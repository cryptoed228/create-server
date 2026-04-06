// Файл config.go — конфигурация PostgreSQL из переменных окружения.
// Подключение задаётся через единый URL: DB_POSTGRES_URL.
package postgres

import (
	"fmt"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	URL string `envconfig:"DB_POSTGRES_URL" required:"true"`
}

func LoadConfig() (Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return Config{}, fmt.Errorf("failed to load postgres config: %w", err)
	}
	return cfg, nil
}
