package main

import (
	"context"
	"flag"
	"os"
	"strconv"
	"sync"
	"sync/atomic"

	"github.com/romaxa55/iptv-parser/internal/config"
	"github.com/romaxa55/iptv-parser/internal/models"
	"github.com/romaxa55/iptv-parser/internal/queue"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/romaxa55/iptv-parser/internal/services"
	"github.com/sirupsen/logrus"

	_ "github.com/lib/pq"
)

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		logrus.WithError(err).Fatal("Failed to load config")
	}

	var (
		debug          = flag.Bool("debug", cfg.Debug, "Enable debug logging")
		migrations     = flag.String("migrations", "", "Path to migrations directory")
		sourceURL      = flag.String("source", "", "Single M3U source URL to parse")
		fastCheck      = flag.Bool("fast-check", false, "Enable ffprobe fast check for crawled sources")
		fastCheckAll   = flag.Bool("fast-check-all", false, "Enable ffprobe fast check for ALL sources including defaults")
		checkWorkers   = flag.Int("check-workers", 20, "Number of fast-check worker goroutines")
	)
	flag.Parse()

	logger := logrus.New()
	if *debug {
		logger.SetLevel(logrus.DebugLevel)
	}

	if v := os.Getenv("FAST_CHECK_WORKERS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*checkWorkers = n
		}
	}
	if os.Getenv("FAST_CHECK") == "true" || os.Getenv("FAST_CHECK") == "1" {
		*fastCheck = true
	}
	if os.Getenv("FAST_CHECK_ALL") == "true" || os.Getenv("FAST_CHECK_ALL") == "1" {
		*fastCheckAll = true
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

	m3uService := services.NewM3UService(logger)
	var checker *services.CheckerService
	if *fastCheck || *fastCheckAll {
		checker = services.NewCheckerService(logger, cfg.FFprobeBin, cfg.Timeout)
	}

	// Phase 1: Parse default/explicit sources
	defaultSources := services.GetDefaultSources()
	if *sourceURL != "" {
		defaultSources = []string{*sourceURL}
	}

	totalChannels := 0
	for _, src := range defaultSources {
		count := parseSource(logger, repo, m3uService, checker, src, "github", *fastCheckAll, *checkWorkers)
		totalChannels += count
	}

	// Phase 2: Build enricher index for matching crawled channels to reference DB
	enricher := services.NewChannelEnricher(logger, repo.GetDB())
	if err := enricher.BuildIndex(context.Background()); err != nil {
		logger.WithError(err).Warn("Failed to build enricher index, crawled channels won't be matched")
	}

	// Phase 3: Process sources from Redis queue (from GitHub crawler)
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
			logger.Infof("Processing crawled source: %s (%s/%s, %d stars)",
				si.RawURL, si.GitHubRepo, si.FilePath, si.Stars)

			count := parseCrawledSource(logger, repo, m3uService, checker, enricher, si, *checkWorkers)
			totalChannels += count

			if err := rq.MarkSourceProcessed(ctx, si.RawURL); err != nil {
				logger.WithError(err).Warn("Failed to mark source as processed")
			}
		}
	}

	if err := repo.RefreshGroupCounts(); err != nil {
		logger.WithError(err).Warn("Failed to refresh group counts")
	}

	logger.Infof("M3U parsing complete. Total channels upserted: %d", totalChannels)
}

func parseSource(logger *logrus.Logger, repo *repositories.IPTVRepository, m3uService *services.M3UService, checker *services.CheckerService, srcURL, sourceType string, doCheck bool, workers int) int {
	srcModel := &models.Source{
		URL:        srcURL,
		SourceType: sourceType,
		Status:     "active",
	}
	name := srcURL
	srcModel.Name = &name

	sourceID, err := repo.UpsertSource(srcModel)
	if err != nil {
		logger.WithError(err).Errorf("Failed to upsert source: %s", srcURL)
		return 0
	}

	entries, err := m3uService.FetchAndParse(srcURL)
	if err != nil {
		logger.WithError(err).Errorf("Failed to parse: %s", srcURL)
		return 0
	}

	channels := m3uService.EntriesToChannels(entries, &sourceID)
	logger.Infof("Source %s: %d entries -> %d unique channels", srcURL, len(entries), len(channels))

	if doCheck && checker != nil {
		channels = fastCheckChannels(logger, checker, channels, workers)
		logger.Infof("After fast check: %d alive channels", len(channels))
	}

	total := batchUpsert(logger, repo, channels, 100)

	if err := repo.UpdateSourceStats(sourceID, len(channels)); err != nil {
		logger.WithError(err).Warn("Failed to update source stats")
	}

	return total
}

