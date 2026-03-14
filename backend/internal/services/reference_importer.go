package services

import (
	"context"
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/lib/pq"
	"github.com/sirupsen/logrus"
)

const (
	channelsCSVURL = "https://raw.githubusercontent.com/iptv-org/database/master/data/channels.csv"
)

type ReferenceImporter struct {
	logger *logrus.Logger
	db     *sql.DB
	client *http.Client
}

func NewReferenceImporter(logger *logrus.Logger, db *sql.DB) *ReferenceImporter {
	return &ReferenceImporter{
		logger: logger,
		db:     db,
		client: &http.Client{Timeout: 60 * time.Second},
	}
}

const logosJSONURL = "https://iptv-org.github.io/api/logos.json"

type csvChannel struct {
	ID         string
	Name       string
	AltNames   []string
	Network    string
	Owners     string
	Country    string
	Categories []string
	IsNSFW     bool
	Launched   string
	Closed     string
	ReplacedBy string
	Website    string
	LogoURL    string
}

type logoEntry struct {
	Channel string  `json:"channel"`
	Feed    *string `json:"feed"`
	URL     string  `json:"url"`
	Width   int     `json:"width"`
	Height  int     `json:"height"`
}

func (ri *ReferenceImporter) Import(ctx context.Context) (int, error) {
	ri.logger.Info("Downloading channels.csv from iptv-org/database...")

	req, err := http.NewRequestWithContext(ctx, "GET", channelsCSVURL, nil)
	if err != nil {
		return 0, err
	}

	resp, err := ri.client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("failed to download channels.csv: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return 0, fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	ri.logger.Info("Download complete, parsing CSV...")

	channels, err := ri.parseCSV(resp.Body)
	if err != nil {
		return 0, fmt.Errorf("failed to parse CSV: %w", err)
	}

	ri.logger.Infof("Parsed %d reference channels, fetching logos...", len(channels))

	logoMap, err := ri.fetchLogos(ctx)
	if err != nil {
		ri.logger.Warnf("Failed to fetch logos (continuing without): %v", err)
	} else {
		matched := 0
		for _, ch := range channels {
			if url, ok := logoMap[ch.ID]; ok {
				ch.LogoURL = url
				matched++
			}
		}
		ri.logger.Infof("Matched %d/%d channels with logos", matched, len(channels))
	}

	ri.logger.Infof("Upserting to DB...")

	count, err := ri.upsertBatch(ctx, channels)
	if err != nil {
		return count, fmt.Errorf("upsert failed: %w", err)
	}

	ri.logger.Infof("Imported %d reference channels", count)
	return count, nil
}

func (ri *ReferenceImporter) fetchLogos(ctx context.Context) (map[string]string, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", logosJSONURL, nil)
	if err != nil {
		return nil, err
	}

	resp, err := ri.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to download logos.json: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	var logos []logoEntry
	if err := json.NewDecoder(resp.Body).Decode(&logos); err != nil {
		return nil, fmt.Errorf("failed to decode logos.json: %w", err)
	}

	result := make(map[string]string, len(logos))
	for _, l := range logos {
		if l.URL == "" || l.Channel == "" {
			continue
		}
		if _, exists := result[l.Channel]; exists {
			continue
		}
		result[l.Channel] = l.URL
	}

	ri.logger.Infof("Loaded %d unique logos from iptv-org", len(result))
	return result, nil
}

func (ri *ReferenceImporter) parseCSV(reader io.Reader) ([]*csvChannel, error) {
	r := csv.NewReader(reader)
	r.LazyQuotes = true

	header, err := r.Read()
	if err != nil {
		return nil, fmt.Errorf("failed to read header: %w", err)
	}

	colIdx := make(map[string]int)
	for i, h := range header {
		colIdx[h] = i
	}

	required := []string{"id", "name", "country"}
	for _, col := range required {
		if _, ok := colIdx[col]; !ok {
			return nil, fmt.Errorf("missing required column: %s", col)
		}
	}

	var channels []*csvChannel
	for {
		record, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			ri.logger.Warnf("CSV read error (skipping): %v", err)
			continue
		}

		ch := &csvChannel{
			ID:      getCol(record, colIdx, "id"),
			Name:    getCol(record, colIdx, "name"),
			Country: getCol(record, colIdx, "country"),
		}

		if ch.ID == "" || ch.Name == "" {
			continue
		}

		if altStr := getCol(record, colIdx, "alt_names"); altStr != "" {
			ch.AltNames = splitSemicolon(altStr)
		}

		ch.Network = getCol(record, colIdx, "network")
		ch.Owners = getCol(record, colIdx, "owners")
		ch.IsNSFW = getCol(record, colIdx, "is_nsfw") == "TRUE"
		ch.Launched = getCol(record, colIdx, "launched")
		ch.Closed = getCol(record, colIdx, "closed")
		ch.ReplacedBy = getCol(record, colIdx, "replaced_by")
		ch.Website = getCol(record, colIdx, "website")

		if catStr := getCol(record, colIdx, "categories"); catStr != "" {
			ch.Categories = splitSemicolon(catStr)
		}

		channels = append(channels, ch)
	}

	return channels, nil
}

