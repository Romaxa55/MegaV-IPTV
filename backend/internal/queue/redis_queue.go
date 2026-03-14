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

func (q *RedisQueue) Close() error {
	return q.client.Close()
}
