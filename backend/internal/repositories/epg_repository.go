package repositories

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/romaxa55/iptv-parser/internal/models"
)

func (r *IPTVRepository) GetCurrentProgram(channelID string) (*models.EpgProgram, error) {
	now := time.Now()
	p := &models.EpgProgram{}
	err := r.db.QueryRow(`
		SELECT id, channel_id, title, description, category, icon, start_time, end_time, lang
		FROM iptv_epg_programs
		WHERE channel_id = $1 AND start_time <= $2 AND end_time > $2
		ORDER BY start_time DESC
		LIMIT 1`, channelID, now).Scan(
		&p.ID, &p.ChannelID, &p.Title, &p.Description, &p.Category,
		&p.Icon, &p.StartTime, &p.EndTime, &p.Lang)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return p, err
}

func (r *IPTVRepository) GetUpcomingPrograms(channelID string, limit int) ([]*models.EpgProgram, error) {
	now := time.Now()
	rows, err := r.db.Query(`
		SELECT id, channel_id, title, description, category, icon, start_time, end_time, lang
		FROM iptv_epg_programs
		WHERE channel_id = $1 AND start_time > $2
		ORDER BY start_time ASC
		LIMIT $3`, channelID, now, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var programs []*models.EpgProgram
	for rows.Next() {
		p := &models.EpgProgram{}
		if err := rows.Scan(&p.ID, &p.ChannelID, &p.Title, &p.Description,
			&p.Category, &p.Icon, &p.StartTime, &p.EndTime, &p.Lang); err != nil {
			return nil, err
		}
		programs = append(programs, p)
	}
	return programs, nil
}

func (r *IPTVRepository) InsertEpgProgramsBatch(programs []*models.EpgProgram) (int, error) {
	if len(programs) == 0 {
		return 0, nil
	}

	tx, err := r.db.Begin()
	if err != nil {
		return 0, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`
		INSERT INTO iptv_epg_programs (channel_id, title, description, category, icon, start_time, end_time, lang)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT DO NOTHING`)
	if err != nil {
		return 0, err
	}
	defer stmt.Close()

	count := 0
	for _, p := range programs {
		if _, err := stmt.Exec(p.ChannelID, p.Title, p.Description, p.Category,
			p.Icon, p.StartTime, p.EndTime, p.Lang); err != nil {
			r.logger.Warnf("Failed to insert EPG program for %s: %v", p.ChannelID, err)
			continue
		}
		count++
	}

	if err := tx.Commit(); err != nil {
		return 0, err
	}
	return count, nil
}

func (r *IPTVRepository) DeleteOldEpgPrograms() (int64, error) {
	result, err := r.db.Exec(`
		DELETE FROM iptv_epg_programs
		WHERE end_time < NOW() - INTERVAL '1 day'`)
	if err != nil {
		return 0, err
	}
	return result.RowsAffected()
}

func (r *IPTVRepository) DeleteEpgForChannel(channelID string) error {
	_, err := r.db.Exec("DELETE FROM iptv_epg_programs WHERE channel_id = $1", channelID)
	return err
}

func (r *IPTVRepository) UpsertEpgChannelMap(channelID, epgChannelID string, confidence float64) error {
	_, err := r.db.Exec(`
		INSERT INTO iptv_epg_channel_map (channel_id, epg_channel_id, confidence, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (channel_id, epg_channel_id) DO UPDATE SET confidence = EXCLUDED.confidence`,
		channelID, epgChannelID, confidence)
	return err
}

func (r *IPTVRepository) GetEpgChannelMap() (map[string]string, error) {
	rows, err := r.db.Query(`
		SELECT channel_id, epg_channel_id
		FROM iptv_epg_channel_map
		ORDER BY confidence DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	m := make(map[string]string)
	for rows.Next() {
		var channelID, epgChannelID string
		if err := rows.Scan(&channelID, &epgChannelID); err != nil {
			return nil, err
		}
		if _, exists := m[epgChannelID]; !exists {
			m[epgChannelID] = channelID
		}
	}
	return m, nil
}

func (r *IPTVRepository) GetAllChannelTvgIDs() (map[string]string, error) {
	rows, err := r.db.Query(`
		SELECT id, tvg_id FROM iptv_channels WHERE tvg_id IS NOT NULL AND tvg_id != ''`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	m := make(map[string]string)
	for rows.Next() {
		var id, tvgID string
		if err := rows.Scan(&id, &tvgID); err != nil {
			return nil, err
		}
		m[tvgID] = id
	}
	return m, nil
}

func (r *IPTVRepository) GetAllChannelNames() (map[string]string, error) {
	rows, err := r.db.Query("SELECT id, name FROM iptv_channels")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	m := make(map[string]string)
	for rows.Next() {
		var id, name string
		if err := rows.Scan(&id, &name); err != nil {
			return nil, err
		}
		m[name] = id
	}
	return m, nil
}
