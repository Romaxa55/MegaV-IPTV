package services

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/romaxa55/iptv-parser/internal/queue"
	"github.com/sirupsen/logrus"
)

type GitHubCrawler struct {
	logger      *logrus.Logger
	client      *http.Client
	token       string
	redisQueue  *queue.RedisQueue
	minStars    int
	maxAgeDays  int
	minChannels int
}

type CrawlerConfig struct {
	Token       string
	MinStars    int
	MaxAgeDays  int
	MinChannels int
}

func NewGitHubCrawler(logger *logrus.Logger, rq *queue.RedisQueue, cfg CrawlerConfig) *GitHubCrawler {
	if cfg.MaxAgeDays == 0 {
		cfg.MaxAgeDays = 7
	}
	if cfg.MinChannels == 0 {
		cfg.MinChannels = 5
	}
	return &GitHubCrawler{
		logger:      logger,
		client:      &http.Client{Timeout: 30 * time.Second},
		token:       cfg.Token,
		redisQueue:  rq,
		minStars:    cfg.MinStars,
		maxAgeDays:  cfg.MaxAgeDays,
		minChannels: cfg.MinChannels,
	}
}

// --- GitHub API types ---

type ghRepoSearchResponse struct {
	TotalCount int      `json:"total_count"`
	Items      []ghRepo `json:"items"`
}

type ghRepo struct {
	FullName  string    `json:"full_name"`
	Fork      bool      `json:"fork"`
	StarCount int       `json:"stargazers_count"`
	PushedAt  time.Time `json:"pushed_at"`
	Language  string    `json:"language"`
}

type ghCodeSearchResponse struct {
	TotalCount int            `json:"total_count"`
	Items      []ghCodeResult `json:"items"`
}

type ghCodeResult struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

type ghTreeResponse struct {
	Tree []ghTreeEntry `json:"tree"`
}

type ghTreeEntry struct {
	Path string `json:"path"`
	Type string `json:"type"`
}

// --- Search queries ---

func (c *GitHubCrawler) buildRepoQueries() []string {
	cutoff := time.Now().AddDate(0, 0, -c.maxAgeDays).Format("2006-01-02")
	return []string{
		fmt.Sprintf("iptv m3u pushed:>%s", cutoff),
		fmt.Sprintf("iptv playlist pushed:>%s", cutoff),
		fmt.Sprintf("m3u channels pushed:>%s", cutoff),
		fmt.Sprintf("iptv list pushed:>%s", cutoff),
		fmt.Sprintf("free iptv pushed:>%s", cutoff),
		fmt.Sprintf("m3u8 live tv pushed:>%s", cutoff),
	}
}

// --- HTTP helpers ---

func (c *GitHubCrawler) doGitHubRequest(ctx context.Context, u string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", u, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 403 || resp.StatusCode == 429 {
		return nil, fmt.Errorf("rate limited: %d", resp.StatusCode)
	}
	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("status %d: %s", resp.StatusCode, string(body[:min(len(body), 200)]))
	}

	return io.ReadAll(resp.Body)
}

func (c *GitHubCrawler) searchRepos(ctx context.Context, query string, page int) (*ghRepoSearchResponse, error) {
	u := fmt.Sprintf("https://api.github.com/search/repositories?q=%s&sort=updated&per_page=100&page=%d",
		url.QueryEscape(query), page)

	body, err := c.doGitHubRequest(ctx, u)
	if err != nil {
		return nil, err
	}

	var result ghRepoSearchResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("decode error: %w", err)
	}
	return &result, nil
}

func (c *GitHubCrawler) findM3UInRepo(ctx context.Context, repo string) ([]string, error) {
	u := fmt.Sprintf("https://api.github.com/search/code?q=EXTINF+repo:%s+language:M3U&per_page=20",
		url.QueryEscape(repo))

	body, err := c.doGitHubRequest(ctx, u)
	if err != nil {
		return nil, err
	}

	var result ghCodeSearchResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}

	var paths []string
	for _, item := range result.Items {
		lower := strings.ToLower(item.Path)
		if strings.HasSuffix(lower, ".m3u") || strings.HasSuffix(lower, ".m3u8") {
			paths = append(paths, item.Path)
		}
	}
	return paths, nil
}

func (c *GitHubCrawler) getRawURL(repo, path string) string {
	return fmt.Sprintf("https://raw.githubusercontent.com/%s/HEAD/%s", repo, path)
}

