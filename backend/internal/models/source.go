package models

import "time"

type Source struct {
	ID           int        `json:"id" db:"id"`
	URL          string     `json:"url" db:"url"`
	Name         *string    `json:"name,omitempty" db:"name"`
	SourceType   string     `json:"sourceType" db:"source_type"`
	LastParsedAt *time.Time `json:"lastParsedAt,omitempty" db:"last_parsed_at"`
	Status       string     `json:"status" db:"status"`
	ChannelCount int        `json:"channelCount" db:"channel_count"`
	CreatedAt    time.Time  `json:"createdAt" db:"created_at"`

	GitHubRepo   *string    `json:"githubRepo,omitempty" db:"github_repo"`
	GitHubStars  int        `json:"githubStars" db:"github_stars"`
	LastCommitAt *time.Time `json:"lastCommitAt,omitempty" db:"last_commit_at"`
	DiscoveredAt *time.Time `json:"discoveredAt,omitempty" db:"discovered_at"`
	FilePath     *string    `json:"filePath,omitempty" db:"file_path"`
	RawURL       *string    `json:"rawUrl,omitempty" db:"raw_url"`
}
