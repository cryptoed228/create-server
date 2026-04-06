// Файл redis.go — подключение к Redis.
//
// Client — обёртка над redis.Client, которую получает адаптер (internal/adapter/redis).
// При создании проверяет подключение через Ping.
package redis

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"
)

// Client — обёртка над redis.Client. Передаётся в адаптер через Wire.
type Client struct {
	*redis.Client
}

func New(ctx context.Context, cfg Config) (*Client, error) {
	opts, err := redis.ParseURL(cfg.URL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse redis url: %w", err)
	}

	rdb := redis.NewClient(opts)

	// Fail fast — проверяем доступность Redis при старте
	if err := rdb.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to redis: %w", err)
	}

	return &Client{Client: rdb}, nil
}

func (c *Client) Close() error {
	return c.Client.Close()
}
