package repositories

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"github.com/romaxa55/iptv-parser/internal/models"
)

func (r *IPTVRepository) UpsertChannel(ch *models.Channel) error {
	query := `
		INSERT INTO iptv_channels (id, name, url, logo_url, group_title, country, language, tvg_id, source_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name,
			url = EXCLUDED.url,
			logo_url = COALESCE(EXCLUDED.logo_url, iptv_channels.logo_url),
			group_title = COALESCE(EXCLUDED.group_title, iptv_channels.group_title),
			country = COALESCE(EXCLUDED.country, iptv_channels.country),
			language = COALESCE(EXCLUDED.language, iptv_channels.language),
			tvg_id = COALESCE(EXCLUDED.tvg_id, iptv_channels.tvg_id),
			source_id = COALESCE(EXCLUDED.source_id, iptv_channels.source_id),
			updated_at = NOW()`

	_, err := r.db.Exec(query, ch.ID, ch.Name, ch.URL, ch.LogoURL, ch.GroupTitle,
		ch.Country, ch.Language, ch.TvgID, ch.SourceID)
	return err
}

func (r *IPTVRepository) UpsertChannelsBatch(channels []*models.Channel) (int, error) {
	if len(channels) == 0 {
		return 0, nil
	}

	tx, err := r.db.Begin()
	if err != nil {
		return 0, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`
		INSERT INTO iptv_channels (id, name, url, logo_url, group_title, country, language, tvg_id, source_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
		ON CONFLICT (id) DO UPDATE SET
			name = EXCLUDED.name,
			url = EXCLUDED.url,
			logo_url = COALESCE(EXCLUDED.logo_url, iptv_channels.logo_url),
			group_title = COALESCE(EXCLUDED.group_title, iptv_channels.group_title),
			country = COALESCE(EXCLUDED.country, iptv_channels.country),
			language = COALESCE(EXCLUDED.language, iptv_channels.language),
			tvg_id = COALESCE(EXCLUDED.tvg_id, iptv_channels.tvg_id),
			source_id = COALESCE(EXCLUDED.source_id, iptv_channels.source_id),
			updated_at = NOW()`)
	if err != nil {
		return 0, fmt.Errorf("failed to prepare statement: %w", err)
	}
	defer stmt.Close()

	count := 0
	for _, ch := range channels {
		if _, err := stmt.Exec(ch.ID, ch.Name, ch.URL, ch.LogoURL, ch.GroupTitle,
			ch.Country, ch.Language, ch.TvgID, ch.SourceID); err != nil {
			r.logger.Warnf("Failed to upsert channel %s: %v", ch.ID, err)
			continue
		}
		count++
	}

	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("failed to commit: %w", err)
	}
	return count, nil
}

type ChannelFilters struct {
	Group  *string
	Limit  int
	Offset int
}

func (r *IPTVRepository) GetChannels(filters ChannelFilters) ([]*models.Channel, error) {
	var conditions []string
	var args []interface{}
	argIdx := 1

	if filters.Group != nil {
		conditions = append(conditions, fmt.Sprintf("group_title = $%d", argIdx))
		args = append(args, *filters.Group)
		argIdx++
	}

	query := "SELECT id, name, url, logo_url, group_title, country, language, tvg_id, is_working, thumbnail_url FROM iptv_channels"
	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}
	query += " ORDER BY name ASC"

	if filters.Limit > 0 {
		query += fmt.Sprintf(" LIMIT $%d", argIdx)
		args = append(args, filters.Limit)
		argIdx++
	}
	if filters.Offset > 0 {
		query += fmt.Sprintf(" OFFSET $%d", argIdx)
		args = append(args, filters.Offset)
	}

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query channels: %w", err)
	}
	defer rows.Close()

	var channels []*models.Channel
	for rows.Next() {
		ch := &models.Channel{}
		if err := rows.Scan(&ch.ID, &ch.Name, &ch.URL, &ch.LogoURL, &ch.GroupTitle,
			&ch.Country, &ch.Language, &ch.TvgID, &ch.IsWorking, &ch.ThumbnailURL); err != nil {
			return nil, fmt.Errorf("failed to scan channel: %w", err)
		}
		channels = append(channels, ch)
	}
	return channels, nil
}

func (r *IPTVRepository) GetFeaturedChannels(limit int) ([]*models.Channel, error) {
	query := `
		SELECT id, name, url, logo_url, group_title, country, language, tvg_id, is_working, thumbnail_url
		FROM iptv_channels
		WHERE is_working = true
		ORDER BY RANDOM()
		LIMIT $1`

	rows, err := r.db.Query(query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query featured channels: %w", err)
	}
	defer rows.Close()

	var channels []*models.Channel
	for rows.Next() {
		ch := &models.Channel{}
		if err := rows.Scan(&ch.ID, &ch.Name, &ch.URL, &ch.LogoURL, &ch.GroupTitle,
			&ch.Country, &ch.Language, &ch.TvgID, &ch.IsWorking, &ch.ThumbnailURL); err != nil {
			return nil, fmt.Errorf("failed to scan featured channel: %w", err)
		}
		channels = append(channels, ch)
	}
	return channels, nil
}

