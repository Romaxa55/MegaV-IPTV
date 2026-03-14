package services

import (
	"context"
	"database/sql"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"unicode"

	"github.com/sirupsen/logrus"
)

type ChannelEnricher struct {
	logger *logrus.Logger
	db     *sql.DB
	index  *channelIndex
}

type channelIndex struct {
	byID      map[string]string // tvg-id → reference channel id
	byName    map[string]string // normalized name → reference channel id
	byAltName map[string]string // normalized alt name → reference channel id
}

var qualityRe = regexp.MustCompile(`(?i)\s*([\[\(]?\s*(HD|FHD|UHD|4K|8K|SD|720p?|1080[pi]?|2160p?|backup|резерв)\s*[\]\)]?\s*)`)
var extraRe = regexp.MustCompile(`(?i)\s*[\[\(](new|old|test|mirror|backup|резерв|дубль)\s*[\]\)]`)

func NewChannelEnricher(logger *logrus.Logger, db *sql.DB) *ChannelEnricher {
	return &ChannelEnricher{
		logger: logger,
		db:     db,
	}
}

func (ce *ChannelEnricher) BuildIndex(ctx context.Context) error {
	ce.logger.Info("Building reference channel index...")

	rows, err := ce.db.QueryContext(ctx, `SELECT id, name, alt_names FROM iptv_reference_channels WHERE closed IS NULL OR closed = ''`)
	if err != nil {
		return fmt.Errorf("query reference channels: %w", err)
	}
	defer rows.Close()

	idx := &channelIndex{
		byID:      make(map[string]string),
		byName:    make(map[string]string),
		byAltName: make(map[string]string),
	}

	count := 0
	for rows.Next() {
		var id, name string
		var altNames []string

		if err := rows.Scan(&id, &name, (*stringArrayScanner)(&altNames)); err != nil {
			ce.logger.Warnf("Scan error: %v", err)
			continue
		}

		idLower := strings.ToLower(id)
		idx.byID[idLower] = id

		norm := normalizeChannelName(name)
		if norm != "" {
			idx.byName[norm] = id
		}

		for _, alt := range altNames {
			normAlt := normalizeChannelName(alt)
			if normAlt != "" {
				idx.byAltName[normAlt] = id
			}
		}
		count++
	}

	ce.index = idx
	ce.logger.Infof("Index built: %d channels, %d names, %d alt_names",
		count, len(idx.byName), len(idx.byAltName))
	return nil
}

func (ce *ChannelEnricher) BackfillLogos(ctx context.Context) (int64, error) {
	ce.logger.Info("Backfilling logos from playlist channels...")

	result, err := ce.db.ExecContext(ctx, `
		WITH stream_logos AS (
			SELECT DISTINCT ON (s.channel_id)
				s.channel_id,
				c.logo_url
			FROM iptv_streams s
			JOIN iptv_channels c ON c.url = s.url
			WHERE s.channel_id IS NOT NULL
				AND c.logo_url IS NOT NULL
				AND c.logo_url != ''
			ORDER BY s.channel_id, s.uptime_pct DESC NULLS LAST
		)
		UPDATE iptv_reference_channels rc
		SET logo_url = sl.logo_url
		FROM stream_logos sl
		WHERE rc.id = sl.channel_id
			AND rc.logo_url IS NULL`)
	if err != nil {
		return 0, fmt.Errorf("backfill logos: %w", err)
	}

	n, _ := result.RowsAffected()
	ce.logger.Infof("Backfilled %d channel logos from playlists", n)
	return n, nil
}

type MatchResult struct {
	ReferenceID    string
	Method         string // "tvg_id", "exact_name", "alt_name", "normalized"
	Feed           string // "SD", "HD", "Plus2", etc.
	TimeshiftHours int    // 0, 2, 4, 7...
}

