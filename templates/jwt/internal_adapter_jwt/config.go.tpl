// Файл config.go — конфигурация JWT адаптера из переменных окружения.
//
// Добавь нужные поля, например:
//   Secret     string        `envconfig:"JWT_SECRET" required:"true"`
//   AccessTTL  time.Duration `envconfig:"JWT_ACCESS_TTL" default:"15m"`
//   RefreshTTL time.Duration `envconfig:"JWT_REFRESH_TTL" default:"720h"`
package jwt

import (
	"fmt"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
}

func LoadConfig() (Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return Config{}, fmt.Errorf("failed to load jwt config: %w", err)
	}
	return cfg, nil
}
