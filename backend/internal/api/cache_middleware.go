package api

import (
	"context"
	"crypto/md5"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
)

const cacheKeyPrefix = "iptv:cache:"

type CacheMiddleware struct {
	client *redis.Client
	logger *logrus.Logger
}

func NewCacheMiddleware(client *redis.Client, logger *logrus.Logger) *CacheMiddleware {
	return &CacheMiddleware{client: client, logger: logger}
}

func (m *CacheMiddleware) CacheResponse() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Method != http.MethodGet {
			c.Next()
			return
		}

		ttl := m.getTTL(c.Request.URL.Path)
		if ttl == 0 {
			c.Next()
			return
		}

		key := m.generateKey(c)

		cached, err := m.client.Get(c.Request.Context(), key).Result()
		if err == nil {
			c.Header("X-Cache", "HIT")
			c.Header("Content-Type", "application/json; charset=utf-8")
			c.String(http.StatusOK, cached)
			c.Abort()
			return
		}

		w := &responseWriter{ResponseWriter: c.Writer, body: &strings.Builder{}}
		c.Writer = w
		c.Next()

		if c.Writer.Status() == http.StatusOK && w.body.Len() > 0 {
			m.client.Set(c.Request.Context(), key, w.body.String(), ttl)
		}
		c.Header("X-Cache", "MISS")
	}
}

func (m *CacheMiddleware) getTTL(path string) time.Duration {
	switch {
	case strings.Contains(path, "/api/channels/featured"):
		return 5 * time.Minute
	case strings.Contains(path, "/api/channels"):
		return 2 * time.Minute
	case strings.Contains(path, "/api/groups"):
		return 10 * time.Minute
	case strings.Contains(path, "/api/epg"):
		return 5 * time.Minute
	case strings.Contains(path, "/api/health"):
		return 30 * time.Second
	default:
		return 0
	}
}

func (m *CacheMiddleware) generateKey(c *gin.Context) string {
	raw := c.Request.URL.Path + "?" + c.Request.URL.RawQuery
	if len(raw) > 200 {
		hash := md5.Sum([]byte(raw))
		return cacheKeyPrefix + fmt.Sprintf("%x", hash)
	}
	return cacheKeyPrefix + raw
}

func (m *CacheMiddleware) InvalidateAll(ctx context.Context) error {
	iter := m.client.Scan(ctx, 0, cacheKeyPrefix+"*", 100).Iterator()
	var keys []string
	for iter.Next(ctx) {
		keys = append(keys, iter.Val())
	}
	if len(keys) > 0 {
		return m.client.Del(ctx, keys...).Err()
	}
	return nil
}

type responseWriter struct {
	gin.ResponseWriter
	body *strings.Builder
}

func (w *responseWriter) Write(data []byte) (int, error) {
	w.body.Write(data)
	return w.ResponseWriter.Write(data)
}
