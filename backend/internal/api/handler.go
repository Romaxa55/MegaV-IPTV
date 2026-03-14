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

const thumbnailStaleDuration = 5 * time.Minute
const thumbnailGeneratingTTL = 60 * time.Second

type Handler struct {
	repo          *repositories.IPTVRepository
	logger        *logrus.Logger
	thumbService  *services.ThumbnailService
	posterService *services.PosterService
	redisClient   *redis.Client
	thumbQueue    *queue.RedisQueue
}

type HandlerOpts struct {
	Repo          *repositories.IPTVRepository
	Logger        *logrus.Logger
	ThumbService  *services.ThumbnailService
	PosterService *services.PosterService
	RedisClient   *redis.Client
	ThumbQueue    *queue.RedisQueue
}

func NewHandler(opts HandlerOpts) *Handler {
	return &Handler{
		repo:          opts.Repo,
		logger:        opts.Logger,
		thumbService:  opts.ThumbService,
		posterService: opts.PosterService,
		redisClient:   opts.RedisClient,
		thumbQueue:    opts.ThumbQueue,
	}
}

func (h *Handler) GetChannels(c *gin.Context) {
	filters := repositories.ChannelFilters{
		Limit:  50,
		Offset: 0,
	}

	if v := c.Query("category"); v != "" {
		filters.Group = &v
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

	channels, total, err := h.repo.GetChannels(filters)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get channels")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load channels"})
		return
	}

	h.enrichThumbnails(c, channels)

	c.JSON(http.StatusOK, gin.H{
		"channels": channels,
		"total":    total,
		"limit":    filters.Limit,
		"offset":   filters.Offset,
	})
}

func (h *Handler) GetChannel(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid channel ID"})
		return
	}

	ch, err := h.repo.GetChannelByID(id)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get channel")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load channel"})
		return
	}
	if ch == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Channel not found"})
		return
	}

	c.JSON(http.StatusOK, ch)
}

func (h *Handler) GetChannelStreams(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid channel ID"})
		return
	}

	url, err := h.repo.GetStreamURL(id)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get stream")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load stream"})
		return
	}

	c.JSON(http.StatusOK, []gin.H{{"url": url}})
}

func (h *Handler) GetChannelEPG(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid channel ID"})
		return
	}

	limit := 20
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}

	programs, err := h.repo.GetProgramsForChannel(id, limit)
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

	h.enrichNowPlayingThumbnails(c, items)

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

	h.enrichNowPlayingThumbnails(c, items)

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

	h.enrichNowPlayingThumbnails(c, items)

	c.JSON(http.StatusOK, items)
}

func (h *Handler) GetMoviesNowPlaying(c *gin.Context) {
	limit := 20
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 50 {
			limit = n
		}
	}

	items, err := h.repo.GetMoviesNowPlaying(limit)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get movies now playing")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load movies"})
		return
	}

	if h.posterService != nil {
		h.posterService.EnrichMoviePosters(items)
	}

	h.enrichNowPlayingThumbnails(c, items)

	c.JSON(http.StatusOK, items)
}

func (h *Handler) GetFeaturedChannels(c *gin.Context) {
	limit := 10
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}

	channels, err := h.repo.GetFeaturedChannels(limit)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get featured channels")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load featured channels"})
		return
	}

	h.enrichThumbnails(c, channels)

	c.JSON(http.StatusOK, channels)
}

func (h *Handler) GetCategories(c *gin.Context) {
	categories, err := h.repo.GetCategories()
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
	info, err := os.Stat(thumbPath)
	if err == nil && info.Size() > 0 {
		age := time.Since(info.ModTime())
		if age > thumbnailStaleDuration {
			h.enqueueThumbnail(id)
		}
		c.Header("Cache-Control", "public, max-age=60")
		c.Header("X-Thumbnail-Age", age.Round(time.Second).String())
		c.File(thumbPath)
		return
	}

	h.enqueueThumbnail(id)
	c.JSON(http.StatusNotFound, gin.H{"error": "thumbnail not available yet"})
}

func (h *Handler) enqueueThumbnail(channelID string) {
	if h.redisClient == nil || h.thumbQueue == nil {
		return
	}

	ctx := context.Background()
	genKey := "iptv:thumb:generating:" + channelID
	set, err := h.redisClient.SetNX(ctx, genKey, "1", thumbnailGeneratingTTL).Result()
	if err != nil || !set {
		return
	}

	chID, err := strconv.Atoi(channelID)
	if err != nil {
		h.redisClient.Del(ctx, genKey)
		return
	}

	streamURL, err := h.repo.GetStreamURL(chID)
	if err != nil || streamURL == "" {
		h.redisClient.Del(ctx, genKey)
		return
	}

	item := &queue.ThumbnailItem{
		ChannelID: channelID,
		URL:       streamURL,
		Timestamp: time.Now(),
	}
	if err := h.thumbQueue.EnqueueThumbnail(ctx, item); err != nil {
		h.logger.WithError(err).Warnf("Failed to enqueue thumbnail for %s", channelID)
		h.redisClient.Del(ctx, genKey)
	}
}

