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
		debug    = flag.Bool("debug", cfg.Debug, "Enable debug logging")
		epgURL   = flag.String("epg-url", "", "Single EPG URL to parse (overrides defaults)")
		cleanOld = flag.Bool("clean-old", true, "Delete EPG programs older than 1 day")
	)
	flag.Parse()

	logger := logrus.New()
	if *debug {
		logger.SetLevel(logrus.DebugLevel)
	}

	logger.Info("IPTV EPG Parser starting")

	repo, err := repositories.NewIPTVRepository(cfg.DatabaseURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to database")
	}
	defer repo.Close()

	if *cleanOld {
		deleted, err := repo.DeleteOldEpgPrograms()
		if err != nil {
			logger.WithError(err).Warn("Failed to clean old EPG programs")
		} else {
			logger.Infof("Cleaned %d old EPG programs", deleted)
		}
	}

	tvgIDMap, err := repo.GetAllChannelTvgIDs()
	if err != nil {
		logger.WithError(err).Fatal("Failed to load tvg-id map")
	}
	channelNames, err := repo.GetAllChannelNames()
	if err != nil {
		logger.WithError(err).Fatal("Failed to load channel names")
	}

	existingMap, err := repo.GetEpgChannelMap()
	if err != nil {
		logger.WithError(err).Warn("Failed to load existing EPG channel map")
		existingMap = make(map[string]string)
	}

	epgService := services.NewEPGService(logger)

	epgSources := services.GetDefaultEPGSources()
	if *epgURL != "" {
		epgSources = []string{*epgURL}
	}

	totalPrograms := 0

	for _, src := range epgSources {
		data, err := epgService.FetchAndParse(src)
		if err != nil {
			logger.WithError(err).Errorf("Failed to parse EPG: %s", src)
			continue
		}

		matched := epgService.SmartMatch(data.Channels, tvgIDMap, channelNames)

		for epgID, chID := range existingMap {
			if _, exists := matched[epgID]; !exists {
				matched[epgID] = chID
			}
		}

		for epgID, chID := range matched {
			confidence := 1.0
			if _, exactMatch := tvgIDMap[epgID]; !exactMatch {
				confidence = 0.8
			}
			if err := repo.UpsertEpgChannelMap(chID, epgID, confidence); err != nil {
				logger.WithError(err).Warnf("Failed to save EPG channel map: %s -> %s", epgID, chID)
			}
		}

		// Remap program channel IDs to our channel IDs
		var mappedPrograms []*models.EpgProgram
		for _, p := range data.Programs {
			if chID, ok := matched[p.ChannelID]; ok {
				p.ChannelID = chID
				mappedPrograms = append(mappedPrograms, p)
			}
		}

		batchSize := cfg.BatchSize
		for i := 0; i < len(mappedPrograms); i += batchSize {
			end := i + batchSize
			if end > len(mappedPrograms) {
				end = len(mappedPrograms)
			}

			count, err := repo.InsertEpgProgramsBatch(mappedPrograms[i:end])
			if err != nil {
				logger.WithError(err).Errorf("Failed to insert EPG batch at offset %d", i)
				continue
			}
			totalPrograms += count
		}

		logger.Infof("EPG source %s: matched %d channels, inserted programs", src, len(matched))
	}

	logger.Infof("EPG parsing complete. Total programs inserted: %d", totalPrograms)
}
