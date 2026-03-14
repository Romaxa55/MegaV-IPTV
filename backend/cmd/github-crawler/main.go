package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"strconv"
	"syscall"

	"github.com/romaxa55/iptv-parser/internal/config"
	"github.com/romaxa55/iptv-parser/internal/queue"
	"github.com/romaxa55/iptv-parser/internal/services"
	"github.com/sirupsen/logrus"
)

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		logrus.WithError(err).Fatal("Failed to load config")
	}

	var (
		debug       = flag.Bool("debug", cfg.Debug, "Enable debug logging")
		minStars    = flag.Int("min-stars", 0, "Minimum GitHub stars")
		maxAgeDays  = flag.Int("max-age-days", 7, "Maximum age of last push in days")
		minChannels = flag.Int("min-channels", 5, "Minimum #EXTINF entries to accept a playlist")
	)
	flag.Parse()

	logger := logrus.New()
	if *debug {
		logger.SetLevel(logrus.DebugLevel)
	}

	if v := os.Getenv("CRAWLER_MIN_STARS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*minStars = n
		}
	}
	if v := os.Getenv("CRAWLER_MAX_AGE_DAYS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*maxAgeDays = n
		}
	}
	if v := os.Getenv("CRAWLER_MIN_CHANNELS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			*minChannels = n
		}
	}

	githubToken := os.Getenv("GITHUB_TOKEN")
	if githubToken == "" {
		logger.Warn("GITHUB_TOKEN not set — rate limits will be very restrictive (10 req/min shared)")
	}

	logger.Info("GitHub M3U Crawler starting")

	rq, err := queue.NewRedisQueue(cfg.RedisURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to Redis")
	}
	defer rq.Close()

	crawler := services.NewGitHubCrawler(logger, rq, services.CrawlerConfig{
		Token:       githubToken,
		MinStars:    *minStars,
		MaxAgeDays:  *maxAgeDays,
		MinChannels: *minChannels,
	})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		logger.Info("Received shutdown signal")
		cancel()
	}()

	found, err := crawler.Crawl(ctx)
	if err != nil {
		logger.WithError(err).Error("Crawl finished with error")
	}

	queueLen, _ := rq.GetSourceQueueLen(ctx)
	logger.Infof("Crawl complete. Found %d valid playlists. Queue length: %d", found, queueLen)
}
