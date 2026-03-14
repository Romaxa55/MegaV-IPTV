package api

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/romaxa55/iptv-parser/internal/queue"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/romaxa55/iptv-parser/internal/services"
	"github.com/sirupsen/logrus"
)

const thumbnailStaleDuration = 6 * time.Hour
const thumbnailGeneratingTTL = 5 * time.Minute

type Handler struct {
	repo         *repositories.IPTVRepository
	logger       *logrus.Logger
	thumbService *services.ThumbnailService
	redisClient  *redis.Client
	thumbQueue   *queue.RedisQueue
}

type HandlerOpts struct {
	Repo         *repositories.IPTVRepository
	Logger       *logrus.Logger
	ThumbService *services.ThumbnailService
	RedisClient  *redis.Client
	ThumbQueue   *queue.RedisQueue
}

func NewHandler(opts HandlerOpts) *Handler {
	return &Handler{
		repo:         opts.Repo,
		logger:       opts.Logger,
		thumbService: opts.ThumbService,
		redisClient:  opts.RedisClient,
		thumbQueue:   opts.ThumbQueue,
	}
}

func (h *Handler) GetChannels(c *gin.Context) {
	filters := repositories.ReferenceChannelFilters{
		Limit:  50,
		Offset: 0,
	}

	if v := c.Query("country"); v != "" {
		filters.Country = &v
	}
	if v := c.Query("category"); v != "" {
		filters.Category = &v
	}
	if v := c.Query("search"); v != "" {
		filters.Search = &v
	}
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 200 {
			filters.Limit = n
		}
	}
	if v := c.Query("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			filters.Offset = n
		}
	}

	channels, total, err := h.repo.GetReferenceChannels(filters)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get channels")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load channels"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"channels": channels,
		"total":    total,
		"limit":    filters.Limit,
		"offset":   filters.Offset,
	})
}

func (h *Handler) GetChannel(c *gin.Context) {
	id := c.Param("id")

	ch, err := h.repo.GetReferenceChannelByID(id)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get channel")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load channel"})
		return
	}
	if ch == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Channel not found"})
		return
	}

	if h.thumbService != nil && !h.thumbService.ThumbnailExists(id) {
		h.enqueueThumbnail(id)
	}

	streams, err := h.repo.GetStreamsByChannelFull(id)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get streams")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load streams"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"channel": ch,
		"streams": streams,
	})
}

func (h *Handler) GetChannelStreams(c *gin.Context) {
	id := c.Param("id")

	streams, err := h.repo.GetStreamsByChannelFull(id)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get streams")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load streams"})
		return
	}

	c.JSON(http.StatusOK, streams)
}

func (h *Handler) GetChannelEPG(c *gin.Context) {
	id := c.Param("id")

	limit := 20
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}

	timeshiftHours := 0
	if v := c.Query("timeshift"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			timeshiftHours = n
		}
	}

	programs, err := h.repo.GetProgramsForStream(id, timeshiftHours, limit)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get EPG")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load EPG"})
		return
	}

	c.JSON(http.StatusOK, programs)
}

func (h *Handler) GetNowPlaying(c *gin.Context) {
	items, err := h.repo.GetNowPlaying()
	if err != nil {
		h.logger.WithError(err).Error("Failed to get now playing")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load now playing"})
		return
	}

	c.JSON(http.StatusOK, items)
}

func (h *Handler) GetUpcomingAll(c *gin.Context) {
	withinMinutes := 180
	if v := c.Query("within"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			withinMinutes = n
		}
	}
	limit := 50
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 200 {
			limit = n
		}
	}

	items, err := h.repo.GetUpcomingAll(withinMinutes, limit)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get upcoming")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load upcoming"})
		return
	}

	c.JSON(http.StatusOK, items)
}

func (h *Handler) GetFeaturedNowPlaying(c *gin.Context) {
	limit := 10
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}

	items, err := h.repo.GetFeaturedNowPlaying(limit)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get featured now playing")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load featured"})
		return
	}

	c.JSON(http.StatusOK, items)
}

func (h *Handler) GetFeaturedChannels(c *gin.Context) {
	limit := 10
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}

	channels, err := h.repo.GetFeaturedReferenceChannels(limit)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get featured channels")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load featured channels"})
		return
	}

	c.JSON(http.StatusOK, channels)
}

