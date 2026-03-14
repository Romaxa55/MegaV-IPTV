package services

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/sirupsen/logrus"
)

type PosterService struct {
	apiKey    string
	repo      *repositories.IPTVRepository
	logger    *logrus.Logger
	client    *http.Client
	outputDir string
}

func NewPosterService(apiKey string, repo *repositories.IPTVRepository, logger *logrus.Logger, outputDir string) *PosterService {
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		logger.Warnf("Failed to create poster dir %s: %v", outputDir, err)
	}
	return &PosterService{
		apiKey:    apiKey,
		repo:      repo,
		logger:    logger,
		client:    &http.Client{Timeout: 15 * time.Second},
		outputDir: outputDir,
	}
}

func (s *PosterService) Enabled() bool {
	return s.apiKey != ""
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

func titleHash(title string) string {
	return fmt.Sprintf("%x", sha256.Sum256([]byte(title)))[:16]
}

// EnrichMoviePosters sets program.Icon to our local poster endpoint URL.
// Looks up DB cache first, only hits Kinopoisk API on cache miss.
func (s *PosterService) EnrichMoviePosters(items []*repositories.NowPlayingItem, baseURL string) {
	for _, item := range items {
		if item.Program == nil {
			continue
		}

		title := cleanTitle(item.Program.Title)
		if title == "" {
			continue
		}

		hash := titleHash(title)

		cached, err := s.repo.GetPosterCache(hash)
		if err != nil {
			s.logger.WithError(err).Debug("poster cache lookup failed")
		}

		if cached != nil {
			if cached.FilePath != "" {
				localURL := fmt.Sprintf("%s/api/posters/%s.jpg", baseURL, hash)
				item.Program.Icon = &localURL
			}
			continue
		}

		if !s.Enabled() {
			continue
		}

		posterURL := s.searchKinopoisk(title)
		if posterURL == "" {
			s.repo.UpsertPosterCache(hash, title, "", "")
			continue
		}

		filePath := s.downloadPoster(hash, posterURL)
		s.repo.UpsertPosterCache(hash, title, posterURL, filePath)

		if filePath != "" {
			localURL := fmt.Sprintf("%s/api/posters/%s.jpg", baseURL, hash)
			item.Program.Icon = &localURL
		}
	}
}

// GetPosterPath returns the file path for a poster by hash, or empty if not found.
func (s *PosterService) GetPosterPath(hash string) string {
	path := filepath.Join(s.outputDir, hash+".jpg")
	info, err := os.Stat(path)
	if err == nil && info.Size() > 0 {
		return path
	}
	return ""
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

	if resp.StatusCode == 429 {
		s.logger.Warn("Kinopoisk API rate limit reached")
		return ""
	}
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

func (s *PosterService) downloadPoster(hash, posterURL string) string {
	resp, err := s.client.Get(posterURL)
	if err != nil {
		s.logger.WithError(err).Debugf("Failed to download poster: %s", posterURL)
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return ""
	}

	path := filepath.Join(s.outputDir, hash+".jpg")
	f, err := os.Create(path)
	if err != nil {
		s.logger.WithError(err).Warnf("Failed to create poster file: %s", path)
		return ""
	}
	defer f.Close()

	written, err := io.Copy(f, resp.Body)
	if err != nil || written == 0 {
		os.Remove(path)
		return ""
	}

	s.logger.Debugf("Downloaded poster %s (%d bytes)", hash, written)
	return path
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
