package models

import "time"

type Channel struct {
	ID                 string     `json:"id" db:"id"`
	Name               string     `json:"name" db:"name"`
	URL                string     `json:"url" db:"url"`
	LogoURL            *string    `json:"logoUrl,omitempty" db:"logo_url"`
	GroupTitle         *string    `json:"groupTitle,omitempty" db:"group_title"`
	Country            *string    `json:"country,omitempty" db:"country"`
	Language           *string    `json:"language,omitempty" db:"language"`
	TvgID              *string    `json:"tvgId,omitempty" db:"tvg_id"`
	SourceID           *int       `json:"sourceId,omitempty" db:"source_id"`
	IsWorking          *bool      `json:"isWorking,omitempty" db:"is_working"`
	LastCheckedAt      *time.Time `json:"lastCheckedAt,omitempty" db:"last_checked_at"`
	VideoCodec         *string    `json:"videoCodec,omitempty" db:"video_codec"`
	AudioCodec         *string    `json:"audioCodec,omitempty" db:"audio_codec"`
	Resolution         *string    `json:"resolution,omitempty" db:"resolution"`
	ThumbnailURL       *string    `json:"thumbnailUrl,omitempty" db:"thumbnail_url"`
	ThumbnailUpdatedAt *time.Time `json:"thumbnailUpdatedAt,omitempty" db:"thumbnail_updated_at"`
	CreatedAt          time.Time  `json:"createdAt" db:"created_at"`
	UpdatedAt          time.Time  `json:"updatedAt" db:"updated_at"`
}

type ChannelGroup struct {
	ID           int    `json:"id" db:"id"`
	Name         string `json:"name" db:"name"`
	ChannelCount int    `json:"count" db:"channel_count"`
	Icon         string `json:"icon,omitempty" db:"icon"`
}