func (ri *ReferenceImporter) upsertBatch(ctx context.Context, channels []*csvChannel) (int, error) {
	const batchSize = 500
	count := 0

	for i := 0; i < len(channels); i += batchSize {
		end := i + batchSize
		if end > len(channels) {
			end = len(channels)
		}
		batch := channels[i:end]

		n, err := ri.upsertChunk(ctx, batch)
		if err != nil {
			ri.logger.Warnf("Batch at offset %d failed: %v", i, err)
			continue
		}
		count += n

		if (i/batchSize)%10 == 0 {
			ri.logger.Infof("  Progress: %d/%d channels imported", count, len(channels))
		}
	}

	return count, nil
}

func (ri *ReferenceImporter) upsertChunk(ctx context.Context, batch []*csvChannel) (int, error) {
	if len(batch) == 0 {
		return 0, nil
	}

	var sb strings.Builder
	sb.WriteString(`INSERT INTO iptv_reference_channels
		(id, name, alt_names, network, owners, country, categories, is_nsfw, launched, closed, replaced_by, website, logo_url, updated_at)
		VALUES `)

	args := make([]interface{}, 0, len(batch)*13)
	for i, ch := range batch {
		if i > 0 {
			sb.WriteString(",")
		}
		base := i * 13
		fmt.Fprintf(&sb, "($%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d,NOW())",
			base+1, base+2, base+3, base+4, base+5, base+6,
			base+7, base+8, base+9, base+10, base+11, base+12, base+13)

		args = append(args,
			ch.ID, ch.Name, pq.Array(ch.AltNames),
			nullStr(ch.Network), nullStr(ch.Owners), ch.Country,
			pq.Array(ch.Categories), ch.IsNSFW,
			nullStr(ch.Launched), nullStr(ch.Closed),
			nullStr(ch.ReplacedBy), nullStr(ch.Website),
			nullStr(ch.LogoURL))
	}

	sb.WriteString(` ON CONFLICT (id) DO UPDATE SET
		name = EXCLUDED.name,
		alt_names = EXCLUDED.alt_names,
		network = EXCLUDED.network,
		owners = EXCLUDED.owners,
		country = EXCLUDED.country,
		categories = EXCLUDED.categories,
		is_nsfw = EXCLUDED.is_nsfw,
		launched = EXCLUDED.launched,
		closed = EXCLUDED.closed,
		replaced_by = EXCLUDED.replaced_by,
		website = EXCLUDED.website,
		logo_url = COALESCE(EXCLUDED.logo_url, iptv_reference_channels.logo_url),
		updated_at = NOW()`)

	_, err := ri.db.ExecContext(ctx, sb.String(), args...)
	if err != nil {
		return 0, err
	}
	return len(batch), nil
}

func getCol(record []string, idx map[string]int, col string) string {
	i, ok := idx[col]
	if !ok || i >= len(record) {
		return ""
	}
	return strings.TrimSpace(record[i])
}

func splitSemicolon(s string) []string {
	parts := strings.Split(s, ";")
	var result []string
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			result = append(result, p)
		}
	}
	return result
}

func nullStr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
