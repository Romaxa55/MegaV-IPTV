package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/romaxa55/iptv-parser/internal/config"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/romaxa55/iptv-parser/internal/services"
	"github.com/sirupsen/logrus"
)

func main() {
	logger := logrus.New()
	logger.SetFormatter(&logrus.TextFormatter{FullTimestamp: true})

	cfg, err := config.LoadConfig()
	if err != nil {
		logger.Fatalf("Failed to load config: %v", err)
	}

	if cfg.Debug {
		logger.SetLevel(logrus.DebugLevel)
	}

	repo, err := repositories.NewIPTVRepository(cfg.DatabaseURL, logger)
	if err != nil {
		logger.Fatalf("Failed to connect to DB: %v", err)
	}
	defer repo.Close()

	repo.RunMigrations("migrations")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sig
		logger.Info("Shutting down...")
		cancel()
	}()

	db := repo.GetDB()

	importer := services.NewReferenceImporter(logger, db)
	count, err := importer.Import(ctx)
	if err != nil {
		logger.Fatalf("Reference import failed: %v", err)
	}
	logger.Infof("Reference DB: %d channels", count)

	enricher := services.NewChannelEnricher(logger, db)
	if err := enricher.BuildIndex(ctx); err != nil {
		logger.Fatalf("Failed to build index: %v", err)
	}

	rematched, err := rematchUnmatched(ctx, logger, repo, enricher)
	if err != nil {
		logger.Warnf("Re-match error: %v", err)
	} else {
		logger.Infof("Re-matched %d previously unmatched streams", rematched)
	}

	logger.Info("Channel enricher complete")
}

func rematchUnmatched(ctx context.Context, logger *logrus.Logger, repo *repositories.IPTVRepository, enricher *services.ChannelEnricher) (int, error) {
	_ = repo
	return 0, nil
}
