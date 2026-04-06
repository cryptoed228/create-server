// Файл config.go — конфигурация Redis из переменных окружения.
// Подключение задаётся через единый URL: DB_REDIS_URL.
package redis

import (
	"fmt"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	URL string `envconfig:"DB_REDIS_URL" required:"true"`
}

func LoadConfig() (Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return Config{}, fmt.Errorf("failed to load redis config: %w", err)
	}
	return cfg, nil
}
