package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/romaxa55/iptv-parser/internal/config"
	"github.com/romaxa55/iptv-parser/internal/queue"
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
		debug     = flag.Bool("debug", cfg.Debug, "Enable debug logging")
		workers   = flag.Int("workers", 10, "Number of concurrent thumbnail workers")
		outputDir = flag.String("output", "/app/thumbnails", "Thumbnail output directory")
		mode      = flag.String("mode", "queue", "Mode: queue (long-running) or batch (one-shot)")
		batch     = flag.Int("batch", 200, "Batch size for batch mode")
	)
	flag.Parse()

	logger := logrus.New()
	logger.SetFormatter(&logrus.TextFormatter{FullTimestamp: true})
	if *debug {
		logger.SetLevel(logrus.DebugLevel)
	}

	logger.Info("IPTV Thumbnail Worker starting")

	repo, err := repositories.NewIPTVRepository(cfg.DatabaseURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to database")
	}
	defer repo.Close()

	thumbService := services.NewThumbnailService(logger, cfg.FFmpegBin, *outputDir, 15*time.Second)

	if *mode == "batch" {
		runBatchStreams(repo, thumbService, logger, *batch, *workers)
		return
	}

	redisQueue, err := queue.NewRedisQueue(cfg.RedisURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to Redis queue")
	}
	defer redisQueue.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var wg sync.WaitGroup
	for i := 0; i < *workers; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			logger.Infof("Thumbnail worker %d started", workerID)

			for {
				select {
				case <-ctx.Done():
					return
				default:
				}

				item, err := redisQueue.DequeueThumbnail(ctx, 5*time.Second)
				if err != nil {
					logger.WithError(err).Warn("Failed to dequeue thumbnail item")
					continue
				}
				if item == nil {
					continue
				}

				path, err := thumbService.GenerateThumbnail(ctx, item.ChannelID, item.URL)
				if err != nil {
					logger.WithError(err).Debugf("Failed to generate thumbnail for %s", item.ChannelID)
					continue
				}

				thumbnailURL := fmt.Sprintf("/api/channels/%s/thumbnail", item.ChannelID)
				if err := repo.UpdateChannelThumbnail(item.ChannelID, thumbnailURL); err != nil {
					logger.WithError(err).Warnf("Failed to update thumbnail URL for %s", item.ChannelID)
				} else {
					logger.Debugf("Generated thumbnail for %s: %s", item.ChannelID, path)
				}
			}
		}(i)
	}

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down thumbnail worker...")
	cancel()
	wg.Wait()
	logger.Info("Thumbnail worker stopped")
}

func runBatchStreams(repo *repositories.IPTVRepository, thumbService *services.ThumbnailService, logger *logrus.Logger, batchSize, workers int) {
	streams, err := repo.GetWorkingStreamsForThumbnail(batchSize)
	if err != nil {
		logger.WithError(err).Fatal("Failed to get streams for thumbnails")
	}

	if len(streams) == 0 {
		logger.Info("No streams need thumbnail updates")
		return
	}

	logger.Infof("Generating thumbnails for %d streams with %d workers", len(streams), workers)

	ctx := context.Background()
	var wg sync.WaitGroup
	sem := make(chan struct{}, workers)

	for _, s := range streams {
		if s.ChannelID == nil {
			continue
		}
		wg.Add(1)
		sem <- struct{}{}

		go func(channelID, streamURL string) {
			defer wg.Done()
			defer func() { <-sem }()

			_, err := thumbService.GenerateThumbnail(ctx, channelID, streamURL)
			if err != nil {
				logger.Debugf("Failed thumbnail for %s: %v", channelID, err)
				return
			}

			thumbnailURL := fmt.Sprintf("/api/channels/%s/thumbnail", channelID)
			repo.UpdateChannelThumbnail(channelID, thumbnailURL)
		}(*s.ChannelID, s.URL)
	}

	wg.Wait()
	logger.Info("Batch thumbnail generation complete")
}
