package queue

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/sirupsen/logrus"
)

const keyPrefix = "iptv:"

type RedisQueue struct {
	client *redis.Client
	logger *logrus.Logger
}

type ChannelCheckItem struct {
	ChannelID string    `json:"channel_id"`
	URL       string    `json:"url"`
	Name      string    `json:"name"`
	Timestamp time.Time `json:"timestamp"`
	Retries   int       `json:"retries"`
	Priority  int       `json:"priority"`
}

type ThumbnailItem struct {
	ChannelID string    `json:"channel_id"`
	URL       string    `json:"url"`
	Timestamp time.Time `json:"timestamp"`
	Priority  int       `json:"priority"`
}

func NewRedisQueue(redisURL string, logger *logrus.Logger) (*RedisQueue, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse Redis URL: %w", err)
	}

	client := redis.NewClient(opts)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	logger.Info("Connected to Redis queue")
	return &RedisQueue{client: client, logger: logger}, nil
}

func (q *RedisQueue) GetClient() *redis.Client {
	return q.client
}

func (q *RedisQueue) EnqueueChannelCheck(ctx context.Context, item *ChannelCheckItem) error {
	data, err := json.Marshal(item)
	if err != nil {
		return fmt.Errorf("failed to marshal check item: %w", err)
	}
	return q.client.LPush(ctx, keyPrefix+"channel_check:queue", data).Err()
}

func (q *RedisQueue) EnqueueChannelCheckBatch(ctx context.Context, items []*ChannelCheckItem) error {
	if len(items) == 0 {
		return nil
	}

	pipe := q.client.Pipeline()
	for _, item := range items {
		data, err := json.Marshal(item)
		if err != nil {
			q.logger.Warnf("Failed to marshal check item %s: %v", item.ChannelID, err)
			continue
		}
		pipe.LPush(ctx, keyPrefix+"channel_check:queue", data)
	}
	_, err := pipe.Exec(ctx)
	return err
}

func (q *RedisQueue) DequeueChannelCheck(ctx context.Context, timeout time.Duration) (*ChannelCheckItem, error) {
	result, err := q.client.BRPop(ctx, timeout, keyPrefix+"channel_check:queue").Result()
	if err != nil {
		if err == redis.Nil {
			return nil, nil
		}
		return nil, err
	}
	if len(result) < 2 {
		return nil, fmt.Errorf("invalid redis result")
	}

	var item ChannelCheckItem
	if err := json.Unmarshal([]byte(result[1]), &item); err != nil {
		return nil, err
	}
	return &item, nil
}

func (q *RedisQueue) EnqueueThumbnail(ctx context.Context, item *ThumbnailItem) error {
	data, err := json.Marshal(item)
	if err != nil {
		return fmt.Errorf("failed to marshal thumbnail item: %w", err)
	}
	queueKey := keyPrefix + "thumbnail:queue"
	if item.Priority > 0 {
		queueKey = keyPrefix + "thumbnail:priority_queue"
	}
	return q.client.LPush(ctx, queueKey, data).Err()
}

func (q *RedisQueue) DequeueThumbnail(ctx context.Context, timeout time.Duration) (*ThumbnailItem, error) {
	// Try priority queue first (non-blocking)
	result, err := q.client.RPop(ctx, keyPrefix+"thumbnail:priority_queue").Result()
	if err == nil {
		var item ThumbnailItem
		if err := json.Unmarshal([]byte(result), &item); err == nil {
			return &item, nil
		}
	}

	// Fall back to normal queue (blocking)
	results, err := q.client.BRPop(ctx, timeout, keyPrefix+"thumbnail:queue").Result()
	if err != nil {
		if err == redis.Nil {
			return nil, nil
		}
		return nil, err
	}
	if len(results) < 2 {
		return nil, fmt.Errorf("invalid redis result")
	}

	var item ThumbnailItem
	if err := json.Unmarshal([]byte(results[1]), &item); err != nil {
		return nil, err
	}
	return &item, nil
}

