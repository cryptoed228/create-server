# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

CLI tool that generates Go server projects with optional modules (PostgreSQL, Redis, JWT). Users run `go run github.com/cryptoed228/create-server@latest my-project` and get a ready-to-run server with clean architecture.

## Build & Run

```bash
go build -o create-server .        # build
./create-server my-project         # interactive mode
./create-server my-project --module github.com/user/my-project --all  # non-interactive
```

No tests or linter configured in the generator itself.

## Architecture

Three files do everything:

- **main.go** — Entry point. Flag parsing → either interactive (`runCLI`) or non-interactive config → `generate(cfg)`
- **cli.go** — Interactive UI via `charmbracelet/huh`. Two-step form: module name input → multi-select modules. Returns `ProjectConfig`
- **generator.go** — Template engine. `getMappings()` returns ~80 template→target file pairs with module conditions. `generate()` iterates mappings, skips disabled modules, renders templates, writes files

## Template System

Templates live in `templates/` embedded via `//go:embed all:templates`.

Four directories: `base/` (always), `postgres/`, `redis/`, `jwt/` (conditional).

Two file types:
- **`.tmpl`** — Go `text/template` files, rendered with `ProjectConfig` (`{{.ModuleName}}`, `{{if .Postgres}}`, etc.)
- **`.tpl`** — Plain files with `{{MODULE}}` string-replaced to the actual Go module path

Each mapping in `getMappings()` has: `Source`, `Target`, `Module` (empty = always include), `IsTmpl` (true = Go template).

## Generated Project Patterns

- **DI**: Google Wire. Every package exports `var Set = wire.NewSet(...)`, composed in `cmd/app/wire.go`
- **Config**: `kelseyhightower/envconfig` with `LoadConfig()` per package
- **HTTP**: Gin framework with standardized JSON responses (`OK()`, `BadRequest()`, etc.)
- **Adapters**: `pkg/{module}/` = pure connection layer, `internal/adapter/{module}/` = business logic wrapper
- **Logging**: Zap with lumberjack rotation (console + file outputs)

## Language

All UI text, comments, and documentation are in Russian.
