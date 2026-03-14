package repositories

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/romaxa55/iptv-parser/internal/models"
)

type NowPlayingItem struct {
	ChannelID    int                `json:"channelId"`
	ChannelName  string             `json:"channelName"`
	GroupTitle   string             `json:"groupTitle"`
	LogoURL      *string            `json:"logoUrl,omitempty"`
	ThumbnailURL *string            `json:"thumbnailUrl,omitempty"`
	Program      *models.EpgProgram `json:"program"`
}

func (r *IPTVRepository) GetCurrentProgram(channelID int) (*models.EpgProgram, error) {
	now := time.Now()
	p := &models.EpgProgram{}
	err := r.db.QueryRow(`
		SELECT id, channel_id, title, description, category, icon, start_time, end_time, lang
		FROM epg_programs
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

func (r *IPTVRepository) GetProgramsForChannel(channelID int, limit int) ([]*models.EpgProgram, error) {
	now := time.Now()
	rows, err := r.db.Query(`
		SELECT id, channel_id, title, description, category, icon, start_time, end_time, lang
		FROM epg_programs
		WHERE channel_id = $1 AND end_time > $2
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

func (r *IPTVRepository) GetNowPlaying() ([]*NowPlayingItem, error) {
	now := time.Now()
	rows, err := r.db.Query(`
		SELECT c.id, c.name, c.group_title, c.logo_url, c.thumbnail_url,
		       ep.id, ep.channel_id, ep.title, ep.description, ep.category, ep.icon,
		       ep.start_time, ep.end_time, ep.lang
		FROM epg_programs ep
		JOIN channels c ON c.id = ep.channel_id
		WHERE ep.start_time <= $1 AND ep.end_time > $1
		  AND c.group_title NOT IN ('Взрослые')
		ORDER BY c.name ASC`, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*NowPlayingItem
	for rows.Next() {
		item := &NowPlayingItem{}
		p := &models.EpgProgram{}
		if err := rows.Scan(
			&item.ChannelID, &item.ChannelName, &item.GroupTitle, &item.LogoURL, &item.ThumbnailURL,
			&p.ID, &p.ChannelID, &p.Title, &p.Description, &p.Category, &p.Icon,
			&p.StartTime, &p.EndTime, &p.Lang,
		); err != nil {
			return nil, err
		}
		item.Program = p
		items = append(items, item)
	}
	return items, nil
}

func (r *IPTVRepository) GetUpcomingAll(withinMinutes int, limit int) ([]*NowPlayingItem, error) {
	now := time.Now()
	until := now.Add(time.Duration(withinMinutes) * time.Minute)
	rows, err := r.db.Query(`
		SELECT c.id, c.name, c.group_title, c.logo_url, c.thumbnail_url,
		       ep.id, ep.channel_id, ep.title, ep.description, ep.category, ep.icon,
		       ep.start_time, ep.end_time, ep.lang
		FROM epg_programs ep
		JOIN channels c ON c.id = ep.channel_id
		WHERE ep.start_time > $1 AND ep.start_time <= $2
		  AND c.group_title NOT IN ('Взрослые')
		ORDER BY ep.start_time ASC
		LIMIT $3`, now, until, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*NowPlayingItem
	for rows.Next() {
		item := &NowPlayingItem{}
		p := &models.EpgProgram{}
		if err := rows.Scan(
			&item.ChannelID, &item.ChannelName, &item.GroupTitle, &item.LogoURL, &item.ThumbnailURL,
			&p.ID, &p.ChannelID, &p.Title, &p.Description, &p.Category, &p.Icon,
			&p.StartTime, &p.EndTime, &p.Lang,
		); err != nil {
			return nil, err
		}
		item.Program = p
		items = append(items, item)
	}
	return items, nil
}

func (r *IPTVRepository) GetFeaturedNowPlaying(limit int) ([]*NowPlayingItem, error) {
	now := time.Now()
	rows, err := r.db.Query(`
		SELECT c.id, c.name, c.group_title, c.logo_url, c.thumbnail_url,
		       ep.id, ep.channel_id, ep.title, ep.description, ep.category, ep.icon,
		       ep.start_time, ep.end_time, ep.lang
		FROM epg_programs ep
		JOIN channels c ON c.id = ep.channel_id
		WHERE ep.start_time <= $1 AND ep.end_time > $1
		  AND c.group_title NOT IN ('Взрослые')
		ORDER BY
		  CASE WHEN ep.icon IS NOT NULL AND ep.icon != '' THEN 0 ELSE 1 END,
		  ep.end_time - ep.start_time DESC
		LIMIT $2`, now, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*NowPlayingItem
	for rows.Next() {
		item := &NowPlayingItem{}
		p := &models.EpgProgram{}
		if err := rows.Scan(
			&item.ChannelID, &item.ChannelName, &item.GroupTitle, &item.LogoURL, &item.ThumbnailURL,
			&p.ID, &p.ChannelID, &p.Title, &p.Description, &p.Category, &p.Icon,
			&p.StartTime, &p.EndTime, &p.Lang,
		); err != nil {
			return nil, err
		}
		item.Program = p
		items = append(items, item)
	}
	return items, nil
}

func (r *IPTVRepository) InsertEpgProgramsBatch(programs []*models.EpgProgram) (int, error) {
	if len(programs) == 0 {
		return 0, nil
	}

	const chunkSize = 100
	total := 0

	for i := 0; i < len(programs); i += chunkSize {
		end := i + chunkSize
		if end > len(programs) {
			end = len(programs)
		}
		chunk := programs[i:end]

		query := "INSERT INTO epg_programs (channel_id, title, description, category, icon, start_time, end_time, lang) VALUES "
		args := make([]interface{}, 0, len(chunk)*8)
		for j, p := range chunk {
			if j > 0 {
				query += ","
			}
			base := j * 8
			query += fmt.Sprintf("($%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d)",
				base+1, base+2, base+3, base+4, base+5, base+6, base+7, base+8)
			args = append(args, p.ChannelID, p.Title, p.Description,
				p.Category, p.Icon, p.StartTime, p.EndTime, p.Lang)
		}
		query += " ON CONFLICT DO NOTHING"

		result, err := r.db.Exec(query, args...)
		if err != nil {
			r.logger.Warnf("Failed to insert EPG batch chunk at %d: %v", i, err)
			continue
		}
		n, _ := result.RowsAffected()
		total += int(n)
	}

	return total, nil
}

func (r *IPTVRepository) DeleteOldEpgPrograms() (int64, error) {
	result, err := r.db.Exec("DELETE FROM epg_programs WHERE end_time < NOW() - INTERVAL '1 day'")
	if err != nil {
		return 0, err
	}
	return result.RowsAffected()
}

func (r *IPTVRepository) TruncateEpgPrograms() error {
	_, err := r.db.Exec("TRUNCATE epg_programs")
	return err
}

func (r *IPTVRepository) GetConfig() (playlistURL, epgURL string, err error) {
	err = r.db.QueryRow("SELECT playlist_url, epg_url FROM config WHERE id = 1").Scan(&playlistURL, &epgURL)
	return
}

func (r *IPTVRepository) UpsertConfig(playlistURL, epgURL string) error {
	_, err := r.db.Exec(`
		INSERT INTO config (id, playlist_url, epg_url) VALUES (1, $1, $2)
		ON CONFLICT (id) DO UPDATE SET
			playlist_url = CASE WHEN $1 != '' THEN $1 ELSE config.playlist_url END,
			epg_url = CASE WHEN $2 != '' THEN $2 ELSE config.epg_url END`,
		playlistURL, epgURL)
	return err
}

func (r *IPTVRepository) UpdateSyncTime(field string) error {
	query := fmt.Sprintf("UPDATE config SET %s = NOW() WHERE id = 1", field)
	_, err := r.db.Exec(query)
	return err
}