func (q *RedisQueue) GetQueueStats(ctx context.Context) (map[string]int64, error) {
	pipe := q.client.Pipeline()
	checkLen := pipe.LLen(ctx, keyPrefix+"channel_check:queue")
	thumbLen := pipe.LLen(ctx, keyPrefix+"thumbnail:queue")
	thumbPrioLen := pipe.LLen(ctx, keyPrefix+"thumbnail:priority_queue")

	if _, err := pipe.Exec(ctx); err != nil {
		return nil, err
	}

	return map[string]int64{
		"channel_check_queue":      checkLen.Val(),
		"thumbnail_queue":          thumbLen.Val(),
		"thumbnail_priority_queue": thumbPrioLen.Val(),
	}, nil
}

// --- Source pipeline for GitHub crawler ---

type SourceItem struct {
	RawURL     string    `json:"raw_url"`
	GitHubRepo string    `json:"github_repo"`
	FilePath   string    `json:"file_path"`
	Stars      int       `json:"stars"`
	PushedAt   time.Time `json:"pushed_at"`
	EntryCount int       `json:"entry_count"`
}

func (q *RedisQueue) EnqueueSource(ctx context.Context, item *SourceItem) error {
	ok, err := q.IsSourceProcessed(ctx, item.RawURL)
	if err != nil {
		return err
	}
	if ok {
		q.logger.Debugf("Source already processed, skipping: %s", item.RawURL)
		return nil
	}

	data, err := json.Marshal(item)
	if err != nil {
		return fmt.Errorf("failed to marshal source item: %w", err)
	}
	return q.client.LPush(ctx, keyPrefix+"sources:queue", data).Err()
}

func (q *RedisQueue) EnqueueSourceBatch(ctx context.Context, items []*SourceItem) (int, error) {
	if len(items) == 0 {
		return 0, nil
	}
	enqueued := 0
	pipe := q.client.Pipeline()
	for _, item := range items {
		ok, _ := q.IsSourceProcessed(ctx, item.RawURL)
		if ok {
			continue
		}
		data, err := json.Marshal(item)
		if err != nil {
			continue
		}
		pipe.LPush(ctx, keyPrefix+"sources:queue", data)
		enqueued++
	}
	if enqueued == 0 {
		return 0, nil
	}
	_, err := pipe.Exec(ctx)
	return enqueued, err
}

func (q *RedisQueue) DequeueSource(ctx context.Context, timeout time.Duration) (*SourceItem, error) {
	result, err := q.client.BRPop(ctx, timeout, keyPrefix+"sources:queue").Result()
	if err != nil {
		if err == redis.Nil {
			return nil, nil
		}
		return nil, err
	}
	if len(result) < 2 {
		return nil, fmt.Errorf("invalid redis result")
	}

	var item SourceItem
	if err := json.Unmarshal([]byte(result[1]), &item); err != nil {
		return nil, err
	}
	return &item, nil
}

func (q *RedisQueue) DequeueAllSources(ctx context.Context) ([]*SourceItem, error) {
	var items []*SourceItem
	for {
		result, err := q.client.RPop(ctx, keyPrefix+"sources:queue").Result()
		if err != nil {
			if err == redis.Nil {
				break
			}
			return items, err
		}
		var item SourceItem
		if err := json.Unmarshal([]byte(result), &item); err != nil {
			q.logger.Warnf("Failed to unmarshal source item: %v", err)
			continue
		}
		items = append(items, &item)
	}
	return items, nil
}

func (q *RedisQueue) IsSourceProcessed(ctx context.Context, rawURL string) (bool, error) {
	return q.client.SIsMember(ctx, keyPrefix+"sources:processed", rawURL).Result()
}

func (q *RedisQueue) MarkSourceProcessed(ctx context.Context, rawURL string) error {
	pipe := q.client.Pipeline()
	pipe.SAdd(ctx, keyPrefix+"sources:processed", rawURL)
	pipe.Expire(ctx, keyPrefix+"sources:processed", 7*24*time.Hour)
	_, err := pipe.Exec(ctx)
	return err
}

func (q *RedisQueue) MarkSourceFailed(ctx context.Context, rawURL string) error {
	pipe := q.client.Pipeline()
	pipe.SAdd(ctx, keyPrefix+"sources:failed", rawURL)
	pipe.Expire(ctx, keyPrefix+"sources:failed", 24*time.Hour)
	_, err := pipe.Exec(ctx)
	return err
}

func (q *RedisQueue) GetSourceQueueLen(ctx context.Context) (int64, error) {
	return q.client.LLen(ctx, keyPrefix+"sources:queue").Result()
}

func (q *RedisQueue) Close() error {
	return q.client.Close()
}
