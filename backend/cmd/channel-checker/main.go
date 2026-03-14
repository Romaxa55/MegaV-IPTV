package main

import (
	"context"
	"flag"
	"os"
	"strconv"
	"sync"
	"sync/atomic"

	"github.com/romaxa55/iptv-parser/internal/config"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/romaxa55/iptv-parser/internal/services"
	"github.com/sirupsen/logrus"
)

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		logrus.WithError(err).Fatal("Failed to load config")
	}

	var (
		debug   = flag.Bool("debug", cfg.Debug, "Enable debug logging")
		workers = flag.Int("workers", 500, "Number of concurrent check workers")
		batch   = flag.Int("batch", 5000, "Number of streams to check per run")
	)
	flag.Parse()

	if v := os.Getenv("CHECK_WORKERS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*workers = n
		}
	}
	if v := os.Getenv("CHECK_BATCH"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*batch = n
		}
	}

	logger := logrus.New()
	logger.SetFormatter(&logrus.TextFormatter{FullTimestamp: true})
	if *debug {
		logger.SetLevel(logrus.DebugLevel)
	}

	logger.Info("IPTV Stream Checker starting")

	repo, err := repositories.NewIPTVRepository(cfg.DatabaseURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to database")
	}
	defer repo.Close()

	checker := services.NewCheckerService(logger, cfg.FFprobeBin, cfg.Timeout)

	streams, err := repo.GetStreamsForCheck(*batch)
	if err != nil {
		logger.WithError(err).Fatal("Failed to get streams for check")
	}

	if len(streams) == 0 {
		logger.Info("No streams to check")
		return
	}

	logger.Infof("Checking %d streams with %d workers", len(streams), *workers)

	ctx := context.Background()
	var wg sync.WaitGroup
	sem := make(chan struct{}, *workers)
	var working, failed atomic.Int64
	var checked atomic.Int64
	total := int64(len(streams))

	for _, s := range streams {
		wg.Add(1)
		sem <- struct{}{}

		go func(streamID int, streamURL string) {
			defer wg.Done()
			defer func() { <-sem }()

			result := checker.CheckStreamFull(ctx, streamID, streamURL)

			if err := repo.UpdateStreamCheckResult(
				streamID, result.IsWorking, result.ResponseTimeMs,
				result.VideoCodec, result.AudioCodec, result.Resolution,
			); err != nil {
				logger.WithError(err).Debugf("Failed to update check for stream %d", streamID)
			}

			n := checked.Add(1)
			if result.IsWorking {
				working.Add(1)
			} else {
				failed.Add(1)
			}

			if n%200 == 0 || n == total {
				logger.Infof("Progress: %d/%d (working: %d, failed: %d)", n, total, working.Load(), failed.Load())
			}
		}(s.ID, s.URL)
	}

	wg.Wait()

	logger.Infof("Stream check complete. Working: %d, Failed: %d, Total: %d",
		working.Load(), failed.Load(), len(streams))
}
