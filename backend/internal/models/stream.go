package models

import "time"

type Stream struct {
	ID             int        `json:"id" db:"id"`
	ChannelID      *string    `json:"channelId,omitempty" db:"channel_id"`
	URL            string     `json:"url" db:"url"`
	SourceID       *int       `json:"sourceId,omitempty" db:"source_id"`
	OriginalName   *string    `json:"originalName,omitempty" db:"original_name"`
	OriginalGroup  *string    `json:"originalGroup,omitempty" db:"original_group"`
	Quality        *string    `json:"quality,omitempty" db:"quality"`
	Feed           *string    `json:"feed,omitempty" db:"feed"`
	TimeshiftHours int        `json:"timeshiftHours" db:"timeshift_hours"`
	IsWorking      *bool      `json:"isWorking,omitempty" db:"is_working"`
	LastCheckedAt  *time.Time `json:"lastCheckedAt,omitempty" db:"last_checked_at"`
	ResponseTimeMs *int       `json:"responseTimeMs,omitempty" db:"response_time_ms"`
	VideoCodec     *string    `json:"videoCodec,omitempty" db:"video_codec"`
	AudioCodec     *string    `json:"audioCodec,omitempty" db:"audio_codec"`
	Resolution     *string    `json:"resolution,omitempty" db:"resolution"`
	UptimePct      float64    `json:"uptimePct" db:"uptime_pct"`
	CheckCount     int        `json:"checkCount" db:"check_count"`
	OkCount        int        `json:"okCount" db:"ok_count"`
	CreatedAt      time.Time  `json:"createdAt" db:"created_at"`
	UpdatedAt      time.Time  `json:"updatedAt" db:"updated_at"`
}

type UnmatchedStream struct {
	ID             int        `json:"id" db:"id"`
	URL            string     `json:"url" db:"url"`
	OriginalName   *string    `json:"originalName,omitempty" db:"original_name"`
	OriginalGroup  *string    `json:"originalGroup,omitempty" db:"original_group"`
	TvgID          *string    `json:"tvgId,omitempty" db:"tvg_id"`
	LogoURL        *string    `json:"logoUrl,omitempty" db:"logo_url"`
	CountryHint    *string    `json:"countryHint,omitempty" db:"country_hint"`
	SourceID       *int       `json:"sourceId,omitempty" db:"source_id"`
	IsWorking      *bool      `json:"isWorking,omitempty" db:"is_working"`
	LastCheckedAt  *time.Time `json:"lastCheckedAt,omitempty" db:"last_checked_at"`
	MatchAttempted bool       `json:"matchAttempted" db:"match_attempted"`
	CreatedAt      time.Time  `json:"createdAt" db:"created_at"`
}
