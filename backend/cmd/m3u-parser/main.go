package main

import (
	"context"
	"flag"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/romaxa55/iptv-parser/internal/config"
	"github.com/romaxa55/iptv-parser/internal/models"
	"github.com/romaxa55/iptv-parser/internal/queue"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/romaxa55/iptv-parser/internal/services"
	"github.com/sirupsen/logrus"

	_ "github.com/lib/pq"
)

type streamResult struct {
	stream    *models.Stream
	unmatched *models.UnmatchedStream
}

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		logrus.WithError(err).Fatal("Failed to load config")
	}

	var (
		debug        = flag.Bool("debug", cfg.Debug, "Enable debug logging")
		migrations   = flag.String("migrations", "", "Path to migrations directory")
		migrateOnly  = flag.Bool("migrate-only", false, "Run migrations and exit")
		sourceURL    = flag.String("source", "", "Single M3U source URL to parse")
		fastCheck     = flag.Bool("fast-check", true, "Enable ffprobe fast check")
		checkWorkers  = flag.Int("check-workers", 500, "Number of fast-check worker goroutines")
		dbWriters     = flag.Int("db-writers", 8, "Number of DB batch-writer goroutines")
		batchSize     = flag.Int("batch-size", 1000, "Batch size for DB writes")
		sourceWorkers = flag.Int("source-workers", 10, "Number of parallel source processing goroutines")
	)
	flag.Parse()

	if v := os.Getenv("FAST_CHECK_WORKERS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*checkWorkers = n
		}
	}
	if os.Getenv("FAST_CHECK") == "false" || os.Getenv("FAST_CHECK") == "0" {
		*fastCheck = false
	}
	if v := os.Getenv("DB_WRITERS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*dbWriters = n
		}
	}
	if v := os.Getenv("BATCH_SIZE"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*batchSize = n
		}
	}
	if v := os.Getenv("SOURCE_WORKERS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*sourceWorkers = n
		}
	}

	logger := logrus.New()
	logger.SetFormatter(&logrus.TextFormatter{FullTimestamp: true})
	if *debug {
		logger.SetLevel(logrus.DebugLevel)
	}

	logger.Info("IPTV M3U Parser starting")

	repo, err := repositories.NewIPTVRepository(cfg.DatabaseURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to database")
	}
	defer repo.Close()

	if *migrations != "" {
		if err := repo.RunMigrations(*migrations); err != nil {
			logger.WithError(err).Fatal("Failed to run migrations")
		}
	}

	if *migrateOnly {
		logger.Info("Migrations complete, exiting (--migrate-only)")
		return
	}

	m3uService := services.NewM3UService(logger)

	var checker *services.CheckerService
	if *fastCheck {
		checker = services.NewCheckerService(logger, cfg.FFprobeBin, cfg.Timeout)
	}

	enricher := services.NewChannelEnricher(logger, repo.GetDB())
	if err := enricher.BuildIndex(context.Background()); err != nil {
		logger.WithError(err).Warn("Failed to build enricher index — all channels will go to unmatched")
	}

	resultCh := make(chan streamResult, *batchSize*2)

	var writerWg sync.WaitGroup
	var totalMatched, totalUnmatched int64

	for i := 0; i < *dbWriters; i++ {
		writerWg.Add(1)
		go batchWriter(logger, repo, resultCh, *batchSize, &totalMatched, &totalUnmatched, &writerWg)
	}

	type sourceJob struct {
		url        string
		sourceType string
		si         *queue.SourceItem
	}

	var allJobs []sourceJob

	defaultSources := services.GetDefaultSources()
	if *sourceURL != "" {
		defaultSources = []string{*sourceURL}
	}
	for _, src := range defaultSources {
		allJobs = append(allJobs, sourceJob{url: src, sourceType: "iptv_org"})
	}

	var rq *queue.RedisQueue
	rq, err = queue.NewRedisQueue(cfg.RedisURL, logger)
	if err != nil {
		logger.WithError(err).Warn("Failed to connect to Redis, skipping crawled sources")
	} else {
		defer rq.Close()
		ctx := context.Background()

		queueLen, _ := rq.GetSourceQueueLen(ctx)
		logger.Infof("Redis source queue length: %d", queueLen)

		crawledSources, err := rq.DequeueAllSources(ctx)
		if err != nil {
			logger.WithError(err).Warn("Failed to dequeue sources from Redis")
		}

		if len(crawledSources) > 0 {
			logger.Infof("Processing %d crawled sources from Redis", len(crawledSources))
		}
		for _, si := range crawledSources {
			allJobs = append(allJobs, sourceJob{url: si.RawURL, sourceType: "github_crawl", si: si})
		}
	}

	logger.Infof("Total sources to process: %d (parallel workers: %d)", len(allJobs), *sourceWorkers)

	sourceSem := make(chan struct{}, *sourceWorkers)
	var sourceWg sync.WaitGroup

	for _, job := range allJobs {
		sourceWg.Add(1)
		sourceSem <- struct{}{}
		go func(j sourceJob) {
			defer sourceWg.Done()
			defer func() { <-sourceSem }()

			processSource(logger, repo, m3uService, checker, enricher, j.url, j.sourceType, j.si, resultCh, *checkWorkers)

			if j.si != nil && rq != nil {
				if err := rq.MarkSourceProcessed(context.Background(), j.si.RawURL); err != nil {
					logger.WithError(err).Warn("Failed to mark source as processed")
				}
			}
		}(job)
	}

	sourceWg.Wait()
	close(resultCh)
	writerWg.Wait()

	matched := atomic.LoadInt64(&totalMatched)
	unmatched := atomic.LoadInt64(&totalUnmatched)
	logger.Infof("M3U parsing complete. Streams: matched=%d, unmatched=%d, total=%d", matched, unmatched, matched+unmatched)
}