func parseCrawledSource(logger *logrus.Logger, repo *repositories.IPTVRepository, m3uService *services.M3UService, checker *services.CheckerService, enricher *services.ChannelEnricher, si *queue.SourceItem, workers int) int {
	srcModel := &models.Source{
		URL:        si.RawURL,
		SourceType: "github_crawl",
		Status:     "active",
	}
	name := si.GitHubRepo + "/" + si.FilePath
	srcModel.Name = &name
	srcModel.GitHubRepo = &si.GitHubRepo
	srcModel.GitHubStars = si.Stars
	srcModel.LastCommitAt = &si.PushedAt
	srcModel.FilePath = &si.FilePath
	srcModel.RawURL = &si.RawURL

	sourceID, err := repo.UpsertSource(srcModel)
	if err != nil {
		logger.WithError(err).Errorf("Failed to upsert crawled source: %s", si.RawURL)
		return 0
	}

	entries, err := m3uService.FetchAndParse(si.RawURL)
	if err != nil {
		logger.WithError(err).Errorf("Failed to parse crawled source: %s", si.RawURL)
		return 0
	}

	logger.Infof("Crawled source %s: %d entries", si.RawURL, len(entries))

	// Fast-check entries if checker is available
	if checker != nil {
		entries = fastCheckEntries(logger, checker, entries, workers)
		logger.Infof("After fast check: %d alive entries from %s", len(entries), si.GitHubRepo)
	}

	// Match each entry to reference channel and create stream or unmatched
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
			stream := &models.Stream{
				ChannelID:      &match.ReferenceID,
				URL:            entry.URL,
				SourceID:       &sourceID,
				OriginalName:   strPtr(entry.Name),
				OriginalGroup:  strPtr(entry.GroupTitle),
				Quality:        strPtr(quality),
				Feed:           strPtr(match.Feed),
				TimeshiftHours: match.TimeshiftHours,
			}
			isWorking := true
			stream.IsWorking = &isWorking

			if _, err := repo.UpsertStream(stream); err != nil {
				logger.Debugf("Failed to upsert stream: %v", err)
			} else {
				matched++
			}
		} else {
			countryHint := enricher.GuessCountry(entry.Name, entry.GroupTitle)
			us := &models.UnmatchedStream{
				URL:           entry.URL,
				OriginalName:  strPtr(entry.Name),
				OriginalGroup: strPtr(entry.GroupTitle),
				TvgID:         strPtr(entry.TvgID),
				LogoURL:       strPtr(entry.LogoURL),
				CountryHint:   strPtr(countryHint),
				SourceID:      &sourceID,
			}
			isWorking := true
			us.IsWorking = &isWorking

			if _, err := repo.UpsertUnmatchedStream(us); err != nil {
				logger.Debugf("Failed to upsert unmatched stream: %v", err)
			} else {
				unmatched++
			}
		}
	}

	logger.Infof("Source %s: matched=%d, unmatched=%d", si.GitHubRepo, matched, unmatched)

	if err := repo.UpdateSourceStats(sourceID, matched+unmatched); err != nil {
		logger.WithError(err).Warn("Failed to update source stats")
	}

	return matched
}

func fastCheckEntries(logger *logrus.Logger, checker *services.CheckerService, entries []*services.M3UEntry, workers int) []*services.M3UEntry {
	if len(entries) == 0 {
		return entries
	}

	ctx := context.Background()
	var alive []*services.M3UEntry
	var mu sync.Mutex
	var checked int64

	ch := make(chan *services.M3UEntry, len(entries))
	for _, e := range entries {
		ch <- e
	}
	close(ch)

	var wg sync.WaitGroup
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for entry := range ch {
				n := atomic.AddInt64(&checked, 1)
				if n%50 == 0 {
					logger.Infof("Fast check progress: %d/%d", n, len(entries))
				}

				if checker.CheckChannelFast(ctx, entry.URL) {
					mu.Lock()
					alive = append(alive, entry)
					mu.Unlock()
				}
			}
		}()
	}
	wg.Wait()

	return alive
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func fastCheckChannels(logger *logrus.Logger, checker *services.CheckerService, channels []*models.Channel, workers int) []*models.Channel {
	if len(channels) == 0 {
		return channels
	}

	ctx := context.Background()
	var alive []*models.Channel
	var mu sync.Mutex
	var checked int64

	ch := make(chan *models.Channel, len(channels))
	for _, c := range channels {
		ch <- c
	}
	close(ch)

	var wg sync.WaitGroup
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for channel := range ch {
				n := atomic.AddInt64(&checked, 1)
				if n%50 == 0 {
					logger.Infof("Fast check progress: %d/%d", n, len(channels))
				}

				ok := checker.CheckChannelFast(ctx, channel.URL)
				if ok {
					isWorking := true
					channel.IsWorking = &isWorking
					mu.Lock()
					alive = append(alive, channel)
					mu.Unlock()
				}
			}
		}()
	}
	wg.Wait()

	return alive
}

func batchUpsert(logger *logrus.Logger, repo *repositories.IPTVRepository, channels []*models.Channel, batchSize int) int {
	total := 0
	for i := 0; i < len(channels); i += batchSize {
		end := i + batchSize
		if end > len(channels) {
			end = len(channels)
		}
		batch := channels[i:end]
		count, err := repo.UpsertChannelsBatch(batch)
		if err != nil {
			logger.WithError(err).Errorf("Failed to upsert batch at offset %d", i)
			continue
		}
		total += count
	}
	return total
}
