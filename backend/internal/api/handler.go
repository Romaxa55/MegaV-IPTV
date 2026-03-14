package api

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/sirupsen/logrus"
)

type Handler struct {
	repo   *repositories.IPTVRepository
	logger *logrus.Logger
}

func NewHandler(repo *repositories.IPTVRepository, logger *logrus.Logger) *Handler {
	return &Handler{repo: repo, logger: logger}
}

func (h *Handler) GetGroups(c *gin.Context) {
	groups, err := h.repo.GetGroups()
	if err != nil {
		h.logger.WithError(err).Error("Failed to get groups")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load groups"})
		return
	}

	result := make([]gin.H, 0, len(groups))
	for _, g := range groups {
		result = append(result, gin.H{
			"name":  g.Name,
			"count": g.ChannelCount,
		})
	}
	c.JSON(http.StatusOK, result)
}

func (h *Handler) GetChannels(c *gin.Context) {
	filters := repositories.ChannelFilters{
		Limit:  20,
		Offset: 0,
	}

	if group := c.Query("group"); group != "" {
		filters.Group = &group
	}
	if limit := c.Query("limit"); limit != "" {
		if n, err := strconv.Atoi(limit); err == nil && n > 0 {
			filters.Limit = n
		}
	}
	if offset := c.Query("offset"); offset != "" {
		if n, err := strconv.Atoi(offset); err == nil && n >= 0 {
			filters.Offset = n
		}
	}

	channels, err := h.repo.GetChannels(filters)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get channels")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load channels"})
		return
	}

	c.JSON(http.StatusOK, channels)
}

func (h *Handler) GetFeaturedChannels(c *gin.Context) {
	limit := 10
	if l := c.Query("limit"); l != "" {
		if n, err := strconv.Atoi(l); err == nil && n > 0 {
			limit = n
		}
	}

	channels, err := h.repo.GetFeaturedChannels(limit)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get featured channels")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load featured channels"})
		return
	}

	c.JSON(http.StatusOK, channels)
}

func (h *Handler) GetCurrentProgram(c *gin.Context) {
	channelID := c.Query("channelId")
	if channelID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "channelId is required"})
		return
	}

	program, err := h.repo.GetCurrentProgram(channelID)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get current program")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load current program"})
		return
	}

	if program == nil {
		c.JSON(http.StatusNotFound, nil)
		return
	}

	c.JSON(http.StatusOK, program)
}

func (h *Handler) GetUpcomingPrograms(c *gin.Context) {
	channelID := c.Query("channelId")
	if channelID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "channelId is required"})
		return
	}

	limit := 10
	if l := c.Query("limit"); l != "" {
		if n, err := strconv.Atoi(l); err == nil && n > 0 {
			limit = n
		}
	}

	programs, err := h.repo.GetUpcomingPrograms(channelID, limit)
	if err != nil {
		h.logger.WithError(err).Error("Failed to get upcoming programs")
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load upcoming programs"})
		return
	}

	c.JSON(http.StatusOK, programs)
}

func (h *Handler) GetChannelThumbnail(c *gin.Context) {
	channelID := c.Param("id")
	ch, err := h.repo.GetChannelByID(channelID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load channel"})
		return
	}
	if ch == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Channel not found"})
		return
	}
	if ch.ThumbnailURL == nil || *ch.ThumbnailURL == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "No thumbnail available"})
		return
	}
	c.Redirect(http.StatusTemporaryRedirect, *ch.ThumbnailURL)
}

func (h *Handler) HealthCheck(c *gin.Context) {
	total, _ := h.repo.GetTotalChannelCount()
	working, _ := h.repo.GetWorkingChannelCount()

	c.JSON(http.StatusOK, gin.H{
		"status":           "ok",
		"service":          "iptv-api",
		"total_channels":   total,
		"working_channels": working,
	})
}