func (r *IPTVRepository) GetGroups() ([]*models.ChannelGroup, error) {
	query := `
		SELECT group_title, COUNT(*) as channel_count
		FROM iptv_channels
		WHERE group_title IS NOT NULL AND group_title != ''
		GROUP BY group_title
		ORDER BY channel_count DESC`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to query groups: %w", err)
	}
	defer rows.Close()

	var groups []*models.ChannelGroup
	for rows.Next() {
		g := &models.ChannelGroup{}
		if err := rows.Scan(&g.Name, &g.ChannelCount); err != nil {
			return nil, fmt.Errorf("failed to scan group: %w", err)
		}
		groups = append(groups, g)
	}
	return groups, nil
}

func (r *IPTVRepository) GetChannelByID(id string) (*models.Channel, error) {
	ch := &models.Channel{}
	err := r.db.QueryRow(`
		SELECT id, name, url, logo_url, group_title, country, language, tvg_id,
		       is_working, last_checked_at, video_codec, audio_codec, resolution,
		       thumbnail_url, thumbnail_updated_at, created_at, updated_at
		FROM iptv_channels WHERE id = $1`, id).Scan(
		&ch.ID, &ch.Name, &ch.URL, &ch.LogoURL, &ch.GroupTitle, &ch.Country,
		&ch.Language, &ch.TvgID, &ch.IsWorking, &ch.LastCheckedAt,
		&ch.VideoCodec, &ch.AudioCodec, &ch.Resolution,
		&ch.ThumbnailURL, &ch.ThumbnailUpdatedAt, &ch.CreatedAt, &ch.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return ch, err
}

func (r *IPTVRepository) UpdateChannelCheckResult(channelID string, isWorking bool, videoCodec, audioCodec, resolution *string) error {
	_, err := r.db.Exec(`
		UPDATE iptv_channels
		SET is_working = $2, last_checked_at = $3, video_codec = $4, audio_codec = $5, resolution = $6, updated_at = NOW()
		WHERE id = $1`,
		channelID, isWorking, time.Now(), videoCodec, audioCodec, resolution)
	return err
}

func (r *IPTVRepository) UpdateChannelThumbnail(channelID, thumbnailURL string) error {
	_, err := r.db.Exec(`
		UPDATE iptv_channels
		SET thumbnail_url = $2, thumbnail_updated_at = $3, updated_at = NOW()
		WHERE id = $1`,
		channelID, thumbnailURL, time.Now())
	return err
}

func (r *IPTVRepository) GetChannelsForCheck(limit int) ([]*models.Channel, error) {
	query := `
		SELECT id, name, url
		FROM iptv_channels
		WHERE last_checked_at IS NULL
		   OR last_checked_at < NOW() - INTERVAL '30 minutes'
		ORDER BY last_checked_at ASC NULLS FIRST
		LIMIT $1`

	rows, err := r.db.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var channels []*models.Channel
	for rows.Next() {
		ch := &models.Channel{}
		if err := rows.Scan(&ch.ID, &ch.Name, &ch.URL); err != nil {
			return nil, err
		}
		channels = append(channels, ch)
	}
	return channels, nil
}

func (r *IPTVRepository) GetWorkingChannelsForThumbnail(limit int) ([]*models.Channel, error) {
	query := `
		SELECT id, name, url
		FROM iptv_channels
		WHERE is_working = true
		  AND (thumbnail_updated_at IS NULL OR thumbnail_updated_at < NOW() - INTERVAL '15 minutes')
		ORDER BY thumbnail_updated_at ASC NULLS FIRST
		LIMIT $1`

	rows, err := r.db.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var channels []*models.Channel
	for rows.Next() {
		ch := &models.Channel{}
		if err := rows.Scan(&ch.ID, &ch.Name, &ch.URL); err != nil {
			return nil, err
		}
		channels = append(channels, ch)
	}
	return channels, nil
}

func (r *IPTVRepository) GetTotalChannelCount() (int, error) {
	var count int
	err := r.db.QueryRow("SELECT COUNT(*) FROM iptv_channels").Scan(&count)
	return count, err
}

func (r *IPTVRepository) GetWorkingChannelCount() (int, error) {
	var count int
	err := r.db.QueryRow("SELECT COUNT(*) FROM iptv_channels WHERE is_working = true").Scan(&count)
	return count, err
}

func (r *IPTVRepository) RefreshGroupCounts() error {
	_, err := r.db.Exec(`
		INSERT INTO iptv_groups (name, channel_count)
		SELECT group_title, COUNT(*)
		FROM iptv_channels
		WHERE group_title IS NOT NULL AND group_title != ''
		GROUP BY group_title
		ON CONFLICT (name) DO UPDATE SET channel_count = EXCLUDED.channel_count`)
	return err
}
