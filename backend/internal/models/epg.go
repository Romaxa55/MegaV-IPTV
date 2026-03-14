package models

import "time"

type EpgProgram struct {
	ID          int       `json:"id" db:"id"`
	ChannelID   int       `json:"channelId" db:"channel_id"`
	Title       string    `json:"title" db:"title"`
	Description *string   `json:"description,omitempty" db:"description"`
	Category    *string   `json:"category,omitempty" db:"category"`
	Icon        *string   `json:"icon,omitempty" db:"icon"`
	StartTime   time.Time `json:"start" db:"start_time"`
	EndTime     time.Time `json:"end" db:"end_time"`
	Lang        *string   `json:"lang,omitempty" db:"lang"`
}