func processSource(
	logger *logrus.Logger,
	repo *repositories.IPTVRepository,
	m3uService *services.M3UService,
	checker *services.CheckerService,
	enricher *services.ChannelEnricher,
	srcURL, sourceType string,
	si *queue.SourceItem,
	resultCh chan<- streamResult,
	checkWorkers int,
) {
	srcModel := &models.Source{
		URL:        srcURL,
		SourceType: sourceType,
		Status:     "active",
	}
	name := srcURL
	srcModel.Name = &name

	if si != nil {
		srcModel.GitHubRepo = &si.GitHubRepo
		srcModel.GitHubStars = si.Stars
		srcModel.LastCommitAt = &si.PushedAt
		srcModel.FilePath = &si.FilePath
		srcModel.RawURL = &si.RawURL
		n := si.GitHubRepo + "/" + si.FilePath
		srcModel.Name = &n
	}

	sourceID, err := repo.UpsertSource(srcModel)
	if err != nil {
		logger.WithError(err).Errorf("Failed to upsert source: %s", srcURL)
		return
	}

	entries, err := m3uService.FetchAndParse(srcURL)
	if err != nil {
		logger.WithError(err).Errorf("Failed to parse: %s", srcURL)
		return
	}

	logger.Infof("Source %s: %d entries parsed", srcURL, len(entries))

	if checker != nil && len(entries) > 0 {
		entries = fastCheckEntries(logger, checker, entries, checkWorkers)
		logger.Infof("Source %s: %d alive after fast check", srcURL, len(entries))
	}

	matched, unmatched := 0, 0
	for _, entry := range entries {
		if entry.URL == "" || entry.Name == "" {
			continue
		}

		quality := enricher.DetectQuality(entry.Name)
		baseName, timeshiftFromName := enricher.DetectTimeshift(entry.Name)

		match := enricher.Match(entry.TvgID, entry.Name, entry.GroupTitle)
		if match == nil && timeshiftFromName > 0 {
			match = enricher.Match("", baseName, entry.GroupTitle)
			if match != nil {
				match.TimeshiftHours = timeshiftFromName
			}
		}

		if match != nil {
			isWorking := true
			resultCh <- streamResult{
				stream: &models.Stream{
					ChannelID:      &match.ReferenceID,
					URL:            entry.URL,
					SourceID:       &sourceID,
					OriginalName:   strPtr(entry.Name),
					OriginalGroup:  strPtr(entry.GroupTitle),
					Quality:        strPtr(quality),
					Feed:           strPtr(match.Feed),
					TimeshiftHours: match.TimeshiftHours,
					IsWorking:      &isWorking,
				},
			}
			matched++
		} else {
			isWorking := true
			countryHint := enricher.GuessCountry(entry.Name, entry.GroupTitle)
			resultCh <- streamResult{
				unmatched: &models.UnmatchedStream{
					URL:           entry.URL,
					OriginalName:  strPtr(entry.Name),
					OriginalGroup: strPtr(entry.GroupTitle),
					TvgID:         strPtr(entry.TvgID),
					LogoURL:       strPtr(entry.LogoURL),
					CountryHint:   strPtr(countryHint),
					SourceID:      &sourceID,
					IsWorking:     &isWorking,
				},
			}
			unmatched++
		}
	}

	if err := repo.UpdateSourceStats(sourceID, matched+unmatched); err != nil {
		logger.WithError(err).Warn("Failed to update source stats")
	}

	logger.Infof("Source %s: matched=%d, unmatched=%d", srcURL, matched, unmatched)
}

