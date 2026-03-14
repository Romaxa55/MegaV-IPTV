package main

import (
	"flag"

	"github.com/romaxa55/iptv-parser/internal/config"
	"github.com/romaxa55/iptv-parser/internal/models"
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
		debug      = flag.Bool("debug", cfg.Debug, "Enable debug logging")
		migrations = flag.String("migrations", "", "Path to migrations directory (run before parsing)")
		sourceURL  = flag.String("source", "", "Single M3U source URL to parse (overrides defaults)")
	)
	flag.Parse()

	logger := logrus.New()
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

	m3uService := services.NewM3UService(logger)

	sources := services.GetDefaultSources()
	if *sourceURL != "" {
		sources = []string{*sourceURL}
	}

	totalChannels := 0

	for _, src := range sources {
		srcModel := &models.Source{
			URL:        src,
			SourceType: "github",
			Status:     "active",
		}
		name := src
		srcModel.Name = &name

		sourceID, err := repo.UpsertSource(srcModel)
		if err != nil {
			logger.WithError(err).Errorf("Failed to upsert source: %s", src)
			continue
		}

		entries, err := m3uService.FetchAndParse(src)
		if err != nil {
			logger.WithError(err).Errorf("Failed to parse: %s", src)
			continue
		}

		channels := m3uService.EntriesToChannels(entries, &sourceID)
		logger.Infof("Source %s: %d entries -> %d unique channels", src, len(entries), len(channels))

		// Batch upsert
		batchSize := cfg.BatchSize
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
			totalChannels += count
		}

		if err := repo.UpdateSourceStats(sourceID, len(channels)); err != nil {
			logger.WithError(err).Warn("Failed to update source stats")
		}
	}

	if err := repo.RefreshGroupCounts(); err != nil {
		logger.WithError(err).Warn("Failed to refresh group counts")
	}

	logger.Infof("M3U parsing complete. Total channels upserted: %d", totalChannels)
}
