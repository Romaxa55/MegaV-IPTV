package models

import "time"

type Channel struct {
	ID           int       `json:"id" db:"id"`
	Name         string    `json:"name" db:"name"`
	GroupTitle   string    `json:"groupTitle" db:"group_title"`
	StreamURL    string    `json:"streamUrl" db:"stream_url"`
	TvgRec       int       `json:"tvgRec" db:"tvg_rec"`
	LogoURL      *string   `json:"logoUrl,omitempty" db:"logo_url"`
	ThumbnailURL *string   `json:"thumbnailUrl,omitempty" db:"thumbnail_url"`
	CreatedAt    time.Time `json:"createdAt" db:"created_at"`
	UpdatedAt    time.Time `json:"updatedAt" db:"updated_at"`
}
