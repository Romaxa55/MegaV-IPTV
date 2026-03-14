package services

import (
	"bufio"
	"crypto/sha256"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/romaxa55/iptv-parser/internal/models"
	"github.com/sirupsen/logrus"
)

var (
	reExtInf   = regexp.MustCompile(`#EXTINF:\s*-?\d+\s*(.*)`)
	reTvgID    = regexp.MustCompile(`tvg-id="([^"]*)"`)
	reTvgName  = regexp.MustCompile(`tvg-name="([^"]*)"`)
	reTvgLogo  = regexp.MustCompile(`tvg-logo="([^"]*)"`)
	reGroup    = regexp.MustCompile(`group-title="([^"]*)"`)
	reCountry  = regexp.MustCompile(`tvg-country="([^"]*)"`)
	reLanguage = regexp.MustCompile(`tvg-language="([^"]*)"`)
)

type M3UService struct {
	logger *logrus.Logger
	client *http.Client
}

func NewM3UService(logger *logrus.Logger) *M3UService {
	return &M3UService{
		logger: logger,
		client: &http.Client{Timeout: 60 * time.Second},
	}
}

type M3UEntry struct {
	TvgID      string
	TvgName    string
	Name       string
	URL        string
	LogoURL    string
	GroupTitle  string
	Country    string
	Language   string
	RawExtInf  string
}

func (s *M3UService) FetchAndParse(playlistURL string) ([]*M3UEntry, error) {
	s.logger.Infof("Fetching playlist: %s", playlistURL)

	resp, err := s.client.Get(playlistURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch playlist: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	return s.Parse(resp.Body)
}

func (s *M3UService) Parse(reader io.Reader) ([]*M3UEntry, error) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)

	var entries []*M3UEntry
	var currentEntry *M3UEntry

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		if strings.HasPrefix(line, "#EXTM3U") {
			continue
		}

		if strings.HasPrefix(line, "#EXTINF:") {
			currentEntry = s.parseExtInf(line)
			continue
		}

		if strings.HasPrefix(line, "#") {
			continue
		}

		// This is a URL line
		if currentEntry != nil && (strings.HasPrefix(line, "http://") || strings.HasPrefix(line, "https://") || strings.HasPrefix(line, "rtsp://") || strings.HasPrefix(line, "rtmp://")) {
			currentEntry.URL = line
			entries = append(entries, currentEntry)
			currentEntry = nil
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scanner error: %w", err)
	}

	s.logger.Infof("Parsed %d entries from playlist", len(entries))
	return entries, nil
}

func (s *M3UService) parseExtInf(line string) *M3UEntry {
	entry := &M3UEntry{RawExtInf: line}

	if m := reTvgID.FindStringSubmatch(line); len(m) > 1 {
		entry.TvgID = m[1]
	}
	if m := reTvgName.FindStringSubmatch(line); len(m) > 1 {
		entry.TvgName = m[1]
	}
	if m := reTvgLogo.FindStringSubmatch(line); len(m) > 1 {
		entry.LogoURL = m[1]
	}
	if m := reGroup.FindStringSubmatch(line); len(m) > 1 {
		entry.GroupTitle = m[1]
	}
	if m := reCountry.FindStringSubmatch(line); len(m) > 1 {
		entry.Country = m[1]
	}
	if m := reLanguage.FindStringSubmatch(line); len(m) > 1 {
		entry.Language = m[1]
	}

	// Extract display name (after the last comma)
	if idx := strings.LastIndex(line, ","); idx != -1 {
		entry.Name = strings.TrimSpace(line[idx+1:])
	}

	if entry.Name == "" {
		entry.Name = entry.TvgName
	}

	return entry
}

func (s *M3UService) EntriesToChannels(entries []*M3UEntry, sourceID *int) []*models.Channel {
	seen := make(map[string]bool)
	var channels []*models.Channel

	for _, e := range entries {
		if e.URL == "" || e.Name == "" {
			continue
		}

		id := e.TvgID
		if id == "" {
			id = generateChannelID(e.Name, e.URL)
		}

		if seen[id] {
			continue
		}
		seen[id] = true

		ch := &models.Channel{
			ID:       id,
			Name:     e.Name,
			URL:      e.URL,
			SourceID: sourceID,
		}
		if e.LogoURL != "" {
			ch.LogoURL = &e.LogoURL
		}
		if e.GroupTitle != "" {
			ch.GroupTitle = &e.GroupTitle
		}
		if e.Country != "" {
			ch.Country = &e.Country
		}
		if e.Language != "" {
			ch.Language = &e.Language
		}
		if e.TvgID != "" {
			ch.TvgID = &e.TvgID
		}

		channels = append(channels, ch)
	}

	return channels
}

func generateChannelID(name, url string) string {
	h := sha256.Sum256([]byte(name + "|" + url))
	return fmt.Sprintf("%x", h[:8])
}

func GetDefaultSources() []string {
	return []string{
		"https://iptv-org.github.io/iptv/index.m3u",
		"https://iptv-org.github.io/iptv/index.country.m3u",
		"https://iptv-org.github.io/iptv/index.category.m3u",
	}
}
