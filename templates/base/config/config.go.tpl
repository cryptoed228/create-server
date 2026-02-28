package config

import (
	"fmt"

	"github.com/kelseyhightower/envconfig"
)

type App struct {
	ENV     string `envconfig:"ENV" default:"development"`
	Name    string `envconfig:"APP_NAME" default:"app"`
	Version string `envconfig:"APP_VERSION" default:"1.0.0"`
}

func LoadAppConfig() (App, error) {
	var app App
	if err := envconfig.Process("", &app); err != nil {
		return App{}, fmt.Errorf("failed to load app config: %w", err)
	}
	if err := app.validate(); err != nil {
		return App{}, fmt.Errorf("app config validation failed: %w", err)
	}
	return app, nil
}

func (a *App) validate() error {
	if a.Name == "" {
		return fmt.Errorf("APP_NAME is required")
	}
	return nil
}
