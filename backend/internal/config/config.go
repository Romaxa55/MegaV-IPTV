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
	DatabaseURL string
	RedisURL    string

	BatchSize  int
	Workers    int
	Timeout    time.Duration
	Debug      bool
	RateLimit  int
	RateBurst  int
	FFprobeBin string
	FFmpegBin  string
}

func LoadConfig() (*Config, error) {
	_ = godotenv.Load()

	config := &Config{
		BatchSize:  100,
		Workers:    50,
		Timeout:    30 * time.Second,
		Debug:      false,
		RateLimit:  1000,
		RateBurst:  50,
		FFprobeBin: "ffprobe",
		FFmpegBin:  "ffmpeg",
	}

	config.RedisURL = os.Getenv("REDIS_URL")
	if config.RedisURL == "" {
		redisHost := os.Getenv("REDIS_HOST")
		redisPort := os.Getenv("REDIS_PORT")
		redisDB := os.Getenv("REDIS_DB")
		redisPassword := os.Getenv("REDIS_PASSWORD")

		if redisHost != "" && redisPort != "" {
			if redisPassword != "" {
				escapedPassword := url.QueryEscape(redisPassword)
				config.RedisURL = fmt.Sprintf("redis://:%s@%s:%s/%s",
					escapedPassword, redisHost, redisPort, redisDB)
			} else {
				config.RedisURL = fmt.Sprintf("redis://%s:%s/%s",
					redisHost, redisPort, redisDB)
			}
		} else {
			config.RedisURL = "redis://localhost:6379/0"
		}
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
			config.DatabaseURL = "postgres://megav_user:megav_password@localhost:5432/megav_sources?sslmode=disable"
		}
	}

	if v := os.Getenv("BATCH_SIZE"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			config.BatchSize = n
		}
	}
	if v := os.Getenv("WORKERS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			config.Workers = n
		}
	}
	if v := os.Getenv("TIMEOUT"); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			config.Timeout = d
		} else if n, err := strconv.Atoi(v); err == nil {
			config.Timeout = time.Duration(n) * time.Second
		}
	}
	if v := os.Getenv("DEBUG"); v == "true" || v == "1" {
		config.Debug = true
	}
	if v := os.Getenv("FFPROBE_BIN"); v != "" {
		config.FFprobeBin = v
	}
	if v := os.Getenv("FFMPEG_BIN"); v != "" {
		config.FFmpegBin = v
	}

	return config, nil
}

func (c *Config) Validate() error {
	if c.BatchSize <= 0 {
		return fmt.Errorf("batch_size must be positive, got %d", c.BatchSize)
	}
	if c.Workers <= 0 {
		return fmt.Errorf("workers must be positive, got %d", c.Workers)
	}
	return nil
}