// ParseTvgIDFeed splits "Mir.ru@Plus2" into ("Mir.ru", "Plus2", 2)
func ParseTvgIDFeed(tvgID string) (channelID, feed string, timeshiftHours int) {
	if idx := strings.Index(tvgID, "@"); idx > 0 {
		channelID = tvgID[:idx]
		feed = tvgID[idx+1:]
		timeshiftHours = parseFeedTimeshift(feed)
	} else {
		channelID = tvgID
	}
	return
}

func parseFeedTimeshift(feed string) int {
	feed = strings.ToLower(feed)
	if strings.HasPrefix(feed, "plus") {
		numStr := strings.TrimPrefix(feed, "plus")
		if n, err := strconv.Atoi(numStr); err == nil {
			return n
		}
	}
	return 0
}

func (ce *ChannelEnricher) Match(tvgID, name, groupTitle string) *MatchResult {
	if ce.index == nil {
		return nil
	}

	// 1. Direct tvg-id match (most reliable), with @feed parsing
	if tvgID != "" {
		baseID, feed, timeshiftHours := ParseTvgIDFeed(tvgID)

		tvgLower := strings.ToLower(baseID)
		if refID, ok := ce.index.byID[tvgLower]; ok {
			return &MatchResult{ReferenceID: refID, Method: "tvg_id", Feed: feed, TimeshiftHours: timeshiftHours}
		}
		if refID, ok := ce.index.byName[normalizeChannelName(baseID)]; ok {
			return &MatchResult{ReferenceID: refID, Method: "tvg_id_fuzzy", Feed: feed, TimeshiftHours: timeshiftHours}
		}
	}

	// 2. Exact name match
	norm := normalizeChannelName(name)
	if norm == "" {
		return nil
	}

	if refID, ok := ce.index.byName[norm]; ok {
		return &MatchResult{ReferenceID: refID, Method: "exact_name"}
	}

	// 3. Alt name match
	if refID, ok := ce.index.byAltName[norm]; ok {
		return &MatchResult{ReferenceID: refID, Method: "alt_name"}
	}

	// 4. Cleaned name (strip quality tags, brackets)
	cleaned := cleanName(name)
	normCleaned := normalizeChannelName(cleaned)
	if normCleaned != norm && normCleaned != "" {
		if refID, ok := ce.index.byName[normCleaned]; ok {
			return &MatchResult{ReferenceID: refID, Method: "normalized"}
		}
		if refID, ok := ce.index.byAltName[normCleaned]; ok {
			return &MatchResult{ReferenceID: refID, Method: "normalized_alt"}
		}
	}

	return nil
}

// DetectTimeshift parses "+2", "+4 hours" etc from channel name.
// Returns the base name (without timeshift suffix) and hours offset.
func (ce *ChannelEnricher) DetectTimeshift(name string) (baseName string, hours int) {
	timeshiftRe := regexp.MustCompile(`(?i)\s*\+\s*(\d{1,2})\s*(ч|час|hours?|h)?\s*$`)
	if m := timeshiftRe.FindStringSubmatch(name); len(m) > 1 {
		if n, err := strconv.Atoi(m[1]); err == nil && n > 0 && n <= 12 {
			baseName = strings.TrimSpace(timeshiftRe.ReplaceAllString(name, ""))
			return baseName, n
		}
	}
	return name, 0
}

func (ce *ChannelEnricher) DetectQuality(name string) string {
	upper := strings.ToUpper(name)
	switch {
	case strings.Contains(upper, "4K") || strings.Contains(upper, "2160"):
		return "4K"
	case strings.Contains(upper, "FHD") || strings.Contains(upper, "1080"):
		return "1080p"
	case strings.Contains(upper, "HD") || strings.Contains(upper, "720"):
		return "720p"
	case strings.Contains(upper, "SD"):
		return "SD"
	default:
		return ""
	}
}

