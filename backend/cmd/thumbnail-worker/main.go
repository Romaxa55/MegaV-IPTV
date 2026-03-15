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
		workers   = flag.Int("workers", 4, "Number of concurrent thumbnail workers")
		outputDir = flag.String("output", "/app/thumbnails", "Thumbnail output directory")
	)
	flag.Parse()

	logger := logrus.New()
	logger.SetFormatter(&logrus.TextFormatter{FullTimestamp: true})
	if *debug {
		logger.SetLevel(logrus.DebugLevel)
	}

	logger.Info("IPTV Thumbnail Worker starting (queue mode)")

	repo, err := repositories.NewIPTVRepository(cfg.DatabaseURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to database")
	}
	defer repo.Close()

	redisQueue, err := queue.NewRedisQueue(cfg.RedisURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to Redis queue")
	}
	defer redisQueue.Close()

	thumbService := services.NewThumbnailService(logger, cfg.FFmpegBin, *outputDir, 15*time.Second)

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
					if ctx.Err() != nil {
						return
					}
					logger.WithError(err).Warn("Failed to dequeue thumbnail item")
					continue
				}
				if item == nil {
					continue
				}

				_, err = thumbService.GenerateThumbnail(ctx, item.ChannelID, item.URL)
				if err != nil {
					logger.Debugf("Failed thumbnail for %s: %v", item.ChannelID, err)
					clearGeneratingFlag(redisQueue, item.ChannelID)
					continue
				}

				thumbnailURL := fmt.Sprintf("/api/channels/%s/thumbnail.jpg", item.ChannelID)
				if err := repo.UpdateChannelThumbnail(item.ChannelID, thumbnailURL); err != nil {
					logger.WithError(err).Warnf("Failed to update thumbnail URL for %s", item.ChannelID)
				} else {
					logger.Debugf("Generated thumbnail for %s", item.ChannelID)
				}

				clearGeneratingFlag(redisQueue, item.ChannelID)
			}
		}(i)
	}

	logger.Infof("Thumbnail worker running with %d workers, waiting for jobs...", *workers)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down thumbnail worker...")
	cancel()
	wg.Wait()
	logger.Info("Thumbnail worker stopped")
}

func clearGeneratingFlag(rq *queue.RedisQueue, channelID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	rq.GetClient().Del(ctx, "iptv:thumb:generating:"+channelID)
}