func (c *GitHubCrawler) validateM3U(ctx context.Context, rawURL string) (int, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", rawURL, nil)
	if err != nil {
		return 0, err
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("fetch failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return 0, fmt.Errorf("status %d", resp.StatusCode)
	}

	limited := io.LimitReader(resp.Body, 10*1024*1024)
	body, err := io.ReadAll(limited)
	if err != nil {
		return 0, fmt.Errorf("read failed: %w", err)
	}

	count := strings.Count(string(body), "#EXTINF")
	if count == 0 {
		return 0, fmt.Errorf("no #EXTINF entries")
	}
	return count, nil
}

func (c *GitHubCrawler) rateSleep(ctx context.Context, d time.Duration) bool {
	select {
	case <-time.After(d):
		return true
	case <-ctx.Done():
		return false
	}
}

// --- Main crawl logic ---

func (c *GitHubCrawler) Crawl(ctx context.Context) (int, error) {
	queries := c.buildRepoQueries()
	seenRepos := make(map[string]bool)
	seenFiles := make(map[string]bool)
	var allItems []*queue.SourceItem

	for qi, query := range queries {
		if ctx.Err() != nil {
			break
		}
		c.logger.Infof("[%d/%d] Repo search: %s", qi+1, len(queries), query)

		for page := 1; page <= 5; page++ {
			result, err := c.searchRepos(ctx, query, page)
			if err != nil {
				if strings.Contains(err.Error(), "rate limited") {
					c.logger.Warn("Rate limited on repo search, waiting 60s...")
					if !c.rateSleep(ctx, 60*time.Second) {
						return len(allItems), ctx.Err()
					}
					break
				}
				c.logger.WithError(err).Warnf("Repo search failed (page %d)", page)
				break
			}

			c.logger.Infof("  Page %d: %d repos (total: %d)", page, len(result.Items), result.TotalCount)

			for _, repo := range result.Items {
				if repo.Fork || seenRepos[repo.FullName] {
					continue
				}
				if repo.StarCount < c.minStars {
					continue
				}
				seenRepos[repo.FullName] = true

				c.logger.Debugf("  Scanning repo: %s (stars=%d)", repo.FullName, repo.StarCount)

				if !c.rateSleep(ctx, 3*time.Second) {
					return len(allItems), ctx.Err()
				}

				m3uFiles, err := c.findM3UInRepo(ctx, repo.FullName)
				if err != nil {
					if strings.Contains(err.Error(), "rate limited") {
						c.logger.Warn("Rate limited on code search, waiting 60s...")
						if !c.rateSleep(ctx, 60*time.Second) {
							return len(allItems), ctx.Err()
						}
						continue
					}
					c.logger.Debugf("  Skip %s: %v", repo.FullName, err)
					continue
				}

				if len(m3uFiles) == 0 {
					continue
				}

				for _, filePath := range m3uFiles {
					rawURL := c.getRawURL(repo.FullName, filePath)
					if seenFiles[rawURL] {
						continue
					}
					seenFiles[rawURL] = true

					entryCount, err := c.validateM3U(ctx, rawURL)
					if err != nil {
						c.logger.Debugf("    Skip %s: %v", filePath, err)
						continue
					}
					if entryCount < c.minChannels {
						c.logger.Debugf("    Skip %s: only %d entries", filePath, entryCount)
						continue
					}

					c.logger.Infof("    Found: %s/%s (%d entries, %d stars)",
						repo.FullName, filePath, entryCount, repo.StarCount)

					item := &queue.SourceItem{
						RawURL:     rawURL,
						GitHubRepo: repo.FullName,
						FilePath:   filePath,
						Stars:      repo.StarCount,
						PushedAt:   repo.PushedAt,
						EntryCount: entryCount,
					}
					allItems = append(allItems, item)

					if err := c.redisQueue.EnqueueSource(ctx, item); err != nil {
						c.logger.WithError(err).Warn("Failed to enqueue source immediately")
					}
				}
			}

			if len(result.Items) < 100 || result.TotalCount <= page*100 {
				break
			}
			if !c.rateSleep(ctx, 2*time.Second) {
				return len(allItems), ctx.Err()
			}
		}

		if !c.rateSleep(ctx, 2*time.Second) {
			return len(allItems), ctx.Err()
		}
	}

	c.logger.Infof("Crawl complete: %d playlists found and enqueued", len(allItems))

	return len(allItems), nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
