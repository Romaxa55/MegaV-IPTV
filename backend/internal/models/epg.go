package models

import "time"

type EpgProgram struct {
	ID                 int       `json:"id" db:"id"`
	ChannelID          string    `json:"channelId" db:"channel_id"`
	ReferenceChannelID *string   `json:"referenceChannelId,omitempty" db:"reference_channel_id"`
	Title              string    `json:"title" db:"title"`
	Description        *string   `json:"description,omitempty" db:"description"`
	Category           *string   `json:"category,omitempty" db:"category"`
	Icon               *string   `json:"icon,omitempty" db:"icon"`
	StartTime          time.Time `json:"start" db:"start_time"`
	EndTime            time.Time `json:"end" db:"end_time"`
	Lang               *string   `json:"lang,omitempty" db:"lang"`
}

type EpgChannelMap struct {
	ID           int     `json:"id" db:"id"`
	ChannelID    string  `json:"channelId" db:"channel_id"`
	EpgChannelID string  `json:"epgChannelId" db:"epg_channel_id"`
	Confidence   float64 `json:"confidence" db:"confidence"`
}
