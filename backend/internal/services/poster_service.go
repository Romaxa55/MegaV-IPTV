package services

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/sirupsen/logrus"
)

const (
	posterCacheTTL  = 24 * time.Hour
	posterCacheNone = "__none__"
)

type PosterService struct {
	apiKey string
	redis  *redis.Client
	repo   *repositories.IPTVRepository
	logger *logrus.Logger
	client *http.Client
}

func NewPosterService(apiKey string, redisClient *redis.Client, repo *repositories.IPTVRepository, logger *logrus.Logger) *PosterService {
	return &PosterService{
		apiKey: apiKey,
		redis:  redisClient,
		repo:   repo,
		logger: logger,
		client: &http.Client{Timeout: 10 * time.Second},
	}
}

func (s *PosterService) Enabled() bool {
	return s.apiKey != "" && s.redis != nil
}

type kpSearchResponse struct {
	Films []kpFilm `json:"films"`
}

type kpFilm struct {
	FilmID           int    `json:"filmId"`
	NameRu           string `json:"nameRu"`
	NameEn           string `json:"nameEn"`
	Year             string `json:"year"`
	Rating           string `json:"rating"`
	PosterURL        string `json:"posterUrl"`
	PosterURLPreview string `json:"posterUrlPreview"`
}

func (s *PosterService) EnrichMoviePosters(items []*repositories.NowPlayingItem) {
	if !s.Enabled() {
		return
	}

	for _, item := range items {
		if item.Program == nil {
			continue
		}
		if item.Program.Icon != nil && *item.Program.Icon != "" {
			continue
		}

		title := cleanTitle(item.Program.Title)
		if title == "" {
			continue
		}

		posterURL := s.lookupPoster(title)
		if posterURL != "" {
			item.Program.Icon = &posterURL
			s.repo.UpdateEpgProgramIcon(item.Program.ID, posterURL)
		}
	}
}

func (s *PosterService) lookupPoster(title string) string {
	ctx := context.Background()
	cacheKey := fmt.Sprintf("iptv:poster:%x", sha256.Sum256([]byte(title)))

	cached, err := s.redis.Get(ctx, cacheKey).Result()
	if err == nil {
		if cached == posterCacheNone {
			return ""
		}
		return cached
	}

	posterURL := s.searchKinopoisk(title)

	if posterURL != "" {
		s.redis.Set(ctx, cacheKey, posterURL, posterCacheTTL)
	} else {
		s.redis.Set(ctx, cacheKey, posterCacheNone, posterCacheTTL)
	}

	return posterURL
}

func (s *PosterService) searchKinopoisk(title string) string {
	reqURL := fmt.Sprintf("https://kinopoiskapiunofficial.tech/api/v2.1/films/search-by-keyword?keyword=%s",
		url.QueryEscape(title))

	req, err := http.NewRequest("GET", reqURL, nil)
	if err != nil {
		return ""
	}
	req.Header.Set("X-API-KEY", s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		s.logger.WithError(err).Debugf("Kinopoisk API request failed for: %s", title)
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		s.logger.Debugf("Kinopoisk API returned %d for: %s", resp.StatusCode, title)
		return ""
	}

	var result kpSearchResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return ""
	}

	if len(result.Films) == 0 {
		return ""
	}

	film := result.Films[0]
	if film.PosterURL != "" {
		return film.PosterURL
	}
	return film.PosterURLPreview
}

func cleanTitle(title string) string {
	title = strings.TrimSpace(title)
	for _, sep := range []string{" (", ". Серия", ". серия", " / ", ". Сезон"} {
		if idx := strings.Index(title, sep); idx > 0 {
			title = title[:idx]
		}
	}
	return strings.TrimSpace(title)
}
