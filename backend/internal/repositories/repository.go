package repositories

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	_ "github.com/lib/pq"
	"github.com/sirupsen/logrus"
)

type IPTVRepository struct {
	db     *sql.DB
	logger *logrus.Logger
}

func NewIPTVRepository(databaseURL string, logger *logrus.Logger) (*IPTVRepository, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	maxOpen := envInt("DB_MAX_OPEN_CONNS", 25)
	maxIdle := envInt("DB_MAX_IDLE_CONNS", 10)
	db.SetMaxOpenConns(maxOpen)
	db.SetMaxIdleConns(maxIdle)
	db.SetConnMaxLifetime(5 * time.Minute)

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	logger.Info("Connected to PostgreSQL")

	return &IPTVRepository{db: db, logger: logger}, nil
}

func (r *IPTVRepository) Close() {
	if r.db != nil {
		r.db.Close()
	}
}

func (r *IPTVRepository) GetDB() *sql.DB {
	return r.db
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func (r *IPTVRepository) RunMigrations(migrationsDir string) error {
	entries, err := os.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("failed to read migrations dir: %w", err)
	}

	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)

	for _, f := range files {
		path := filepath.Join(migrationsDir, f)
		content, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("failed to read migration %s: %w", f, err)
		}

		r.logger.Infof("Running migration: %s", f)
		if _, err := r.db.Exec(string(content)); err != nil {
			return fmt.Errorf("failed to execute migration %s: %w", f, err)
		}
	}

	r.logger.Info("All migrations completed")
	return nil
}
