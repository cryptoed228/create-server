package http_v1

import (
	"fmt"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	AllowOrigins     []string `envconfig:"CORS_ALLOW_ORIGINS" default:"*"`
	AllowMethods     []string `envconfig:"CORS_ALLOW_METHODS" default:"GET,POST,PUT,DELETE,OPTIONS"`
	AllowHeaders     []string `envconfig:"CORS_ALLOW_HEADERS" default:"Content-Type,Authorization"`
	ExposeHeaders    []string `envconfig:"CORS_EXPOSE_HEADERS" default:"Content-Length"`
	AllowCredentials bool     `envconfig:"CORS_ALLOW_CREDENTIALS" default:"true"`
}

func LoadConfig() (Config, error) {
	var cfg Config
	if err := envconfig.Process("", &cfg); err != nil {
		return Config{}, fmt.Errorf("failed to load http_v1 controller config: %w", err)
	}
	return cfg, nil
}
