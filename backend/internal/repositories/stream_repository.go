package repositories

import (
	"github.com/romaxa55/iptv-parser/internal/models"
)

func (r *IPTVRepository) UpsertStream(s *models.Stream) (int, error) {
	var id int
	err := r.db.QueryRow(`
		INSERT INTO iptv_streams (channel_id, url, source_id, original_name, original_group, quality, feed, timeshift_hours, is_working, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
		ON CONFLICT (url) DO UPDATE SET
			channel_id = COALESCE(EXCLUDED.channel_id, iptv_streams.channel_id),
			source_id = COALESCE(EXCLUDED.source_id, iptv_streams.source_id),
			original_name = COALESCE(EXCLUDED.original_name, iptv_streams.original_name),
			original_group = COALESCE(EXCLUDED.original_group, iptv_streams.original_group),
			quality = COALESCE(EXCLUDED.quality, iptv_streams.quality),
			feed = COALESCE(EXCLUDED.feed, iptv_streams.feed),
			timeshift_hours = COALESCE(EXCLUDED.timeshift_hours, iptv_streams.timeshift_hours),
			is_working = COALESCE(EXCLUDED.is_working, iptv_streams.is_working),
			updated_at = NOW()
		RETURNING id`,
		s.ChannelID, s.URL, s.SourceID, s.OriginalName, s.OriginalGroup, s.Quality, s.Feed, s.TimeshiftHours, s.IsWorking,
	).Scan(&id)
	return id, err
}

func (r *IPTVRepository) UpsertUnmatchedStream(s *models.UnmatchedStream) (int, error) {
	var id int
	err := r.db.QueryRow(`
		INSERT INTO iptv_unmatched_streams (url, original_name, original_group, tvg_id, logo_url, country_hint, source_id, is_working, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
		ON CONFLICT (url) DO UPDATE SET
			original_name = COALESCE(EXCLUDED.original_name, iptv_unmatched_streams.original_name),
			original_group = COALESCE(EXCLUDED.original_group, iptv_unmatched_streams.original_group),
			tvg_id = COALESCE(EXCLUDED.tvg_id, iptv_unmatched_streams.tvg_id),
			logo_url = COALESCE(EXCLUDED.logo_url, iptv_unmatched_streams.logo_url),
			country_hint = COALESCE(EXCLUDED.country_hint, iptv_unmatched_streams.country_hint),
			is_working = COALESCE(EXCLUDED.is_working, iptv_unmatched_streams.is_working)
		RETURNING id`,
		s.URL, s.OriginalName, s.OriginalGroup, s.TvgID, s.LogoURL, s.CountryHint, s.SourceID, s.IsWorking,
	).Scan(&id)
	return id, err
}

func (r *IPTVRepository) GetStreamsByChannel(channelID string) ([]*models.Stream, error) {
	rows, err := r.db.Query(`
		SELECT id, channel_id, url, source_id, original_name, quality, is_working,
		       response_time_ms, video_codec, audio_codec, resolution, uptime_pct
		FROM iptv_streams
		WHERE channel_id = $1 AND is_working = true
		ORDER BY uptime_pct DESC, response_time_ms ASC NULLS LAST`, channelID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var streams []*models.Stream
	for rows.Next() {
		s := &models.Stream{}
		if err := rows.Scan(&s.ID, &s.ChannelID, &s.URL, &s.SourceID, &s.OriginalName,
			&s.Quality, &s.IsWorking, &s.ResponseTimeMs, &s.VideoCodec, &s.AudioCodec,
			&s.Resolution, &s.UptimePct); err != nil {
			return nil, err
		}
		streams = append(streams, s)
	}
	return streams, nil
}

func (r *IPTVRepository) GetStreamsForCheck(limit int) ([]*models.Stream, error) {
	rows, err := r.db.Query(`
		SELECT id, channel_id, url
		FROM iptv_streams
		WHERE last_checked_at IS NULL
		   OR last_checked_at < NOW() - INTERVAL '30 minutes'
		ORDER BY last_checked_at ASC NULLS FIRST
		LIMIT $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var streams []*models.Stream
	for rows.Next() {
		s := &models.Stream{}
		if err := rows.Scan(&s.ID, &s.ChannelID, &s.URL); err != nil {
			return nil, err
		}
		streams = append(streams, s)
	}
	return streams, nil
}

func (r *IPTVRepository) UpdateStreamCheckResult(streamID int, isWorking bool, responseTimeMs int, videoCodec, audioCodec, resolution *string) error {
	_, err := r.db.Exec(`
		UPDATE iptv_streams SET
			is_working = $2,
			last_checked_at = NOW(),
			response_time_ms = $3,
			video_codec = $4,
			audio_codec = $5,
			resolution = $6,
			check_count = check_count + 1,
			ok_count = CASE WHEN $2 THEN ok_count + 1 ELSE ok_count END,
			uptime_pct = CASE WHEN check_count > 0
				THEN (CASE WHEN $2 THEN ok_count + 1 ELSE ok_count END)::float / (check_count + 1) * 100
				ELSE CASE WHEN $2 THEN 100 ELSE 0 END
			END,
			updated_at = NOW()
		WHERE id = $1`,
		streamID, isWorking, responseTimeMs, videoCodec, audioCodec, resolution)
	return err
}

func (r *IPTVRepository) GetStreamCount() (total int, working int, err error) {
	err = r.db.QueryRow(`SELECT COUNT(*), COUNT(*) FILTER (WHERE is_working = true) FROM iptv_streams`).Scan(&total, &working)
	return
}

func (r *IPTVRepository) GetUnmatchedCount() (int, error) {
	var count int
	err := r.db.QueryRow(`SELECT COUNT(*) FROM iptv_unmatched_streams`).Scan(&count)
	return count, err
}
