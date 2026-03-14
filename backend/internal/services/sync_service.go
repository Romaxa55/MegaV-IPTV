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
	"sync"
	"sync/atomic"
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

// --- EPG Sync (streaming XML + parallel DB writers) ---

const (
	epgBatchSize = 5000
	epgDBWriters = 4
)

type xmlChannel struct {
	ID          string `xml:"id,attr"`
	DisplayName string `xml:"display-name"`
	Icon        struct {
		Src string `xml:"src,attr"`
	} `xml:"icon"`
}

type xmlProgramme struct {
	Start    string `xml:"start,attr"`
	Stop     string `xml:"stop,attr"`
	Channel  string `xml:"channel,attr"`
	Title    string `xml:"title"`
	Desc     string `xml:"desc"`
	Category string `xml:"category"`
	Icon     struct {
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

	decoder := xml.NewDecoder(reader)
	decoder.CharsetReader = func(charset string, input io.Reader) (io.Reader, error) {
		return input, nil
	}

	// Stream XML: collect <channel> elements first (small), then process <programme> on the fly
	epgChannelNames := make(map[string]string, 4000)
	epgChannelLogos := make(map[string]string, 4000)

	channelsByName, err := s.repo.GetAllChannelsByName()
	if err != nil {
		return fmt.Errorf("get channels by name: %w", err)
	}

	if err := s.repo.TruncateEpgPrograms(); err != nil {
		return fmt.Errorf("truncate epg: %w", err)
	}

	// Parallel DB writers: read batches from channel, write concurrently
	batchCh := make(chan []*models.EpgProgram, epgDBWriters*2)
	var totalInserted int64
	var writerWg sync.WaitGroup

	for i := 0; i < epgDBWriters; i++ {
		writerWg.Add(1)
		go func(workerID int) {
			defer writerWg.Done()
			for batch := range batchCh {
				n, err := s.repo.InsertEpgProgramsBatch(batch)
				if err != nil {
					s.logger.Errorf("EPG writer %d: insert batch error: %v", workerID, err)
					continue
				}
				atomic.AddInt64(&totalInserted, int64(n))
			}
		}(i)
	}

	// Streaming parse: decode element-by-element
	var epgToDBChannel map[string]int
	batch := make([]*models.EpgProgram, 0, epgBatchSize)
	channelCount := 0
	programmeCount := 0

	for {
		tok, err := decoder.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			close(batchCh)
			writerWg.Wait()
			return fmt.Errorf("xml token: %w", err)
		}

		se, ok := tok.(xml.StartElement)
		if !ok {
			continue
		}

		switch se.Name.Local {
		case "channel":
			var ch xmlChannel
			if err := decoder.DecodeElement(&ch, &se); err != nil {
				s.logger.Warnf("skip bad channel element: %v", err)
				continue
			}
			epgChannelNames[ch.ID] = ch.DisplayName
			if ch.Icon.Src != "" {
				epgChannelLogos[ch.ID] = ch.Icon.Src
			}
			channelCount++

		case "programme":
			// Build mapping lazily on first programme (all channels parsed by this point)
			if epgToDBChannel == nil {
				epgToDBChannel = make(map[string]int, len(epgChannelNames))
				for epgID, displayName := range epgChannelNames {
					if dbID, ok := channelsByName[displayName]; ok {
						epgToDBChannel[epgID] = dbID
					}
				}
				s.logger.Infof("Parsed %d EPG channels, matched %d to DB", channelCount, len(epgToDBChannel))
			}

			var prog xmlProgramme
			if err := decoder.DecodeElement(&prog, &se); err != nil {
				s.logger.Warnf("skip bad programme element: %v", err)
				continue
			}
			programmeCount++

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

			batch = append(batch, p)

			if len(batch) >= epgBatchSize {
				batchCh <- batch
				batch = make([]*models.EpgProgram, 0, epgBatchSize)
			}
		}
	}

	// Flush remaining
	if len(batch) > 0 {
		batchCh <- batch
	}
	close(batchCh)
	writerWg.Wait()

	s.logger.Infof("EPG sync done: %d channels, %d programmes parsed, %d inserted (%d DB writers)",
		channelCount, programmeCount, atomic.LoadInt64(&totalInserted), epgDBWriters)
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
