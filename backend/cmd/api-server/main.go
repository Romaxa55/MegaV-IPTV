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
	"github.com/romaxa55/iptv-parser/internal/queue"
	"github.com/romaxa55/iptv-parser/internal/repositories"
	"github.com/romaxa55/iptv-parser/internal/services"
	"github.com/sirupsen/logrus"
)

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		logrus.WithError(err).Fatal("Failed to load config")
	}

	var (
		port         = flag.String("port", "8080", "API server port")
		debug        = flag.Bool("debug", cfg.Debug, "Enable debug logging")
		enableCache  = flag.Bool("cache", true, "Enable Redis caching")
		thumbnailDir = flag.String("thumbnail-dir", "/app/thumbnails", "Thumbnail storage directory")
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
	var redisClient *redis.Client
	var thumbQueue *queue.RedisQueue

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

	redisClient = redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", redisHost, redisPort),
		Password: redisPassword,
		DB:       db,
	})

	{
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := redisClient.Ping(ctx).Err(); err != nil {
			logger.WithError(err).Warn("Redis connection failed, running without cache/thumbnails")
			redisClient = nil
		} else {
			logger.Info("Connected to Redis")
			if *enableCache {
				cacheMiddleware = api.NewCacheMiddleware(redisClient, logger)
			}
			tq, err := queue.NewRedisQueue(cfg.RedisURL, logger)
			if err != nil {
				logger.WithError(err).Warn("Failed to create Redis queue for thumbnails")
			} else {
				thumbQueue = tq
			}
		}
	}

	thumbService := services.NewThumbnailService(logger, cfg.FFmpegBin, *thumbnailDir, 15*time.Second)

	handler := api.NewHandler(api.HandlerOpts{
		Repo:         repo,
		Logger:       logger,
		ThumbService: thumbService,
		RedisClient:  redisClient,
		ThumbQueue:   thumbQueue,
	})

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

	apiGroup := router.Group("/api")
	{
		apiGroup.GET("/channels", handler.GetChannels)
		apiGroup.GET("/channels/featured", handler.GetFeaturedChannels)
		apiGroup.GET("/channels/:id", handler.GetChannel)
		apiGroup.GET("/channels/:id/streams", handler.GetChannelStreams)
		apiGroup.GET("/channels/:id/epg", handler.GetChannelEPG)
		apiGroup.GET("/channels/:id/thumbnail.jpg", handler.GetChannelThumbnail)
		apiGroup.GET("/epg/now", handler.GetNowPlaying)
		apiGroup.GET("/epg/upcoming", handler.GetUpcomingAll)
		apiGroup.GET("/epg/featured", handler.GetFeaturedNowPlaying)
		apiGroup.GET("/playlist.m3u", handler.GetM3UPlaylist)
		apiGroup.GET("/countries", handler.GetCountries)
		apiGroup.GET("/categories", handler.GetCategories)
		apiGroup.GET("/health", handler.HealthCheck)
	}

	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
		"service": "IPTV API Server",
		"version": "3.0.0",
		"endpoints": gin.H{
			"channels":     "/api/channels?country=US&category=news&search=CNN&limit=50&offset=0",
			"channel":      "/api/channels/:id",
			"streams":      "/api/channels/:id/streams",
			"epg":          "/api/channels/:id/epg?timeshift=0&limit=20",
			"thumbnail":    "/api/channels/:id/thumbnail.jpg",
			"featured":     "/api/channels/featured?limit=10",
			"epg_now":      "/api/epg/now",
			"epg_upcoming": "/api/epg/upcoming?within=180&limit=50",
			"epg_featured": "/api/epg/featured?limit=10",
			"playlist":     "/api/playlist.m3u",
			"countries":    "/api/countries",
			"categories":   "/api/categories",
			"health":       "/api/health",
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
