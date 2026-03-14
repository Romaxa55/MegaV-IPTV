package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/romaxa55/iptv-parser/internal/api"
	"github.com/romaxa55/iptv-parser/internal/config"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/sirupsen/logrus"
)

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		logrus.WithError(err).Fatal("Failed to load config")
	}

	var (
		port        = flag.String("port", "8080", "API server port")
		debug       = flag.Bool("debug", cfg.Debug, "Enable debug logging")
		enableCache = flag.Bool("cache", true, "Enable Redis caching")
	)
	flag.Parse()

	logger := logrus.New()
	if *debug {
		logger.SetLevel(logrus.DebugLevel)
		gin.SetMode(gin.DebugMode)
	} else {
		logger.SetLevel(logrus.InfoLevel)
		gin.SetMode(gin.ReleaseMode)
	}

	logger.Info("IPTV API Server starting")

	repo, err := repositories.NewIPTVRepository(cfg.DatabaseURL, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to connect to database")
	}
	defer repo.Close()

	var cacheMiddleware *api.CacheMiddleware

	if *enableCache {
		redisHost := os.Getenv("REDIS_HOST")
		redisPort := os.Getenv("REDIS_PORT")
		redisDB := os.Getenv("REDIS_DB")
		redisPassword := os.Getenv("REDIS_PASSWORD")

		if redisHost == "" {
			redisHost = "localhost"
		}
		if redisPort == "" {
			redisPort = "6379"
		}

		db := 0
		if redisDB != "" {
			if n, err := strconv.Atoi(redisDB); err == nil {
				db = n
			}
		}

		redisClient := redis.NewClient(&redis.Options{
			Addr:     fmt.Sprintf("%s:%s", redisHost, redisPort),
			Password: redisPassword,
			DB:       db,
		})

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := redisClient.Ping(ctx).Err(); err != nil {
			logger.WithError(err).Warn("Redis connection failed, running without cache")
			*enableCache = false
		} else {
			logger.Info("Connected to Redis cache")
			cacheMiddleware = api.NewCacheMiddleware(redisClient, logger)
		}
	}

	handler := api.NewHandler(repo, logger)

	router := gin.New()
	router.Use(gin.Logger())
	router.Use(gin.Recovery())

	corsConfig := cors.DefaultConfig()
	corsConfig.AllowAllOrigins = true
	corsConfig.AllowMethods = []string{"GET", "OPTIONS"}
	corsConfig.AllowHeaders = []string{"Origin", "Content-Type", "Accept"}
	corsConfig.ExposeHeaders = []string{"X-Cache"}
	router.Use(cors.New(corsConfig))

	if *enableCache && cacheMiddleware != nil {
		router.Use(cacheMiddleware.CacheResponse())
	}

	// Flutter-compatible API routes (matches ApiClient in megav_iptv)
	apiGroup := router.Group("/api")
	{
		apiGroup.GET("/groups", handler.GetGroups)
		apiGroup.GET("/channels", handler.GetChannels)
		apiGroup.GET("/channels/featured", handler.GetFeaturedChannels)
		apiGroup.GET("/channels/:id/thumbnail", handler.GetChannelThumbnail)
		apiGroup.GET("/epg/current", handler.GetCurrentProgram)
		apiGroup.GET("/epg/upcoming", handler.GetUpcomingPrograms)
		apiGroup.GET("/health", handler.HealthCheck)
	}

	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"service": "IPTV API Server",
			"version": "1.0.0",
			"endpoints": gin.H{
				"groups":   "/api/groups",
				"channels": "/api/channels",
				"featured": "/api/channels/featured",
				"epg":      "/api/epg/current",
				"health":   "/api/health",
			},
		})
	})

	srv := &http.Server{
		Addr:    ":" + *port,
		Handler: router,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.WithError(err).Fatal("Failed to start server")
		}
	}()

	logger.Infof("API Server started on port %s", *port)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.WithError(err).Fatal("Server forced to shutdown")
	}
	logger.Info("Server exited")
}