func (h *Handler) GetCountries(c *gin.Context) {
	countries, err := h.repo.GetCountries()
	if err != nil {
		h.logger.WithError(err).Error("Failed to get countries")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load countries"})
		return
	}

	c.JSON(http.StatusOK, countries)
}

func (h *Handler) GetCategories(c *gin.Context) {
	categories, err := h.repo.GetCategoriesWithCounts()
	if err != nil {
		h.logger.WithError(err).Error("Failed to get categories")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load categories"})
		return
	}

	c.JSON(http.StatusOK, categories)
}

func (h *Handler) HealthCheck(c *gin.Context) {
	stats, err := h.repo.GetStats()
	if err != nil {
		h.logger.WithError(err).Error("Failed to get stats")
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "iptv-api",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "ok",
		"service": "iptv-api",
		"stats":   stats,
	})
}

func (h *Handler) GetChannelThumbnail(c *gin.Context) {
	id := c.Param("id")

	if h.thumbService == nil {
		c.Status(http.StatusNotFound)
		return
	}

	thumbPath := h.thumbService.GetThumbnailPath(id)
	data, err := os.ReadFile(thumbPath)
	if err != nil || len(data) == 0 {
		c.Status(http.StatusNotFound)
		return
	}

	info, _ := os.Stat(thumbPath)
	age := time.Since(info.ModTime())
	if age > thumbnailStaleDuration {
		h.enqueueThumbnail(id)
	}

	c.Header("Cache-Control", "public, max-age=300")
	c.Header("X-Thumbnail-Age", age.Round(time.Second).String())
	c.Data(http.StatusOK, "image/jpeg", data)
}

func (h *Handler) GetM3UPlaylist(c *gin.Context) {
	channels, _, err := h.repo.GetReferenceChannels(repositories.ReferenceChannelFilters{
		Limit:  5000,
		Offset: 0,
	})
	if err != nil {
		h.logger.WithError(err).Error("Failed to get channels for M3U")
		c.String(http.StatusInternalServerError, "Failed to generate playlist")
		return
	}

	baseURL := c.Request.Host
	scheme := "https"
	if c.Request.TLS == nil {
		if fwd := c.GetHeader("X-Forwarded-Proto"); fwd != "" {
			scheme = fwd
		}
	}
	epgURL := fmt.Sprintf("%s://%s/api/epg.xml", scheme, baseURL)

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("#EXTM3U url-tvg=\"%s\" x-tvg-url=\"%s\"\n", epgURL, epgURL))

	for _, ch := range channels {
		if ch.WorkingCount == 0 {
			continue
		}
		streamURL, err := h.repo.GetBestStreamURL(ch.ID)
		if err != nil || streamURL == "" {
			continue
		}

		logo := ""
		if ch.LogoURL != nil {
			logo = *ch.LogoURL
		}

		group := ""
		if len(ch.Categories) > 0 {
			group = string(ch.Categories[0])
		}

		sb.WriteString(fmt.Sprintf("#EXTINF:-1 tvg-id=\"%s\" tvg-name=\"%s\" tvg-logo=\"%s\" group-title=\"%s\",%s\n",
			ch.ID, ch.Name, logo, group, ch.Name))
		sb.WriteString(streamURL + "\n")
	}

	c.Header("Content-Type", "audio/x-mpegurl; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename=\"megav-iptv.m3u\"")
	c.String(http.StatusOK, sb.String())
}

func (h *Handler) enqueueThumbnail(channelID string) bool {
	if h.redisClient == nil || h.thumbQueue == nil {
		return false
	}

	ctx := context.Background()
	genKey := "iptv:thumb:generating:" + channelID

	set, err := h.redisClient.SetNX(ctx, genKey, "1", thumbnailGeneratingTTL).Result()
	if err != nil || !set {
		return false
	}

	streamURL, err := h.repo.GetBestStreamURL(channelID)
	if err != nil || streamURL == "" {
		h.redisClient.Del(ctx, genKey)
		return false
	}

	item := &queue.ThumbnailItem{
		ChannelID: channelID,
		URL:       streamURL,
		Timestamp: time.Now(),
	}
	if err := h.thumbQueue.EnqueueThumbnail(ctx, item); err != nil {
		h.logger.WithError(err).Warnf("Failed to enqueue thumbnail for %s", channelID)
		h.redisClient.Del(ctx, genKey)
		return false
	}
	return true
}
