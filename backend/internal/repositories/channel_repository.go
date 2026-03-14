package repositories

import (
	"database/sql"
	"fmt"
	"strings"

	"github.com/romaxa55/iptv-parser/internal/models"
)

type ChannelFilters struct {
	Group  *string
	Search *string
	Limit  int
	Offset int
}

type ChannelWithEPG struct {
	models.Channel
	HasEPG bool `json:"hasEpg"`
}

func (r *IPTVRepository) GetChannels(filters ChannelFilters) ([]*ChannelWithEPG, int, error) {
	var conditions []string
	var args []interface{}
	argIdx := 1

	if filters.Group != nil && *filters.Group != "" {
		conditions = append(conditions, fmt.Sprintf("c.group_title = $%d", argIdx))
		args = append(args, *filters.Group)
		argIdx++
	}
	if filters.Search != nil && *filters.Search != "" {
		conditions = append(conditions, fmt.Sprintf("c.name ILIKE $%d", argIdx))
		args = append(args, "%"+*filters.Search+"%")
		argIdx++
	}

	where := ""
	if len(conditions) > 0 {
		where = "WHERE " + strings.Join(conditions, " AND ")
	}

	var total int
	countQ := fmt.Sprintf("SELECT COUNT(*) FROM channels c %s", where)
	if err := r.db.QueryRow(countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count: %w", err)
	}

	query := fmt.Sprintf(`
		SELECT c.id, c.name, c.group_title, c.stream_url, c.tvg_rec, c.logo_url, c.thumbnail_url,
		       EXISTS(SELECT 1 FROM epg_programs ep WHERE ep.channel_id = c.id LIMIT 1) as has_epg
		FROM channels c
		%s
		ORDER BY c.name ASC
		LIMIT $%d OFFSET $%d`, where, argIdx, argIdx+1)

	args = append(args, filters.Limit, filters.Offset)

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("channels query: %w", err)
	}
	defer rows.Close()

	var channels []*ChannelWithEPG
	for rows.Next() {
		ch := &ChannelWithEPG{}
		if err := rows.Scan(
			&ch.ID, &ch.Name, &ch.GroupTitle, &ch.StreamURL, &ch.TvgRec,
			&ch.LogoURL, &ch.ThumbnailURL, &ch.HasEPG,
		); err != nil {
			return nil, 0, fmt.Errorf("scan: %w", err)
		}
		channels = append(channels, ch)
	}
	return channels, total, nil
}

func (r *IPTVRepository) GetChannelByID(id int) (*ChannelWithEPG, error) {
	ch := &ChannelWithEPG{}
	err := r.db.QueryRow(`
		SELECT c.id, c.name, c.group_title, c.stream_url, c.tvg_rec, c.logo_url, c.thumbnail_url,
		       EXISTS(SELECT 1 FROM epg_programs ep WHERE ep.channel_id = c.id LIMIT 1) as has_epg
		FROM channels c
		WHERE c.id = $1`, id).Scan(
		&ch.ID, &ch.Name, &ch.GroupTitle, &ch.StreamURL, &ch.TvgRec,
		&ch.LogoURL, &ch.ThumbnailURL, &ch.HasEPG,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return ch, err
}

func (r *IPTVRepository) GetCategories() ([]CategoryStat, error) {
	rows, err := r.db.Query(`
		SELECT group_title, COUNT(*) as channel_count
		FROM channels
		WHERE group_title != ''
		GROUP BY group_title
		ORDER BY channel_count DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var stats []CategoryStat
	for rows.Next() {
		var s CategoryStat
		if err := rows.Scan(&s.Category, &s.ChannelCount); err != nil {
			return nil, err
		}
		stats = append(stats, s)
	}
	return stats, nil
}

type CategoryStat struct {
	Category     string `json:"category"`
	ChannelCount int    `json:"channelCount"`
}

func (r *IPTVRepository) GetFeaturedChannels(limit int) ([]*ChannelWithEPG, error) {
	rows, err := r.db.Query(`
		SELECT c.id, c.name, c.group_title, c.stream_url, c.tvg_rec, c.logo_url, c.thumbnail_url,
		       EXISTS(SELECT 1 FROM epg_programs ep WHERE ep.channel_id = c.id LIMIT 1) as has_epg
		FROM channels c
		WHERE c.group_title NOT IN ('Взрослые')
		ORDER BY RANDOM()
		LIMIT $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var channels []*ChannelWithEPG
	for rows.Next() {
		ch := &ChannelWithEPG{}
		if err := rows.Scan(
			&ch.ID, &ch.Name, &ch.GroupTitle, &ch.StreamURL, &ch.TvgRec,
			&ch.LogoURL, &ch.ThumbnailURL, &ch.HasEPG,
		); err != nil {
			return nil, err
		}
		channels = append(channels, ch)
	}
	return channels, nil
}

func (r *IPTVRepository) GetStreamURL(channelID int) (string, error) {
	var url string
	err := r.db.QueryRow("SELECT stream_url FROM channels WHERE id = $1", channelID).Scan(&url)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return url, err
}

func (r *IPTVRepository) GetStats() (*Stats, error) {
	s := &Stats{}
	err := r.db.QueryRow(`
		SELECT
			(SELECT COUNT(*) FROM channels),
			(SELECT COUNT(DISTINCT group_title) FROM channels WHERE group_title != ''),
			(SELECT COUNT(DISTINCT channel_id) FROM epg_programs)
	`).Scan(&s.TotalChannels, &s.TotalGroups, &s.ChannelsWithEPG)
	return s, err
}

type Stats struct {
	TotalChannels   int `json:"totalChannels"`
	TotalGroups     int `json:"totalGroups"`
	ChannelsWithEPG int `json:"channelsWithEpg"`
}

func (r *IPTVRepository) UpsertChannelsBatch(channels []*models.Channel) (int, error) {
	if len(channels) == 0 {
		return 0, nil
	}

	const batchSize = 500
	total := 0

	for i := 0; i < len(channels); i += batchSize {
		end := i + batchSize
		if end > len(channels) {
			end = len(channels)
		}
		chunk := channels[i:end]

		var b strings.Builder
		b.WriteString("INSERT INTO channels (name, group_title, stream_url, tvg_rec) VALUES ")

		args := make([]interface{}, 0, len(chunk)*4)
		for j, ch := range chunk {
			if j > 0 {
				b.WriteString(",")
			}
			base := j*4 + 1
			fmt.Fprintf(&b, "($%d,$%d,$%d,$%d)", base, base+1, base+2, base+3)
			args = append(args, ch.Name, ch.GroupTitle, ch.StreamURL, ch.TvgRec)
		}
		b.WriteString(` ON CONFLICT (stream_url) DO UPDATE SET
			name = EXCLUDED.name,
			group_title = EXCLUDED.group_title,
			tvg_rec = EXCLUDED.tvg_rec,
			updated_at = NOW()`)

		_, err := r.db.Exec(b.String(), args...)
		if err != nil {
			r.logger.Warnf("batch upsert channels failed at %d: %v", i, err)
			continue
		}
		total += len(chunk)
	}
	return total, nil
}

func (r *IPTVRepository) GetAllChannelsByName() (map[string]int, error) {
	rows, err := r.db.Query("SELECT id, name FROM channels")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	m := make(map[string]int)
	for rows.Next() {
		var id int
		var name string
		if err := rows.Scan(&id, &name); err != nil {
			return nil, err
		}
		m[name] = id
	}
	return m, nil
}

func (r *IPTVRepository) TruncateChannels() error {
	_, err := r.db.Exec("TRUNCATE channels CASCADE")
	return err
}