func (h *Handler) GetM3UPlaylist(c *gin.Context) {
	channels, _, err := h.repo.GetChannels(repositories.ChannelFilters{
		Limit:  5000,
		Offset: 0,
	})
	if err != nil {
		h.logger.WithError(err).Error("Failed to get channels for M3U")
		c.String(http.StatusInternalServerError, "Failed to generate playlist")
		return
	}

	var sb strings.Builder
	sb.WriteString("#EXTM3U\n")

	for _, ch := range channels {
		sb.WriteString(fmt.Sprintf("#EXTINF:-1 tvg-rec=\"%d\" group-title=\"%s\",%s\n",
			ch.TvgRec, ch.GroupTitle, ch.Name))
		sb.WriteString(ch.StreamURL + "\n")
	}

	c.Header("Content-Type", "audio/x-mpegurl; charset=utf-8")
	c.Header("Content-Disposition", "attachment; filename=\"megav-iptv.m3u\"")
	c.String(http.StatusOK, sb.String())
}

func (h *Handler) SyncPlaylist(c *gin.Context) {
	playlistURL, _, err := h.repo.GetConfig()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get config"})
		return
	}

	syncService := services.NewSyncService(h.repo, h.logger)
	if err := syncService.SyncPlaylist(playlistURL); err != nil {
		h.logger.WithError(err).Error("Playlist sync failed")
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok", "message": "Playlist synced"})
}

func (h *Handler) SyncEPG(c *gin.Context) {
	_, epgURL, err := h.repo.GetConfig()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get config"})
		return
	}

	syncService := services.NewSyncService(h.repo, h.logger)
	if err := syncService.SyncEPG(epgURL); err != nil {
		h.logger.WithError(err).Error("EPG sync failed")
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok", "message": "EPG synced"})
}

func (h *Handler) SyncAll(c *gin.Context) {
	playlistURL, epgURL, err := h.repo.GetConfig()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get config"})
		return
	}

	syncService := services.NewSyncService(h.repo, h.logger)

	if err := syncService.SyncPlaylist(playlistURL); err != nil {
		h.logger.WithError(err).Error("Playlist sync failed")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Playlist sync: " + err.Error()})
		return
	}

	if err := syncService.SyncEPG(epgURL); err != nil {
		h.logger.WithError(err).Error("EPG sync failed")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "EPG sync: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok", "message": "Playlist and EPG synced"})
}

func (h *Handler) buildThumbnailURL(c *gin.Context, channelID int) string {
	scheme := "https"
	if c.Request.TLS == nil {
		if fwd := c.GetHeader("X-Forwarded-Proto"); fwd != "" {
			scheme = fwd
		}
	}
	return fmt.Sprintf("%s://%s/api/channels/%d/thumbnail.jpg", scheme, c.Request.Host, channelID)
}

func (h *Handler) enrichThumbnails(c *gin.Context, channels []*repositories.ChannelWithEPG) {
	if h.thumbService == nil {
		return
	}
	for _, ch := range channels {
		idStr := strconv.Itoa(ch.ID)
		if h.thumbService.ThumbnailExists(idStr) {
			url := h.buildThumbnailURL(c, ch.ID)
			ch.ThumbnailURL = &url
		}
		h.enqueueThumbnailIfStale(idStr)
	}
}

func (h *Handler) enrichNowPlayingThumbnails(c *gin.Context, items []*repositories.NowPlayingItem) {
	if h.thumbService == nil {
		return
	}
	for _, item := range items {
		idStr := strconv.Itoa(item.ChannelID)
		if h.thumbService.ThumbnailExists(idStr) {
			url := h.buildThumbnailURL(c, item.ChannelID)
			item.ThumbnailURL = &url
		}
		h.enqueueThumbnailIfStale(idStr)
	}
}

func (h *Handler) enqueueThumbnailIfStale(channelID string) {
	if h.thumbService == nil {
		return
	}
	thumbPath := h.thumbService.GetThumbnailPath(channelID)
	info, err := os.Stat(thumbPath)
	if err != nil || info.Size() == 0 || time.Since(info.ModTime()) > thumbnailStaleDuration {
		h.enqueueThumbnail(channelID)
	}
}
