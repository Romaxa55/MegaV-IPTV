package main

import (
	"context"
	"flag"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
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
		thumbnailDir = flag.String("thumbnail-dir", "/app/thumbnails", "Thumbnail storage directory")
		syncOnStart  = flag.Bool("sync", false, "Sync playlist and EPG on startup")
		migrateOnly  = flag.Bool("migrate-only", false, "Run migrations and exit")
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

	if err := repo.RunMigrations("migrations"); err != nil {
		logger.WithError(err).Warn("Migrations failed (may already be applied)")
	}

	if *migrateOnly {
		logger.Info("Migrations complete, exiting (migrate-only mode)")
		return
	}

	if cfg.PlaylistURL != "" || cfg.EpgURL != "" {
		if err := repo.UpsertConfig(cfg.PlaylistURL, cfg.EpgURL); err != nil {
			logger.WithError(err).Warn("Failed to upsert config from env")
		} else {
			logger.Info("Config updated from environment variables")
		}
	}

	if *syncOnStart {
		go func() {
			runInitialSync(repo, logger)
			backgroundSync(repo, logger)
		}()
	} else {
		go backgroundSync(repo, logger)
	}

	// Connect to Redis for thumbnail queue
	var thumbQueue *queue.RedisQueue
	var redisClient interface{ Close() error }

	tq, err := queue.NewRedisQueue(cfg.RedisURL, logger)
	if err != nil {
		logger.WithError(err).Warn("Redis unavailable, thumbnails will be served from disk only")
	} else {
		thumbQueue = tq
		redisClient = tq
	}
	if redisClient != nil {
		defer redisClient.Close()
	}

	thumbService := services.NewThumbnailService(logger, cfg.FFmpegBin, *thumbnailDir, 15*time.Second)

	var posterService *services.PosterService
	if cfg.KinopoiskAPIKey != "" && thumbQueue != nil {
		posterService = services.NewPosterService(cfg.KinopoiskAPIKey, thumbQueue.GetClient(), repo, logger)
		logger.Info("Kinopoisk poster service enabled")
	}

	handlerOpts := api.HandlerOpts{
		Repo:          repo,
		Logger:        logger,
		ThumbService:  thumbService,
		PosterService: posterService,
	}
	if thumbQueue != nil {
		handlerOpts.RedisClient = thumbQueue.GetClient()
		handlerOpts.ThumbQueue = thumbQueue
	}

	handler := api.NewHandler(handlerOpts)

	router := gin.New()
	router.Use(gin.Logger())
	router.Use(gin.Recovery())

	corsConfig := cors.DefaultConfig()
	corsConfig.AllowAllOrigins = true
	corsConfig.AllowMethods = []string{"GET", "POST", "OPTIONS"}
	corsConfig.AllowHeaders = []string{"Origin", "Content-Type", "Accept"}
	router.Use(cors.New(corsConfig))

	apiGroup := router.Group("/api")
	{
		apiGroup.GET("/channels", handler.GetChannels)
		apiGroup.GET("/channels/featured", handler.GetFeaturedChannels)
		apiGroup.GET("/channels/:id", handler.GetChannel)
		apiGroup.GET("/channels/:id/streams", handler.GetChannelStreams)
		apiGroup.GET("/channels/:id/epg", handler.GetChannelEPG)
		apiGroup.GET("/channels/:id/thumbnail.jpg", handler.GetChannelThumbnail)
		apiGroup.GET("/epg/now", handler.GetNowPlaying)
		apiGroup.GET("/epg/movies", handler.GetMoviesNowPlaying)
		apiGroup.GET("/epg/upcoming", handler.GetUpcomingAll)
		apiGroup.GET("/epg/featured", handler.GetFeaturedNowPlaying)
		apiGroup.GET("/playlist.m3u", handler.GetM3UPlaylist)
		apiGroup.GET("/categories", handler.GetCategories)
		apiGroup.GET("/health", handler.HealthCheck)

		apiGroup.POST("/sync/playlist", handler.SyncPlaylist)
		apiGroup.POST("/sync/epg", handler.SyncEPG)
		apiGroup.POST("/sync/all", handler.SyncAll)
	}

	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"service": "MegaV IPTV API",
			"version": "4.1.0",
			"endpoints": gin.H{
				"channels":     "/api/channels?category=Кино&search=Первый&limit=50&offset=0",
				"channel":      "/api/channels/:id",
				"streams":      "/api/channels/:id/streams",
				"epg":          "/api/channels/:id/epg?limit=20",
				"thumbnail":    "/api/channels/:id/thumbnail.jpg",
				"featured":     "/api/channels/featured?limit=10",
				"epg_now":      "/api/epg/now",
				"epg_movies":   "/api/epg/movies?limit=20",
				"epg_upcoming": "/api/epg/upcoming?within=180&limit=50",
				"epg_featured": "/api/epg/featured?limit=10",
				"playlist":     "/api/playlist.m3u",
				"categories":   "/api/categories",
				"health":       "/api/health",
				"sync_all":     "POST /api/sync/all",
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

func runInitialSync(repo *repositories.IPTVRepository, logger *logrus.Logger) {
	playlistURL, epgURL, err := repo.GetConfig()
	if err != nil {
		logger.WithError(err).Error("Failed to get config for initial sync")
		return
	}

	syncService := services.NewSyncService(repo, logger)

	logger.Info("Running initial playlist sync...")
	if err := syncService.SyncPlaylist(playlistURL); err != nil {
		logger.WithError(err).Error("Initial playlist sync failed")
		return
	}

	logger.Info("Running initial EPG sync...")
	if err := syncService.SyncEPG(epgURL); err != nil {
		logger.WithError(err).Error("Initial EPG sync failed")
	}
}

func backgroundSync(repo *repositories.IPTVRepository, logger *logrus.Logger) {
	ticker := time.NewTicker(6 * time.Hour)
	defer ticker.Stop()

	for range ticker.C {
		logger.Info("Background sync starting...")
		runInitialSync(repo, logger)
		logger.Info("Background sync complete")
	}
}
