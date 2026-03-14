package config

import (
	"fmt"
	"net/url"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseURL    string
	RedisURL       string
	PlaylistURL    string
	EpgURL         string
	KinopoiskAPIKey string
	Debug          bool
	FFmpegBin      string
}

func LoadConfig() (*Config, error) {
	_ = godotenv.Load()

	config := &Config{
		Debug:     false,
		FFmpegBin: "ffmpeg",
	}

	config.DatabaseURL = os.Getenv("DATABASE_URL")
	if config.DatabaseURL == "" {
		dbHost := os.Getenv("DB_HOST")
		dbPort := os.Getenv("DB_PORT")
		dbName := os.Getenv("DB_NAME")
		dbUser := os.Getenv("DB_USER")
		dbPassword := os.Getenv("DB_PASSWORD")

		if dbHost != "" && dbPort != "" && dbName != "" && dbUser != "" && dbPassword != "" {
			config.DatabaseURL = fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
				dbHost, dbPort, dbUser, dbPassword, dbName)
		} else {
			config.DatabaseURL = "postgres://megav_user:megav_password@localhost:5432/megav_iptv?sslmode=disable"
		}
	}

	config.RedisURL = os.Getenv("REDIS_URL")
	if config.RedisURL == "" {
		redisHost := os.Getenv("REDIS_HOST")
		redisPort := os.Getenv("REDIS_PORT")
		redisPassword := os.Getenv("REDIS_PASSWORD")
		redisDB := os.Getenv("REDIS_DB")
		if redisDB == "" {
			redisDB = "0"
		}

		if redisHost != "" && redisPort != "" {
			if redisPassword != "" {
				config.RedisURL = fmt.Sprintf("redis://:%s@%s:%s/%s",
					url.QueryEscape(redisPassword), redisHost, redisPort, redisDB)
			} else {
				config.RedisURL = fmt.Sprintf("redis://%s:%s/%s",
					redisHost, redisPort, redisDB)
			}
		} else {
			config.RedisURL = "redis://localhost:6379/0"
		}
	}

	config.PlaylistURL = os.Getenv("PLAYLIST_URL")
	config.EpgURL = os.Getenv("EPG_URL")
	config.KinopoiskAPIKey = os.Getenv("KINOPOISK_API_KEY")

	if v := os.Getenv("DEBUG"); v == "true" || v == "1" {
		config.Debug = true
	}
	if v := os.Getenv("FFMPEG_BIN"); v != "" {
		config.FFmpegBin = v
	}

	return config, nil
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func envDuration(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}
