package repositories

import (
	"time"

	"github.com/romaxa55/iptv-parser/internal/models"
)

func (r *IPTVRepository) UpsertSource(src *models.Source) (int, error) {
	var id int
	err := r.db.QueryRow(`
		INSERT INTO iptv_sources (url, name, source_type, status, created_at)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (url) DO UPDATE SET
			name = COALESCE(EXCLUDED.name, iptv_sources.name),
			status = EXCLUDED.status
		RETURNING id`,
		src.URL, src.Name, src.SourceType, src.Status).Scan(&id)
	return id, err
}

func (r *IPTVRepository) UpdateSourceStats(sourceID int, channelCount int) error {
	_, err := r.db.Exec(`
		UPDATE iptv_sources
		SET last_parsed_at = $2, channel_count = $3
		WHERE id = $1`,
		sourceID, time.Now(), channelCount)
	return err
}

func (r *IPTVRepository) GetActiveSources() ([]*models.Source, error) {
	rows, err := r.db.Query(`
		SELECT id, url, name, source_type, last_parsed_at, status, channel_count
		FROM iptv_sources
		WHERE status = 'active'
		ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sources []*models.Source
	for rows.Next() {
		s := &models.Source{}
		if err := rows.Scan(&s.ID, &s.URL, &s.Name, &s.SourceType, &s.LastParsedAt, &s.Status, &s.ChannelCount); err != nil {
			return nil, err
		}
		sources = append(sources, s)
	}
	return sources, nil
}
