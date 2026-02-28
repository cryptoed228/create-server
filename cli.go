package main

import (
	"fmt"

	"github.com/charmbracelet/huh"
)

// ProjectConfig — параметры для генерации проекта
type ProjectConfig struct {
	ProjectName string
	ModuleName  string
	Postgres    bool
	Redis       bool
	JWT         bool
}

// runCLI — интерактивный ввод параметров проекта
func runCLI(projectName string) (ProjectConfig, error) {
	cfg := ProjectConfig{}

	// 1. Имя проекта (отдельно, чтобы использовать для дефолта модуля)
	if projectName == "" {
		cfg.ProjectName = "my-server"
		if err := huh.NewInput().
			Title("Имя проекта").
			Value(&cfg.ProjectName).
			WithTheme(huh.ThemeCatppuccin()).
			Run(); err != nil {
			return cfg, err
		}
	} else {
		cfg.ProjectName = projectName
		fmt.Printf("  Проект: %s\n", projectName)
	}

	// 2. Go модуль + выбор модулей
	cfg.ModuleName = "github.com/user/" + cfg.ProjectName
	var selected []string

	form := huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Go модуль (github.com/user/project)").
				Value(&cfg.ModuleName),
		),
		huh.NewGroup(
			huh.NewMultiSelect[string]().
				Title("Выберите модули").
				Description("Space — переключить, Enter — подтвердить").
				Options(
					huh.NewOption("PostgreSQL — БД + SQLC + миграции + Docker", "postgres").Selected(true),
					huh.NewOption("Redis — Кэш + Docker + адаптер", "redis").Selected(true),
					huh.NewOption("JWT — Авторизация + генерация токенов", "jwt"),
				).
				Value(&selected),
		),
	).WithTheme(huh.ThemeCatppuccin())

	if err := form.Run(); err != nil {
		return cfg, err
	}

	for _, m := range selected {
		switch m {
		case "postgres":
			cfg.Postgres = true
		case "redis":
			cfg.Redis = true
		case "jwt":
			cfg.JWT = true
		}
	}

	return cfg, nil
}
