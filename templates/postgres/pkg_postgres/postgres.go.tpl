// Файл postgres.go — подключение к PostgreSQL через пул соединений (pgxpool).
//
// Pool — обёртка над pgxpool.Pool, которую получает адаптер (internal/adapter/postgres).
// Конфигурируется через переменные окружения POSTGRES_*.
// При создании сразу проверяет подключение через Ping.
package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Pool — обёртка над pgxpool.Pool. Передаётся в адаптер через Wire.
type Pool struct {
	*pgxpool.Pool
}

func New(ctx context.Context, cfg Config) (*Pool, error) {
	poolCfg, err := pgxpool.ParseConfig(cfg.DSN())
	if err != nil {
		return nil, fmt.Errorf("error parse postgres config: %w", err)
	}

	// Здесь можно настроить пул: poolCfg.MaxConns, MinConns и т.д.

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("error create postgres pool: %w", err)
	}

	// Проверяем, что БД доступна — fail fast при старте
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("error ping postgres pool: %w", err)
	}

	return &Pool{Pool: pool}, nil
}
