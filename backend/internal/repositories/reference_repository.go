package repositories

import (
	"database/sql"
	"fmt"
	"strings"

	"github.com/lib/pq"
	"github.com/romaxa55/iptv-parser/internal/models"
)

type ChannelWithStreams struct {
	models.ReferenceChannel
	StreamCount  int  `json:"streamCount"`
	WorkingCount int  `json:"workingCount"`
	HasEPG       bool `json:"hasEpg"`
}

type ReferenceChannelFilters struct {
	Country    *string
	Category   *string
	Search     *string
	HasStreams bool
	Limit      int
	Offset     int
}

func (r *IPTVRepository) GetReferenceChannels(filters ReferenceChannelFilters) ([]*ChannelWithStreams, int, error) {
	var conditions []string
	var args []interface{}
	argIdx := 1

	conditions = append(conditions, "s.stream_count > 0")

	if filters.Country != nil && *filters.Country != "" {
		conditions = append(conditions, fmt.Sprintf("rc.country = $%d", argIdx))
		args = append(args, *filters.Country)
		argIdx++
	}
	if filters.Category != nil && *filters.Category != "" {
		conditions = append(conditions, fmt.Sprintf("$%d = ANY(rc.categories)", argIdx))
		args = append(args, *filters.Category)
		argIdx++
	}
	if filters.Search != nil && *filters.Search != "" {
		conditions = append(conditions, fmt.Sprintf("(rc.name ILIKE $%d OR $%d = ANY(rc.alt_names))", argIdx, argIdx))
		args = append(args, "%"+*filters.Search+"%")
		argIdx++
	}

	where := ""
	if len(conditions) > 0 {
		where = "WHERE " + strings.Join(conditions, " AND ")
	}

	countQuery := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM iptv_reference_channels rc
		JOIN (
			SELECT channel_id,
			       COUNT(*) as stream_count,
			       COUNT(*) FILTER (WHERE is_working = true) as working_count
			FROM iptv_streams
			GROUP BY channel_id
		) s ON s.channel_id = rc.id
		%s`, where)

	var total int
	if err := r.db.QueryRow(countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count query: %w", err)
	}

	query := fmt.Sprintf(`
		SELECT rc.id, rc.name, rc.alt_names, rc.network, rc.country, rc.categories,
		       rc.is_nsfw, rc.logo_url,
		       s.stream_count, s.working_count,
		       EXISTS(SELECT 1 FROM iptv_epg_programs ep WHERE ep.reference_channel_id = rc.id LIMIT 1) as has_epg
		FROM iptv_reference_channels rc
		JOIN (
			SELECT channel_id,
			       COUNT(*) as stream_count,
			       COUNT(*) FILTER (WHERE is_working = true) as working_count
			FROM iptv_streams
			GROUP BY channel_id
		) s ON s.channel_id = rc.id
		%s
		ORDER BY s.working_count DESC, rc.name ASC
		LIMIT $%d OFFSET $%d`, where, argIdx, argIdx+1)

	args = append(args, filters.Limit, filters.Offset)

	rows, err := r.db.Query(query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("channels query: %w", err)
	}
	defer rows.Close()

	var channels []*ChannelWithStreams
	for rows.Next() {
		ch := &ChannelWithStreams{}
		if err := rows.Scan(
			&ch.ID, &ch.Name, &ch.AltNames, &ch.Network, &ch.Country, &ch.Categories,
			&ch.IsNSFW, &ch.LogoURL,
			&ch.StreamCount, &ch.WorkingCount, &ch.HasEPG,
		); err != nil {
			return nil, 0, fmt.Errorf("scan: %w", err)
		}
		channels = append(channels, ch)
	}
	return channels, total, nil
}

func (r *IPTVRepository) GetReferenceChannelByID(id string) (*ChannelWithStreams, error) {
	ch := &ChannelWithStreams{}
	err := r.db.QueryRow(`
		SELECT rc.id, rc.name, rc.alt_names, rc.network, rc.owners, rc.country,
		       rc.categories, rc.is_nsfw, rc.launched, rc.closed, rc.replaced_by,
		       rc.website, rc.logo_url,
		       COALESCE(s.stream_count, 0), COALESCE(s.working_count, 0),
		       EXISTS(SELECT 1 FROM iptv_epg_programs ep WHERE ep.reference_channel_id = rc.id LIMIT 1)
		FROM iptv_reference_channels rc
		LEFT JOIN (
			SELECT channel_id,
			       COUNT(*) as stream_count,
			       COUNT(*) FILTER (WHERE is_working = true) as working_count
			FROM iptv_streams
			GROUP BY channel_id
		) s ON s.channel_id = rc.id
		WHERE rc.id = $1`, id).Scan(
		&ch.ID, &ch.Name, &ch.AltNames, &ch.Network, &ch.Owners, &ch.Country,
		&ch.Categories, &ch.IsNSFW, &ch.Launched, &ch.Closed, &ch.ReplacedBy,
		&ch.Website, &ch.LogoURL,
		&ch.StreamCount, &ch.WorkingCount, &ch.HasEPG,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return ch, err
}

func (r *IPTVRepository) GetCountries() ([]CountryStat, error) {
	rows, err := r.db.Query(`
		SELECT rc.country, COUNT(DISTINCT rc.id) as channel_count
		FROM iptv_reference_channels rc
		JOIN iptv_streams s ON s.channel_id = rc.id
		WHERE rc.country != ''
		GROUP BY rc.country
		ORDER BY channel_count DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var stats []CountryStat
	for rows.Next() {
		var s CountryStat
		if err := rows.Scan(&s.Country, &s.ChannelCount); err != nil {
			return nil, err
		}
		stats = append(stats, s)
	}
	return stats, nil
}

