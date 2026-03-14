package services

import (
	"bufio"
	"compress/gzip"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/romaxa55/iptv-parser/internal/models"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/sirupsen/logrus"
)

type SyncService struct {
	repo   *repositories.IPTVRepository
	logger *logrus.Logger
}

func NewSyncService(repo *repositories.IPTVRepository, logger *logrus.Logger) *SyncService {
	return &SyncService{repo: repo, logger: logger}
}

type m3uEntry struct {
	Name      string
	Group     string
	TvgRec    int
	StreamURL string
}

func (s *SyncService) SyncPlaylist(playlistURL string) error {
	s.logger.Infof("Fetching playlist: %s", playlistURL)

	resp, err := http.Get(playlistURL)
	if err != nil {
		return fmt.Errorf("fetch playlist: %w", err)
	}
	defer resp.Body.Close()

	entries, err := parseM3U(resp.Body)
	if err != nil {
		return fmt.Errorf("parse m3u: %w", err)
	}

	s.logger.Infof("Parsed %d channels from playlist", len(entries))

	channels := make([]*models.Channel, 0, len(entries))
	for _, e := range entries {
		channels = append(channels, &models.Channel{
			Name:      e.Name,
			GroupTitle: e.Group,
			StreamURL: e.StreamURL,
			TvgRec:    e.TvgRec,
		})
	}

	if err := s.repo.TruncateChannels(); err != nil {
		return fmt.Errorf("truncate channels: %w", err)
	}

	n, err := s.repo.UpsertChannelsBatch(channels)
	if err != nil {
		return fmt.Errorf("upsert channels: %w", err)
	}

	s.logger.Infof("Synced %d channels to database", n)
	_ = s.repo.UpdateSyncTime("last_playlist_sync")
	return nil
}

func parseM3U(r io.Reader) ([]m3uEntry, error) {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)

	var entries []m3uEntry
	var current m3uEntry
	hasInfo := false

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if strings.HasPrefix(line, "#EXTINF:") {
			hasInfo = true
			current = m3uEntry{}

			// Parse tvg-rec
			if idx := strings.Index(line, `tvg-rec="`); idx != -1 {
				rest := line[idx+9:]
				if end := strings.Index(rest, `"`); end != -1 {
					current.TvgRec, _ = strconv.Atoi(rest[:end])
				}
			}

			// Parse channel name (after last comma)
			if idx := strings.LastIndex(line, ","); idx != -1 {
				current.Name = strings.TrimSpace(line[idx+1:])
			}
		} else if strings.HasPrefix(line, "#EXTGRP:") {
			current.Group = strings.TrimSpace(line[8:])
		} else if hasInfo && !strings.HasPrefix(line, "#") && line != "" {
			current.StreamURL = line
			entries = append(entries, current)
			hasInfo = false
		}
	}

	return entries, scanner.Err()
}

// --- EPG Sync ---

type xmlTV struct {
	XMLName    xml.Name       `xml:"tv"`
	Channels   []xmlChannel   `xml:"channel"`
	Programmes []xmlProgramme `xml:"programme"`
}

type xmlChannel struct {
	ID          string `xml:"id,attr"`
	DisplayName string `xml:"display-name"`
	Icon        struct {
		Src string `xml:"src,attr"`
	} `xml:"icon"`
}

type xmlProgramme struct {
	Start   string `xml:"start,attr"`
	Stop    string `xml:"stop,attr"`
	Channel string `xml:"channel,attr"`
	Title   string `xml:"title"`
	Desc    string `xml:"desc"`
	Category string `xml:"category"`
	Icon    struct {
		Src string `xml:"src,attr"`
	} `xml:"icon"`
}

func (s *SyncService) SyncEPG(epgURL string) error {
	s.logger.Infof("Fetching EPG: %s", epgURL)

	resp, err := http.Get(epgURL)
	if err != nil {
		return fmt.Errorf("fetch epg: %w", err)
	}
	defer resp.Body.Close()

	var reader io.Reader = resp.Body
	if strings.HasSuffix(epgURL, ".gz") {
		gz, err := gzip.NewReader(resp.Body)
		if err != nil {
			return fmt.Errorf("gzip reader: %w", err)
		}
		defer gz.Close()
		reader = gz
	}

	var tv xmlTV
	decoder := xml.NewDecoder(reader)
	decoder.CharsetReader = func(charset string, input io.Reader) (io.Reader, error) {
		return input, nil
	}
	if err := decoder.Decode(&tv); err != nil {
		return fmt.Errorf("decode xml: %w", err)
	}

	s.logger.Infof("Parsed EPG: %d channels, %d programmes", len(tv.Channels), len(tv.Programmes))

	// Build EPG channel name -> display name map
	epgChannelNames := make(map[string]string, len(tv.Channels))
	epgChannelLogos := make(map[string]string, len(tv.Channels))
	for _, ch := range tv.Channels {
		epgChannelNames[ch.ID] = ch.DisplayName
		if ch.Icon.Src != "" {
			epgChannelLogos[ch.ID] = ch.Icon.Src
		}
	}

	// Get all channels from DB and build name->id map
	channelsByName, err := s.repo.GetAllChannelsByName()
	if err != nil {
		return fmt.Errorf("get channels by name: %w", err)
	}

	// Build EPG channel ID -> DB channel ID map
	epgToDBChannel := make(map[string]int, len(tv.Channels))
	for epgID, displayName := range epgChannelNames {
		if dbID, ok := channelsByName[displayName]; ok {
			epgToDBChannel[epgID] = dbID
		}
	}

	s.logger.Infof("Matched %d EPG channels to DB channels (out of %d)", len(epgToDBChannel), len(tv.Channels))

	if err := s.repo.TruncateEpgPrograms(); err != nil {
		return fmt.Errorf("truncate epg: %w", err)
	}

	// Convert programmes to models
	var programs []*models.EpgProgram
	for _, prog := range tv.Programmes {
		dbChannelID, ok := epgToDBChannel[prog.Channel]
		if !ok {
			continue
		}

		startTime, err := parseXMLTVTime(prog.Start)
		if err != nil {
			continue
		}
		endTime, err := parseXMLTVTime(prog.Stop)
		if err != nil {
			continue
		}

		p := &models.EpgProgram{
			ChannelID: dbChannelID,
			Title:     prog.Title,
			StartTime: startTime,
			EndTime:   endTime,
		}
		if prog.Desc != "" {
			p.Description = &prog.Desc
		}
		if prog.Category != "" {
			p.Category = &prog.Category
		}
		if prog.Icon.Src != "" {
			p.Icon = &prog.Icon.Src
		}

		programs = append(programs, p)
	}

	n, err := s.repo.InsertEpgProgramsBatch(programs)
	if err != nil {
		return fmt.Errorf("insert epg: %w", err)
	}

	s.logger.Infof("Inserted %d EPG programs", n)
	_ = s.repo.UpdateSyncTime("last_epg_sync")
	return nil
}

func parseXMLTVTime(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	// Format: 20060102150405 +0300
	if len(s) >= 14 {
		layout := "20060102150405 -0700"
		if !strings.Contains(s, " ") {
			layout = "20060102150405"
		}
		return time.Parse(layout, s)
	}
	return time.Time{}, fmt.Errorf("invalid time: %s", s)
}
