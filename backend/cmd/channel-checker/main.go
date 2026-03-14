package main

import (
	"context"
	"flag"
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
		workers = flag.Int("workers", cfg.Workers, "Number of concurrent workers")
		batch   = flag.Int("batch", 1000, "Number of channels to check per run")
	)
	flag.Parse()

	logger := logrus.New()
	if *debug {
		logger.SetLevel(logrus.DebugLevel)
	}

	logger.Info("IPTV Channel Checker starting")

	repo, err := repositories.NewIPTVRepository(cfg.DatabaseURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to database")
	}
	defer repo.Close()

	checker := services.NewCheckerService(logger, cfg.FFprobeBin, cfg.Timeout)

	channels, err := repo.GetChannelsForCheck(*batch)
	if err != nil {
		logger.WithError(err).Fatal("Failed to get channels for check")
	}

	if len(channels) == 0 {
		logger.Info("No channels to check")
		return
	}

	logger.Infof("Checking %d channels with %d workers", len(channels), *workers)

	ctx := context.Background()
	var wg sync.WaitGroup
	sem := make(chan struct{}, *workers)
	var working, failed atomic.Int64

	for _, ch := range channels {
		wg.Add(1)
		sem <- struct{}{}

		go func(channelID, url string) {
			defer wg.Done()
			defer func() { <-sem }()

			result := checker.CheckChannel(ctx, channelID, url)
			if err := repo.UpdateChannelCheckResult(
				channelID, result.IsWorking,
				result.VideoCodec, result.AudioCodec, result.Resolution,
			); err != nil {
				logger.WithError(err).Warnf("Failed to update check result for %s", channelID)
			}

			if result.IsWorking {
				working.Add(1)
			} else {
				failed.Add(1)
			}
		}(ch.ID, ch.URL)
	}

	wg.Wait()

	logger.Infof("Channel check complete. Working: %d, Failed: %d, Total: %d",
		working.Load(), failed.Load(), len(channels))
}
