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

type ThumbnailItem struct {
	ChannelID string    `json:"channel_id"`
	URL       string    `json:"url"`
	Timestamp time.Time `json:"timestamp"`
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

func (q *RedisQueue) EnqueueThumbnail(ctx context.Context, item *ThumbnailItem) error {
	data, err := json.Marshal(item)
	if err != nil {
		return fmt.Errorf("failed to marshal thumbnail item: %w", err)
	}
	return q.client.LPush(ctx, keyPrefix+"thumbnail:queue", data).Err()
}

func (q *RedisQueue) DequeueThumbnail(ctx context.Context, timeout time.Duration) (*ThumbnailItem, error) {
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

func (q *RedisQueue) Close() error {
	return q.client.Close()
}
