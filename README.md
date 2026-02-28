# create-server

CLI-генератор Go-серверов с Clean Architecture.

Создает готовый проект с Gin, Wire DI, Zap логгером и опциональными модулями: PostgreSQL, Redis, JWT.

## Установка

```bash
go install github.com/cryptoed228/create-server@latest
```

## Использование

### Интерактивный режим

```bash
create-server my-project
```

CLI спросит имя Go модуля и предложит выбрать модули (PostgreSQL, Redis, JWT).

### Флаги (неинтерактивный режим)

```bash
create-server --module github.com/user/api --all my-project
```

| Флаг | Описание |
|------|----------|
| `--module` | Go module path (обязателен для неинтерактивного режима) |
| `--postgres` | Добавить PostgreSQL (pgx + SQLC + миграции + Docker) |
| `--redis` | Добавить Redis (go-redis + адаптер + Docker) |
| `--jwt` | Добавить JWT (golang-jwt + адаптер) |
| `--all` | Добавить все модули |

### Примеры

```bash
# Полный проект со всеми модулями
create-server --module github.com/user/api --all my-api

# Только PostgreSQL
create-server --module github.com/user/api --postgres my-api

# PostgreSQL + Redis, без JWT
create-server --module github.com/user/api --postgres --redis my-api

# Минимальный проект (только HTTP сервер)
create-server --module github.com/user/api my-api
```

### Без установки (go run)

```bash
go run github.com/cryptoed228/create-server@latest my-project
```

## Что генерируется

```
my-project/
├── cmd/app/           # Точка входа + Wire DI
├── config/            # Конфигурация через envconfig
├── internal/
│   ├── controller/    # HTTP маршрутизация (Gin)
│   ├── health/        # Health-check эндпоинт
│   ├── example_uc/    # Пример use case (шаблон для копирования)
│   └── adapter/       # Адаптеры (postgres, redis, jwt)
├── pkg/
│   ├── httpserver/    # HTTP сервер с graceful shutdown
│   ├── logger/        # Zap логгер
│   ├── hash/          # bcrypt хэширование
│   ├── postgres/      # pgx pool (если выбран)
│   ├── redis/         # go-redis клиент (если выбран)
│   └── jwt/           # JWT генерация (если выбран)
├── migrations/        # SQL миграции (если postgres)
├── deployments/db/    # docker-compose для БД
├── Makefile           # Команды: run, build, migrate, sqlc
├── .env.development   # Переменные окружения
└── go.mod
```

## Быстрый старт после генерации

```bash
cd my-project
make docker-db-up   # Запустить PostgreSQL/Redis в Docker (если выбраны)
make migrate-up     # Применить миграции (если PostgreSQL)
make run            # Запустить сервер
```

## Лицензия

MIT
