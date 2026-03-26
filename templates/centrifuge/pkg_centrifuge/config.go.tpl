// Файл config.go — конфигурация Centrifuge из переменных окружения.
package centrifuge

import (
	"fmt"
	"time"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	PingInterval time.Duration `envconfig:"CENTRIFUGE_PING_INTERVAL" default:"25s"`
	PongTimeout  time.Duration `envconfig:"CENTRIFUGE_PONG_TIMEOUT"  default:"10s"`
}

func LoadConfig() (Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return Config{}, fmt.Errorf("centrifuge config: %w", err)
	}
	return cfg, nil
}
