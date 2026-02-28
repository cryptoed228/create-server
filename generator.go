package main

import (
	"embed"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/template"
)

//go:embed all:templates
var templatesFS embed.FS

// templateMapping — карта: шаблон → путь в сгенерированном проекте
type templateMapping struct {
	Source string // путь в embed FS
	Target string // путь в сгенерированном проекте
	Module string // "" = всегда, "postgres"/"redis"/"jwt" = условно
	IsTmpl bool   // true = Go template, false = копируется as-is (с заменой {{MODULE}})
}

// getMappings возвращает список всех файлов для генерации
func getMappings() []templateMapping {
	return []templateMapping{
		// ===== BASE (всегда) =====
		// cmd/app
		{Source: "templates/base/cmd_app/main.go.tmpl", Target: "cmd/app/main.go", IsTmpl: true},
		{Source: "templates/base/cmd_app/app.go.tmpl", Target: "cmd/app/app.go", IsTmpl: true},
		{Source: "templates/base/cmd_app/wire.go.tmpl", Target: "cmd/app/wire.go", IsTmpl: true},
		// config
		{Source: "templates/base/config/config.go.tpl", Target: "config/config.go"},
		// pkg/httpserver
		{Source: "templates/base/pkg_httpserver/httpserver.go.tpl", Target: "pkg/httpserver/httpserver.go"},
		{Source: "templates/base/pkg_httpserver/config.go.tpl", Target: "pkg/httpserver/config.go"},
		{Source: "templates/base/pkg_httpserver/response.go.tpl", Target: "pkg/httpserver/response.go"},
		{Source: "templates/base/pkg_httpserver/wire.go.tpl", Target: "pkg/httpserver/wire.go"},
		// pkg/logger
		{Source: "templates/base/pkg_logger/logger.go.tpl", Target: "pkg/logger/logger.go"},
		{Source: "templates/base/pkg_logger/wire.go.tpl", Target: "pkg/logger/wire.go"},
		// pkg/hash
		{Source: "templates/base/pkg_hash/hash.go.tpl", Target: "pkg/hash/hash.go"},
		// internal/controller
		{Source: "templates/base/internal_controller/controller.go.tmpl", Target: "internal/controller/http_v1/controller.go", IsTmpl: true},
		{Source: "templates/base/internal_controller/wire.go.tpl", Target: "internal/controller/http_v1/wire.go"},
		// internal/health
		{Source: "templates/base/internal_health/http_v1.go.tpl", Target: "internal/health/http_v1.go"},
		// internal/example_uc
		{Source: "templates/base/internal_example_uc/usecase.go.tmpl", Target: "internal/example_uc/usecase.go", IsTmpl: true},
		{Source: "templates/base/internal_example_uc/http_v1.go.tpl", Target: "internal/example_uc/http_v1.go"},
		{Source: "templates/base/internal_example_uc/dto.go.tpl", Target: "internal/example_uc/dto.go"},
		{Source: "templates/base/internal_example_uc/helpers.go.tpl", Target: "internal/example_uc/helpers.go"},
		{Source: "templates/base/internal_example_uc/wire.go.tpl", Target: "internal/example_uc/wire.go"},
		// Корневые файлы
		{Source: "templates/base/go.mod.tmpl", Target: "go.mod", IsTmpl: true},
		{Source: "templates/base/Makefile.tmpl", Target: "Makefile", IsTmpl: true},
		{Source: "templates/base/env.tmpl", Target: ".env.development", IsTmpl: true},
		{Source: "templates/base/docker-compose.yaml.tmpl", Target: "deployments/db/docker-compose.yaml", IsTmpl: true},
		{Source: "templates/base/README.md.tmpl", Target: "README.md", IsTmpl: true},
		{Source: "templates/base/gitignore", Target: ".gitignore"},

		// ===== POSTGRES =====
		{Source: "templates/postgres/pkg_postgres/postgres.go.tpl", Target: "pkg/postgres/postgres.go", Module: "postgres"},
		{Source: "templates/postgres/pkg_postgres/config.go.tpl", Target: "pkg/postgres/config.go", Module: "postgres"},
		{Source: "templates/postgres/pkg_postgres/wire.go.tpl", Target: "pkg/postgres/wire.go", Module: "postgres"},
		{Source: "templates/postgres/internal_adapter_postgres/adapter.go.tpl", Target: "internal/adapter/postgres/adapter.go", Module: "postgres"},
		{Source: "templates/postgres/internal_adapter_postgres/wire.go.tpl", Target: "internal/adapter/postgres/wire.go", Module: "postgres"},
		{Source: "templates/postgres/sqlc.yaml.tmpl", Target: "sqlc.yaml", Module: "postgres", IsTmpl: true},

		// ===== REDIS =====
		{Source: "templates/redis/pkg_redis/redis.go.tpl", Target: "pkg/redis/redis.go", Module: "redis"},
		{Source: "templates/redis/pkg_redis/config.go.tpl", Target: "pkg/redis/config.go", Module: "redis"},
		{Source: "templates/redis/pkg_redis/wire.go.tpl", Target: "pkg/redis/wire.go", Module: "redis"},
		{Source: "templates/redis/internal_adapter_redis/adapter.go.tpl", Target: "internal/adapter/redis/adapter.go", Module: "redis"},
		{Source: "templates/redis/internal_adapter_redis/wire.go.tpl", Target: "internal/adapter/redis/wire.go", Module: "redis"},

		// ===== JWT =====
		{Source: "templates/jwt/pkg_jwt/jwt.go.tpl", Target: "pkg/jwt/jwt.go", Module: "jwt"},
		{Source: "templates/jwt/internal_adapter_jwt/adapter.go.tpl", Target: "internal/adapter/jwt/adapter.go", Module: "jwt"},
		{Source: "templates/jwt/internal_adapter_jwt/config.go.tpl", Target: "internal/adapter/jwt/config.go", Module: "jwt"},
		{Source: "templates/jwt/internal_adapter_jwt/wire.go.tpl", Target: "internal/adapter/jwt/wire.go", Module: "jwt"},
	}
}