func (ce *ChannelEnricher) GuessCountry(name, groupTitle string) string {
	combined := name + " " + groupTitle

	if hasScript(combined, unicode.Cyrillic) {
		if containsAny(combined, "Украин", "Україн", "UA") {
			return "UA"
		}
		if containsAny(combined, "Беларус", "BY") {
			return "BY"
		}
		if containsAny(combined, "Қазақ", "Казах", "KZ") {
			return "KZ"
		}
		return "RU"
	}
	if hasScript(combined, unicode.Arabic) {
		return "SA"
	}
	if hasScript(combined, unicode.Han) {
		return "CN"
	}
	if hasScript(combined, unicode.Hangul) {
		return "KR"
	}
	if hasScript(combined, unicode.Katakana) || hasScript(combined, unicode.Hiragana) {
		return "JP"
	}
	if hasScript(combined, unicode.Devanagari) || hasScript(combined, unicode.Bengali) {
		return "IN"
	}
	if hasScript(combined, unicode.Thai) {
		return "TH"
	}

	keywords := map[string]string{
		"BBC": "GB", "ITV": "GB", "Sky UK": "GB", "Channel 4": "GB", "Channel 5": "GB",
		"CNN": "US", "Fox": "US", "ESPN": "US", "NBC": "US", "CBS": "US", "ABC": "US",
		"France": "FR", "TF1": "FR", "M6": "FR",
		"ARD": "DE", "ZDF": "DE", "RTL": "DE", "ProSieben": "DE",
		"RAI": "IT", "Mediaset": "IT", "Canale": "IT",
		"TVE": "ES", "Antena 3": "ES", "Telecinco": "ES",
		"Globo": "BR", "SBT": "BR", "Record": "BR",
		"NHK": "JP", "Fuji": "JP",
		"CCTV": "CN",
		"Al Jazeera": "QA", "Al Arabiya": "SA",
		"Star Plus": "IN", "Zee": "IN", "Sony": "IN",
	}

	for kw, country := range keywords {
		if strings.Contains(combined, kw) {
			return country
		}
	}

	return ""
}

func normalizeChannelName(s string) string {
	s = strings.ToLower(s)
	s = strings.Map(func(r rune) rune {
		if unicode.IsLetter(r) || unicode.IsDigit(r) || unicode.IsSpace(r) {
			return r
		}
		return ' '
	}, s)
	fields := strings.Fields(s)
	return strings.Join(fields, " ")
}

func cleanName(s string) string {
	s = qualityRe.ReplaceAllString(s, "")
	s = extraRe.ReplaceAllString(s, "")
	return strings.TrimSpace(s)
}

func hasScript(s string, table *unicode.RangeTable) bool {
	for _, r := range s {
		if unicode.Is(table, r) {
			return true
		}
	}
	return false
}

func containsAny(s string, substrs ...string) bool {
	for _, sub := range substrs {
		if strings.Contains(s, sub) {
			return true
		}
	}
	return false
}

// stringArrayScanner implements sql.Scanner for postgres text[] arrays
type stringArrayScanner []string

func (a *stringArrayScanner) Scan(src interface{}) error {
	if src == nil {
		*a = nil
		return nil
	}

	switch v := src.(type) {
	case []byte:
		return (*a).parseArray(string(v))
	case string:
		return (*a).parseArray(v)
	default:
		return fmt.Errorf("unsupported type: %T", src)
	}
}

func (a *stringArrayScanner) parseArray(s string) error {
	s = strings.TrimSpace(s)
	if s == "{}" || s == "" {
		*a = nil
		return nil
	}
	s = strings.TrimPrefix(s, "{")
	s = strings.TrimSuffix(s, "}")

	var result []string
	var current strings.Builder
	inQuote := false
	escaped := false

	for _, r := range s {
		if escaped {
			current.WriteRune(r)
			escaped = false
			continue
		}
		switch {
		case r == '\\':
			escaped = true
		case r == '"':
			inQuote = !inQuote
		case r == ',' && !inQuote:
			val := strings.TrimSpace(current.String())
			if val != "" {
				result = append(result, val)
			}
			current.Reset()
		default:
			current.WriteRune(r)
		}
	}
	if val := strings.TrimSpace(current.String()); val != "" {
		result = append(result, val)
	}

	*a = result
	return nil
}
