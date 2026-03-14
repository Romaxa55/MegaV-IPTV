package models

import (
	"time"

	"github.com/lib/pq"
)

type ReferenceChannel struct {
	ID         string         `json:"id" db:"id"`
	Name       string         `json:"name" db:"name"`
	AltNames   pq.StringArray `json:"altNames" db:"alt_names"`
	Network    *string        `json:"network,omitempty" db:"network"`
	Owners     *string        `json:"owners,omitempty" db:"owners"`
	Country    string         `json:"country" db:"country"`
	Categories pq.StringArray `json:"categories" db:"categories"`
	IsNSFW     bool           `json:"isNsfw" db:"is_nsfw"`
	Launched   *string        `json:"launched,omitempty" db:"launched"`
	Closed     *string        `json:"closed,omitempty" db:"closed"`
	ReplacedBy *string        `json:"replacedBy,omitempty" db:"replaced_by"`
	Website    *string        `json:"website,omitempty" db:"website"`
	LogoURL    *string        `json:"logoUrl,omitempty" db:"logo_url"`
	UpdatedAt  time.Time      `json:"updatedAt" db:"updated_at"`
}