func batchWriter(
	logger *logrus.Logger,
	repo *repositories.IPTVRepository,
	resultCh <-chan streamResult,
	batchSize int,
	totalMatched, totalUnmatched *int64,
	wg *sync.WaitGroup,
) {
	defer wg.Done()

	streamBuf := make([]*models.Stream, 0, batchSize)
	unmatchedBuf := make([]*models.UnmatchedStream, 0, batchSize)

	flush := func() {
		if len(streamBuf) > 0 {
			n, err := repo.UpsertStreamsBatch(streamBuf)
			if err != nil {
				logger.WithError(err).Errorf("Failed to batch upsert %d streams", len(streamBuf))
			} else {
				atomic.AddInt64(totalMatched, int64(n))
			}
			streamBuf = streamBuf[:0]
		}
		if len(unmatchedBuf) > 0 {
			n, err := repo.UpsertUnmatchedStreamsBatch(unmatchedBuf)
			if err != nil {
				logger.WithError(err).Errorf("Failed to batch upsert %d unmatched", len(unmatchedBuf))
			} else {
				atomic.AddInt64(totalUnmatched, int64(n))
			}
			unmatchedBuf = unmatchedBuf[:0]
		}
	}

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case r, ok := <-resultCh:
			if !ok {
				flush()
				return
			}
			if r.stream != nil {
				streamBuf = append(streamBuf, r.stream)
			}
			if r.unmatched != nil {
				unmatchedBuf = append(unmatchedBuf, r.unmatched)
			}
			if len(streamBuf) >= batchSize {
				n, err := repo.UpsertStreamsBatch(streamBuf)
				if err != nil {
					logger.WithError(err).Errorf("Failed to batch upsert %d streams", len(streamBuf))
				} else {
					atomic.AddInt64(totalMatched, int64(n))
				}
				streamBuf = streamBuf[:0]
			}
			if len(unmatchedBuf) >= batchSize {
				n, err := repo.UpsertUnmatchedStreamsBatch(unmatchedBuf)
				if err != nil {
					logger.WithError(err).Errorf("Failed to batch upsert %d unmatched", len(unmatchedBuf))
				} else {
					atomic.AddInt64(totalUnmatched, int64(n))
				}
				unmatchedBuf = unmatchedBuf[:0]
			}
		case <-ticker.C:
			flush()
		}
	}
}

func fastCheckEntries(logger *logrus.Logger, checker *services.CheckerService, entries []*services.M3UEntry, workers int) []*services.M3UEntry {
	if len(entries) == 0 {
		return entries
	}

	ctx := context.Background()
	var alive []*services.M3UEntry
	var mu sync.Mutex
	var checked int64
	total := int64(len(entries))

	ch := make(chan *services.M3UEntry, workers*2)

	var wg sync.WaitGroup
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for entry := range ch {
				n := atomic.AddInt64(&checked, 1)
				if n%100 == 0 || n == total {
					logger.Infof("Fast check progress: %d/%d (alive: %d)", n, total, int64(len(alive)))
				}
				if checker.CheckChannelFast(ctx, entry.URL) {
					mu.Lock()
					alive = append(alive, entry)
					mu.Unlock()
				}
			}
		}()
	}

	for _, e := range entries {
		ch <- e
	}
	close(ch)
	wg.Wait()

	return alive
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