// generate — основная функция генерации проекта
func generate(cfg ProjectConfig) error {
	// Проверяем, что директория не существует
	if _, err := os.Stat(cfg.ProjectName); err == nil {
		return fmt.Errorf("директория %s уже существует", cfg.ProjectName)
	}

	mappings := getMappings()

	for _, m := range mappings {
		// Пропускаем модули, которые не выбраны
		if !isModuleEnabled(m.Module, cfg) {
			continue
		}

		// Читаем шаблон из embed FS
		content, err := templatesFS.ReadFile(m.Source)
		if err != nil {
			return fmt.Errorf("не удалось прочитать шаблон %s: %w", m.Source, err)
		}

		var result string

		if m.IsTmpl {
			// Рендерим Go template
			tmpl, err := template.New(m.Source).Parse(string(content))
			if err != nil {
				return fmt.Errorf("ошибка парсинга шаблона %s: %w", m.Source, err)
			}
			var buf strings.Builder
			if err := tmpl.Execute(&buf, cfg); err != nil {
				return fmt.Errorf("ошибка рендеринга шаблона %s: %w", m.Source, err)
			}
			result = buf.String()
		} else {
			// Копируем as-is, заменяя плейсхолдер module path
			result = strings.ReplaceAll(string(content), "{{MODULE}}", cfg.ModuleName)
		}

		// Записываем файл
		targetPath := filepath.Join(cfg.ProjectName, m.Target)
		if err := writeFile(targetPath, result); err != nil {
			return fmt.Errorf("не удалось записать %s: %w", targetPath, err)
		}

		fmt.Printf("  ✓ %s\n", m.Target)
	}

	// Создаём пустые директории
	if cfg.Postgres {
		os.MkdirAll(filepath.Join(cfg.ProjectName, "migrations"), 0755)
		os.MkdirAll(filepath.Join(cfg.ProjectName, "internal/adapter/postgres/queries"), 0755)
	}

	return nil
}

// isModuleEnabled проверяет, выбран ли модуль
func isModuleEnabled(module string, cfg ProjectConfig) bool {
	switch module {
	case "":
		return true
	case "postgres":
		return cfg.Postgres
	case "redis":
		return cfg.Redis
	case "jwt":
		return cfg.JWT
	}
	return false
}

// writeFile создаёт директории и записывает файл
func writeFile(path, content string) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0644)
}