type CountryStat struct {
	Country      string `json:"country"`
	ChannelCount int    `json:"channelCount"`
}

func (r *IPTVRepository) GetCategoriesWithCounts() ([]CategoryStat, error) {
	rows, err := r.db.Query(`
		SELECT cat, COUNT(DISTINCT rc.id) as channel_count
		FROM iptv_reference_channels rc
		JOIN iptv_streams s ON s.channel_id = rc.id,
		LATERAL unnest(rc.categories) AS cat
		GROUP BY cat
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

func (r *IPTVRepository) GetFeaturedReferenceChannels(limit int) ([]*ChannelWithStreams, error) {
	rows, err := r.db.Query(`
		SELECT rc.id, rc.name, rc.alt_names, rc.network, rc.country, rc.categories,
		       rc.is_nsfw, rc.logo_url,
		       s.stream_count, s.working_count,
		       EXISTS(SELECT 1 FROM iptv_epg_programs ep WHERE ep.reference_channel_id = rc.id LIMIT 1)
		FROM iptv_reference_channels rc
		JOIN (
			SELECT channel_id,
			       COUNT(*) as stream_count,
			       COUNT(*) FILTER (WHERE is_working = true) as working_count
			FROM iptv_streams
			GROUP BY channel_id
		) s ON s.channel_id = rc.id
		WHERE s.working_count > 0 AND rc.logo_url IS NOT NULL AND rc.is_nsfw = false
		ORDER BY RANDOM()
		LIMIT $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var channels []*ChannelWithStreams
	for rows.Next() {
		ch := &ChannelWithStreams{}
		if err := rows.Scan(
			&ch.ID, &ch.Name, &ch.AltNames, &ch.Network, &ch.Country, &ch.Categories,
			&ch.IsNSFW, &ch.LogoURL,
			&ch.StreamCount, &ch.WorkingCount, &ch.HasEPG,
		); err != nil {
			return nil, err
		}
		channels = append(channels, ch)
	}
	return channels, nil
}

func (r *IPTVRepository) GetStreamsByChannelFull(channelID string) ([]*models.Stream, error) {
	rows, err := r.db.Query(`
		SELECT id, channel_id, url, source_id, original_name, original_group,
		       quality, feed, timeshift_hours, is_working, last_checked_at,
		       response_time_ms, video_codec, audio_codec, resolution,
		       uptime_pct, check_count, ok_count
		FROM iptv_streams
		WHERE channel_id = $1
		ORDER BY
			is_working DESC NULLS LAST,
			uptime_pct DESC,
			response_time_ms ASC NULLS LAST`, channelID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var streams []*models.Stream
	for rows.Next() {
		s := &models.Stream{}
		if err := rows.Scan(
			&s.ID, &s.ChannelID, &s.URL, &s.SourceID, &s.OriginalName, &s.OriginalGroup,
			&s.Quality, &s.Feed, &s.TimeshiftHours, &s.IsWorking, &s.LastCheckedAt,
			&s.ResponseTimeMs, &s.VideoCodec, &s.AudioCodec, &s.Resolution,
			&s.UptimePct, &s.CheckCount, &s.OkCount,
		); err != nil {
			return nil, err
		}
		streams = append(streams, s)
	}
	return streams, nil
}

func (r *IPTVRepository) GetStats() (*Stats, error) {
	s := &Stats{}
	err := r.db.QueryRow(`
		SELECT
			(SELECT COUNT(*) FROM iptv_reference_channels),
			(SELECT COUNT(*) FROM iptv_streams),
			(SELECT COUNT(*) FROM iptv_streams WHERE is_working = true),
			(SELECT COUNT(*) FROM iptv_unmatched_streams),
			(SELECT COUNT(*) FROM iptv_sources WHERE status = 'active'),
			(SELECT COUNT(DISTINCT country) FROM iptv_reference_channels rc JOIN iptv_streams s ON s.channel_id = rc.id)
	`).Scan(&s.TotalChannels, &s.TotalStreams, &s.WorkingStreams, &s.UnmatchedStreams, &s.ActiveSources, &s.Countries)

	if err != nil {
		return nil, err
	}

	_ = r.db.QueryRow(`SELECT COUNT(DISTINCT reference_channel_id) FROM iptv_epg_programs WHERE reference_channel_id IS NOT NULL`).Scan(&s.ChannelsWithEPG)

	return s, nil
}

type Stats struct {
	TotalChannels   int `json:"totalChannels"`
	TotalStreams     int `json:"totalStreams"`
	WorkingStreams   int `json:"workingStreams"`
	UnmatchedStreams int `json:"unmatchedStreams"`
	ActiveSources   int `json:"activeSources"`
	Countries       int `json:"countries"`
	ChannelsWithEPG int `json:"channelsWithEpg"`
}

func init() {
	_ = pq.StringArray{}
}
