You are working on a Go backend project that follows a strict vertical-slice clean architecture. When implementing any feature, follow EVERY rule below exactly. Do not deviate.

Before writing any code, read the existing project structure to understand what packages, adapters, and domain models already exist. Reuse them — do not duplicate.

$arguments

---

# ARCHITECTURE RULES

## 1. Project Structure Overview

```
cmd/app/                         # Entry point: main.go, app.go, wire.go
config/                          # App-level config (envconfig)
internal/
  domain/                        # Shared domain models (structs used across usecases)
  controller/
    http_v1/                     # HTTP router — maps routes to usecase handlers
    ws/                          # WebSocket router (if centrifuge is used)
  adapter/
    postgres/                    # Adapter: wraps pkg/postgres with business methods
    redis/                       # Adapter: wraps pkg/redis with business methods
    jwt/                         # Adapter: wraps pkg/jwt with business methods
    centrifuge/                  # Adapter: wraps pkg/centrifuge with business methods
    {any_external_service}/      # Same pattern for any external dependency
  {feature_name}_uc/             # Usecase: vertical slice for one feature
pkg/
  httpserver/                    # HTTP server, config, response helpers
  logger/                       # Zap logger with rotation
  hash/                         # bcrypt, UUID utilities
  postgres/                     # Pure pgxpool connection wrapper
  redis/                        # Pure redis client wrapper
  jwt/                          # Pure JWT generate/parse utilities
  centrifuge/                   # Pure Centrifuge node wrapper
```

**Key principle:** Every package in `pkg/` is a pure infrastructure wrapper with zero business logic. Every package in `internal/adapter/` wraps a `pkg/` package and adds business-specific methods. Every package in `internal/{name}_uc/` is an isolated vertical slice of business logic.

---

## 2. Usecase Package (Vertical Slice)

Each feature lives in its own package: `internal/{feature_name}_uc/`

### Required files:

| File | Purpose |
|------|---------|
| `usecase.go` | Business logic, interface definitions for dependencies |
| `dto.go` | Input/Output structs, Validate() method on Input |
| `http_v1.go` | HTTP handler (if called from HTTP) |
| `ws_v1.go` | WebSocket handler (if called from WebSocket) |
| `bootstrap.go` | Bootstrap/startup handler (if runs on app start) |
| `cron.go` | Cron handler (if called on schedule) |
| `wire.go` | Wire provider set |
| `helpers.go` | Private helper functions (optional) |

The handler file name depends on WHO calls this usecase. If HTTP calls it — `http_v1.go`. If a cron job — `cron.go`. If it runs once on startup — `bootstrap.go`. A usecase can have multiple handlers.

### usecase.go — full pattern:

```go
package create_user_uc

import (
    "context"
    "fmt"

    "go.uber.org/zap"
    "your-module/internal/adapter/postgres"
    "your-module/internal/domain"
)

// Postgres — port: interface for external dependencies this usecase needs.
// The usecase depends on THIS interface, not on the concrete adapter.
// The concrete *postgres.Adapter is injected via the constructor — Go checks
// at compile time that *postgres.Adapter satisfies this interface.
type Postgres interface {
    CreateUser(ctx context.Context, user domain.User) (domain.User, error)
    GetUserByEmail(ctx context.Context, email string) (domain.User, error)
}

type Usecase struct {
    logger   *zap.SugaredLogger
    postgres Postgres // <-- use the INTERFACE, not the concrete type
}

// New accepts the CONCRETE adapter type (*postgres.Adapter) so Wire can resolve it.
// The field stores it as the Postgres interface — compile-time check that adapter implements it.
func New(log *zap.SugaredLogger, pg *postgres.Adapter) *Usecase {
    return &Usecase{
        logger:   log,
        postgres: pg,
    }
}

func (u *Usecase) Execute(ctx context.Context, input Input) (Output, error) {
    // 1. Business logic uses u.postgres (the interface)
    existing, err := u.postgres.GetUserByEmail(ctx, input.Email)
    if err != nil {
        return Output{}, fmt.Errorf("check existing user: %w", err)
    }
    if existing.ID != "" {
        return Output{}, fmt.Errorf("user with email %s already exists", input.Email)
    }

    user := domain.User{
        Email: input.Email,
        Name:  input.Name,
    }

    created, err := u.postgres.CreateUser(ctx, user)
    if err != nil {
        return Output{}, fmt.Errorf("create user: %w", err)
    }

    return Output{
        ID:    created.ID,
        Email: created.Email,
        Name:  created.Name,
    }, nil
}
```

**CRITICAL RULES for usecase.go:**
- Define ONE interface per external dependency (Postgres, Redis, Cache, etc.)
- Interface contains ONLY the methods THIS usecase needs — not all adapter methods
- Struct field uses the interface type (`postgres Postgres`)
- Constructor `New()` accepts the concrete adapter (`pg *postgres.Adapter`) — Wire needs concrete types
- All business logic goes through the interface, never the concrete type directly
- If a usecase needs multiple adapters, define multiple interfaces and accept multiple concrete adapters

Example with multiple adapters:

```go
type Postgres interface {
    CreateUser(ctx context.Context, user domain.User) (domain.User, error)
}

type Redis interface {
    SetSession(ctx context.Context, userID string, token string) error
}

type JWT interface {
    GenerateAccessToken(userID string) (string, error)
    GenerateRefreshToken(userID string) (string, error)
}

type Usecase struct {
    logger   *zap.SugaredLogger
    postgres Postgres
    redis    Redis
    jwt      JWT
}

func New(log *zap.SugaredLogger, pg *postgres.Adapter, rd *redis.Adapter, j *jwt.Adapter) *Usecase {
    return &Usecase{
        logger:   log,
        postgres: pg,
        redis:    rd,
        jwt:      j,
    }
}
```

### dto.go — full pattern:

```go
package create_user_uc

import "fmt"

type Input struct {
    Email string `json:"email"`
    Name  string `json:"name"`
}

// Validate is called in the handler BEFORE passing Input to the usecase.
// Returns nil if valid.
func (i Input) Validate() error {
    if i.Email == "" {
        return fmt.Errorf("email is required")
    }
    if i.Name == "" {
        return fmt.Errorf("name is required")
    }
    return nil
}

type Output struct {
    ID    string `json:"id"`
    Email string `json:"email"`
    Name  string `json:"name"`
}
```

**CRITICAL RULES for dto.go:**
- `Input` — what the handler receives and passes to the usecase
- `Output` — what the usecase returns to the handler
- If Input needs validation, add a `Validate() error` method directly on the Input struct
- Validate is called in the HANDLER, not in the usecase
- Input/Output are the ONLY types crossing the handler↔usecase boundary
- If the usecase has no input (e.g., list all), Input can be empty struct or contain pagination/filter fields
- If the usecase returns a list, Output can contain a slice: `Items []domain.User` + `Total int`

### http_v1.go — full pattern:

```go
package create_user_uc

import (
    "your-module/pkg/httpserver"
    "github.com/gin-gonic/gin"
    "go.uber.org/zap"
)

type HTTPv1 struct {
    logger  *zap.SugaredLogger
    usecase *Usecase
}

func NewHTTPv1(log *zap.SugaredLogger, uc *Usecase) *HTTPv1 {
    return &HTTPv1{
        logger:  log,
        usecase: uc,
    }
}

// Handle is the Gin handler. The controller maps a route to this method.
//
// @Summary Create a new user
// @Tags users
// @Accept json
// @Produce json
// @Param input body Input true "User data"
// @Success 201 {object} httpserver.Response{data=Output}
// @Failure 400 {object} httpserver.Response
// @Failure 422 {object} httpserver.Response
// @Failure 500 {object} httpserver.Response
// @Router /api/v1/users [post]
func (h *HTTPv1) Handle(c *gin.Context) {
    var input Input

    if err := c.ShouldBindJSON(&input); err != nil {
        httpserver.BadRequest(c, "invalid request body", err.Error())
        return
    }

    // Validate BEFORE passing to usecase
    if err := input.Validate(); err != nil {
        httpserver.ValidationError(c, err.Error())
        return
    }

    output, err := h.usecase.Execute(c.Request.Context(), input)
    if err != nil {
        h.logger.Errorw("create user failed", "error", err)
        httpserver.InternalServerError(c, "failed to create user")
        return
    }

    httpserver.Created(c, output)
}
```

**Handler pattern for GET with path params:**

```go
func (h *HTTPv1) Handle(c *gin.Context) {
    input := Input{
        ID: c.Param("id"),
    }

    if err := input.Validate(); err != nil {
        httpserver.ValidationError(c, err.Error())
        return
    }

    output, err := h.usecase.Execute(c.Request.Context(), input)
    if err != nil {
        h.logger.Errorw("get user failed", "error", err, "id", input.ID)
        httpserver.InternalServerError(c, "failed to get user")
        return
    }

    httpserver.OK(c, output)
}
```

**Handler pattern for GET with query params (list/pagination):**

```go
func (h *HTTPv1) Handle(c *gin.Context) {
    var input Input

    if err := c.ShouldBindQuery(&input); err != nil {
        httpserver.BadRequest(c, "invalid query params", err.Error())
        return
    }

    if err := input.Validate(); err != nil {
        httpserver.ValidationError(c, err.Error())
        return
    }

    output, err := h.usecase.Execute(c.Request.Context(), input)
    if err != nil {
        h.logger.Errorw("list users failed", "error", err)
        httpserver.InternalServerError(c, "failed to list users")
        return
    }

    httpserver.OK(c, output)
}
```

**CRITICAL RULES for http_v1.go:**
- Parse request body → `c.ShouldBindJSON(&input)`
- Parse path params → `c.Param("id")`
- Parse query params → `c.ShouldBindQuery(&input)`
- Call `input.Validate()` → return 422 on error
- Call `usecase.Execute()` → return error or success
- ALWAYS use `httpserver.*` response helpers, NEVER `c.JSON()` directly
- Pass `c.Request.Context()` to the usecase, not the gin.Context
- Add Swagger annotations for every handler
- Log errors with context (input data, IDs) before returning error response

### wire.go — full pattern:

```go
package create_user_uc

import "github.com/google/wire"

var Set = wire.NewSet(
    New,       // *Usecase
    NewHTTPv1, // *HTTPv1
)
```

If the usecase has multiple handlers (e.g., HTTP + cron), include all constructors:

```go
var Set = wire.NewSet(
    New,        // *Usecase
    NewHTTPv1,  // *HTTPv1
    NewCron,    // *Cron
)
```

---

## 3. Controller

Location: `internal/controller/http_v1/controller.go`

The controller creates the router and maps routes to usecase handlers. It depends ONLY on usecase handler packages — no adapters, no business logic.

The controller has its own `config.go` with CORS settings loaded from environment variables. This follows the general rule: **if a config is only used by a specific package, put `config.go` in that package.**

### config.go:

```go
// internal/controller/http_v1/config.go
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
```

### wire.go:

```go
package http_v1

import "github.com/google/wire"

var Set = wire.NewSet(
    LoadConfig,
    Controller,
)
```

### controller.go:

```go
package http_v1

import (
    "your-module/internal/health"
    "your-module/internal/create_user_uc"
    "your-module/internal/get_user_uc"
    "your-module/internal/list_users_uc"
    "your-module/internal/update_user_uc"
    "your-module/internal/delete_user_uc"
    "github.com/gin-contrib/cors"
    "github.com/gin-gonic/gin"
    swaggerFiles "github.com/swaggo/files"
    ginSwagger "github.com/swaggo/gin-swagger"
)

func Controller(
    cfg Config,
    createUser *create_user_uc.HTTPv1,
    getUser *get_user_uc.HTTPv1,
    listUsers *list_users_uc.HTTPv1,
    updateUser *update_user_uc.HTTPv1,
    deleteUser *delete_user_uc.HTTPv1,
) *gin.Engine {
    r := gin.Default()

    r.Use(cors.New(cors.Config{
        AllowOrigins:     cfg.AllowOrigins,
        AllowMethods:     cfg.AllowMethods,
        AllowHeaders:     cfg.AllowHeaders,
        ExposeHeaders:    cfg.ExposeHeaders,
        AllowCredentials: cfg.AllowCredentials,
    }))

    r.GET("/ping", health.Handle)
    r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

    api := r.Group("/api")
    v1 := api.Group("/v1")

    // Users
    v1.POST("/users", createUser.Handle)
    v1.GET("/users/:id", getUser.Handle)
    v1.GET("/users", listUsers.Handle)
    v1.PUT("/users/:id", updateUser.Handle)
    v1.DELETE("/users/:id", deleteUser.Handle)

    return r
}
```

**CRITICAL RULES for Controller:**
- The Controller function accepts `cfg Config` as the first argument — CORS is configured from env vars, not hardcoded
- The Controller function accepts usecase handlers as arguments (Wire injects them)
- Route mapping is: `v1.METHOD("/path", handler.Handle)`
- Controller has ZERO business logic — just routing
- Controller does NOT import adapters or domain — only usecase packages and infrastructure (cors, swagger)
- Group routes logically: `/api/v1/users`, `/api/v1/orders`, etc.
- When adding a new feature, add the handler to the Controller function signature and add the route
- **All cross-cutting checks (JWT auth, role verification, rate limiting, request logging, etc.) MUST be implemented as Gin middleware and applied in the controller via `.Use()`.** The controller is ONLY responsible for routing: defining groups, attaching middleware to groups, and mapping routes to handler methods. No check logic lives in handlers or usecases — if a route needs auth, add `authMiddleware` to the group; if it needs a specific role, add `roleMiddleware("admin")`. Middleware lives in `internal/controller/http_v1/middleware/`.

---

## 4. Domain

Location: `internal/domain/`

Domain contains shared models used across usecases and adapters. This is the core of the application — the innermost layer that depends on nothing.

```go
// internal/domain/user.go
package domain

import "time"

type User struct {
    ID        string
    Email     string
    Name      string
    Password  string
    CreatedAt time.Time
    UpdatedAt time.Time
}
```

```go
// internal/domain/order.go
package domain

import "time"

type OrderStatus string

const (
    OrderStatusPending   OrderStatus = "pending"
    OrderStatusCompleted OrderStatus = "completed"
    OrderStatusCancelled OrderStatus = "cancelled"
)

type Order struct {
    ID        string
    UserID    string
    Status    OrderStatus
    Total     float64
    CreatedAt time.Time
}
```

**CRITICAL RULES for Domain:**
- Domain models are pure data structs — no methods with business logic
- **Domain structs MUST NOT have `json:` tags or any other serialization annotations.** Domain is a clean layer with pure Go structs. All serialization markup (`json:`, `xml:`, etc.) belongs in DTOs (`dto.go` in usecase packages) — that is where data crosses the boundary to the outside world.
- Adapters return domain types (map DB rows → domain structs)
- Usecases work with domain types internally; they receive Input and return Output (DTOs)
- Domain NEVER imports from adapter, usecase, controller, or pkg packages
- One file per entity: `user.go`, `order.go`, `product.go`, etc.
- Use constants for enums (status, type, role)

---

## 5. Adapter

Location: `internal/adapter/{name}/`

Each external service gets its own adapter package. The adapter wraps a `pkg/` connection and adds business methods that return domain types.

### Postgres Adapter — uses sqlc for ALL queries

The postgres adapter uses **sqlc** for all database queries. You NEVER write raw SQL in Go code — all queries live in `.sql` files, sqlc generates type-safe Go code, and the adapter calls the generated functions.

#### Step 1: Write SQL queries

Create `.sql` files in `internal/adapter/postgres/queries/` grouped by entity:

```sql
-- internal/adapter/postgres/queries/user.sql

-- name: CreateUser :one
INSERT INTO users (email, name, password)
VALUES ($1, $2, $3)
RETURNING id, email, name, created_at, updated_at;

-- name: GetUserByID :one
SELECT id, email, name, created_at, updated_at
FROM users
WHERE id = $1;

-- name: GetUserByEmail :one
SELECT id, email, name, created_at, updated_at
FROM users
WHERE email = $1;

-- name: ListUsers :many
SELECT id, email, name, created_at, updated_at
FROM users
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: CountUsers :one
SELECT count(*) FROM users;

-- name: UpdateUser :one
UPDATE users
SET name = $2, updated_at = now()
WHERE id = $1
RETURNING id, email, name, created_at, updated_at;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
```

**sqlc query annotations:**
- `-- name: QueryName :one` — returns a single row (generates `func` returning one struct)
- `-- name: QueryName :many` — returns multiple rows (generates `func` returning `[]struct`)
- `-- name: QueryName :exec` — no result rows (INSERT/UPDATE/DELETE without RETURNING)
- `-- name: QueryName :execrows` — returns affected row count
- `-- name: QueryName :execresult` — returns `pgconn.CommandTag`

#### Step 2: Generate code

```bash
make sqlc
```

This reads `sqlc.yaml` and generates type-safe Go code into `internal/adapter/postgres/generated/`:
- `models.go` — structs matching your DB tables
- `querier.go` — interface with all query methods
- `db.go` — `New(pool)` constructor for the Queries type
- `*.sql.go` — implementations for each `.sql` file

The `sqlc.yaml` config (already generated at project root):
```yaml
version: "2"
sql:
  - engine: "postgresql"
    schema: "migrations/"
    queries: "internal/adapter/postgres/queries/"
    gen:
      go:
        package: "generated"
        out: "internal/adapter/postgres/generated"
        sql_package: "pgx/v5"
        emit_json_tags: true
        emit_interface: true
        emit_exact_table_names: false
        emit_empty_slices: true
```

#### Step 3: Use generated code in the adapter

```go
// internal/adapter/postgres/adapter.go
package postgres

import (
    pgxPool "your-module/pkg/postgres"
    "your-module/internal/adapter/postgres/generated"
)

type Adapter struct {
    q *generated.Queries
}

func New(pgPool *pgxPool.Pool) *Adapter {
    return &Adapter{
        q: generated.New(pgPool),
    }
}
```

Business methods in separate files by entity — they call sqlc generated functions and map results to domain types:

```go
// internal/adapter/postgres/user.go
package postgres

import (
    "context"
    "fmt"

    "your-module/internal/adapter/postgres/generated"
    "your-module/internal/domain"
)

func (a *Adapter) CreateUser(ctx context.Context, user domain.User) (domain.User, error) {
    row, err := a.q.CreateUser(ctx, generated.CreateUserParams{
        Email:    user.Email,
        Name:     user.Name,
        Password: user.Password,
    })
    if err != nil {
        return domain.User{}, fmt.Errorf("insert user: %w", err)
    }

    return toDomainUser(row), nil
}

func (a *Adapter) GetUserByID(ctx context.Context, id string) (domain.User, error) {
    row, err := a.q.GetUserByID(ctx, id)
    if err != nil {
        return domain.User{}, fmt.Errorf("get user by id: %w", err)
    }

    return toDomainUser(row), nil
}

func (a *Adapter) GetUserByEmail(ctx context.Context, email string) (domain.User, error) {
    row, err := a.q.GetUserByEmail(ctx, email)
    if err != nil {
        return domain.User{}, fmt.Errorf("get user by email: %w", err)
    }

    return toDomainUser(row), nil
}

func (a *Adapter) ListUsers(ctx context.Context, limit, offset int) ([]domain.User, int, error) {
    total, err := a.q.CountUsers(ctx)
    if err != nil {
        return nil, 0, fmt.Errorf("count users: %w", err)
    }

    rows, err := a.q.ListUsers(ctx, generated.ListUsersParams{
        Limit:  int32(limit),
        Offset: int32(offset),
    })
    if err != nil {
        return nil, 0, fmt.Errorf("list users: %w", err)
    }

    users := make([]domain.User, 0, len(rows))
    for _, row := range rows {
        users = append(users, toDomainUser(row))
    }

    return users, int(total), nil
}

// toDomainUser maps sqlc-generated row to domain model.
// Keep mappers in the same file as the methods that use them.
func toDomainUser(row generated.User) domain.User {
    return domain.User{
        ID:        row.ID,
        Email:     row.Email,
        Name:      row.Name,
        CreatedAt: row.CreatedAt,
        UpdatedAt: row.UpdatedAt,
    }
}
```

### Non-postgres adapters (Redis, JWT, Telegram, S3, etc.)

For adapters that don't use sqlc, the pattern is the same struct + business methods, just without generated code:

```go
// internal/adapter/redis/adapter.go
package redis

import (
    pkgRedis "your-module/pkg/redis"
)

type Adapter struct {
    client *pkgRedis.Client
}

func New(client *pkgRedis.Client) *Adapter {
    return &Adapter{client: client}
}
```

### wire.go (same for all adapters):

```go
package postgres

import "github.com/google/wire"

var Set = wire.NewSet(
    New, // *Adapter
)
```

**CRITICAL RULES for Adapter:**
- `adapter.go` ONLY defines the Adapter struct and constructor `New()`
- Business methods go in separate files grouped by entity: `user.go`, `order.go`, etc.
- ALL methods are on `*Adapter` — no standalone functions
- **Postgres adapter: ALL SQL queries go through sqlc.** Never write raw SQL in Go. Write `.sql` files in `queries/`, run `make sqlc`, use `a.q.QueryName()` in adapter methods
- Adapter methods return `domain.*` types — map sqlc-generated rows to domain structs using mapper functions (e.g., `toDomainUser`)
- Adapter NEVER imports from usecase packages
- Name the adapter package after the service: `postgres`, `redis`, `telegram`, `s3`, `heleket`, `inmemory`, etc.
- The adapter's Wire Set is added to `cmd/app/wire.go` → `InitializeApp()`
- Wrap all errors with `fmt.Errorf("descriptive message: %w", err)`

---

## 6. Pkg Layer (Infrastructure)

Location: `pkg/{name}/`

Pure connection/client wrappers. Zero business logic. Zero domain imports.

Each pkg package typically has:
- Main file (e.g., `postgres.go`) — connection/client setup
- `config.go` — config struct with `LoadConfig()` via `kelseyhightower/envconfig`
- `wire.go` — Wire provider set

```go
// pkg/postgres/config.go
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
```

```go
// pkg/postgres/wire.go
package postgres

import "github.com/google/wire"

var Set = wire.NewSet(
    LoadConfig, // Config
    New,        // *Pool
)
```

**CRITICAL RULES for pkg/:**
- Pure infrastructure — wraps third-party libraries
- No business logic, no domain imports
- Config loaded via `envconfig` with `LoadConfig()` function
- Connection URLs via single env var: `DB_POSTGRES_URL`, `DB_REDIS_URL`, etc.
- Every pkg exports Wire Set

---

## 7. Wire Dependency Injection

Every package exports `var Set = wire.NewSet(...)`. All sets are composed in `cmd/app/wire.go`:

```go
//go:build wireinject

package main

import (
    "context"
    "github.com/google/wire"
    "your-module/internal/adapter/postgres"
    "your-module/internal/controller/http_v1"
    "your-module/internal/create_user_uc"
    "your-module/internal/get_user_uc"
    "your-module/internal/list_users_uc"
    "your-module/pkg/httpserver"
    "your-module/pkg/logger"
    pgPkg "your-module/pkg/postgres"
)

func InitializeApp() (*App, func(), error) {
    wire.Build(
        // Infrastructure
        logger.Set,
        httpserver.Set,

        // Database
        pgPkg.Set,

        // Adapters
        postgres.Set,

        // Usecases
        create_user_uc.Set,
        get_user_uc.Set,
        list_users_uc.Set,

        // Controller (creates router)
        http_v1.Set,

        // App
        ProvideContext,
        NewApp,
    )
    return nil, nil, nil
}

func ProvideContext() context.Context {
    return context.Background()
}
```

**When adding a new feature, add its Wire Set here in the correct section.**

After modifying wire.go, run:
```bash
make wire
```

---

## 8. HTTP Response Helpers

ALWAYS use these helpers from `pkg/httpserver/response.go`. NEVER use `c.JSON()` directly.

```go
httpserver.OK(c, data)                                   // 200 — success with data
httpserver.Created(c, data)                              // 201 — resource created
httpserver.NoContent(c)                                  // 204 — success, no body
httpserver.BadRequest(c, "message", details)             // 400 — bad input
httpserver.Unauthorized(c, "message")                    // 401 — not authenticated
httpserver.Forbidden(c, "message")                       // 403 — not authorized
httpserver.NotFound(c, "message")                        // 404 — resource not found
httpserver.Conflict(c, "message")                        // 409 — conflict (duplicate, etc.)
httpserver.ValidationError(c, details)                   // 422 — validation failed
httpserver.TooManyRequests(c, "message")                 // 429 — rate limited
httpserver.InternalServerError(c, "message")             // 500 — unexpected error
httpserver.ServiceUnavailable(c, "message")              // 503 — service down
httpserver.Error(c, statusCode, code, message, details)  // custom error
```

All responses follow the unified JSON format:

```json
{
    "success": true,
    "data": { ... }
}
```

```json
{
    "success": false,
    "error": {
        "code": "VALIDATION_ERROR",
        "message": "...",
        "details": ...
    }
}
```

---

## 9. Logging

Use `*zap.SugaredLogger` injected via Wire. Structured logging with key-value pairs:

```go
u.logger.Infow("user created", "user_id", user.ID, "email", user.Email)
u.logger.Errorw("failed to create user", "error", err, "email", input.Email)
u.logger.Debugw("processing request", "input", input)
u.logger.Warnw("deprecated endpoint called", "path", c.Request.URL.Path)
```

**Rules:**
- Always use `w` suffix methods (Infow, Errorw, Debugw, Warnw) for structured logging
- First argument is the message, then key-value pairs
- Always log errors with the `"error"` key
- Log at appropriate levels: Debug for dev details, Info for operations, Warn for concerns, Error for failures
- Include relevant context: IDs, emails, input data — helps debugging
- **Handler MUST log at entry point** — every handler logs `Infow` on invocation with the operation name and key request params. This is the anchor point for future metrics (latency, request count). Example: `h.logger.Infow("handle create user", "email", input.Email)`
- **Usecase MUST log every significant stage** — log execution start, result of each adapter call, and the final outcome. This enables tracing and future metrics. Example:
  ```go
  u.logger.Infow("execute create user", "email", input.Email)
  // ... adapter call ...
  u.logger.Infow("user created in db", "user_id", created.ID)
  ```

---

## 10. Step-by-Step Checklist for New Features

When creating a new feature (e.g., "create order"), follow this exact sequence:

1. **Domain model** — Add `internal/domain/order.go` if the entity doesn't exist yet
2. **Migrations** — Add SQL migration in `migrations/` if new tables/columns needed, run `make migrate-up`
3. **SQL queries** — Write `.sql` file in `internal/adapter/postgres/queries/order.sql` with sqlc annotations
4. **Run `make sqlc`** — generates type-safe Go code in `internal/adapter/postgres/generated/`
5. **Adapter methods** — Add methods to `internal/adapter/postgres/order.go` that call `a.q.QueryName()` and map results to domain types
6. **Usecase package** — Create `internal/create_order_uc/` with:
   - `dto.go` — Input (with Validate if needed), Output
   - `usecase.go` — Interface for dependencies, Usecase struct, New(), Execute()
   - `http_v1.go` — HTTPv1 struct, NewHTTPv1(), Handle() with Swagger annotations
   - `wire.go` — `var Set = wire.NewSet(New, NewHTTPv1)`
   - `helpers.go` — only if needed
7. **Controller** — Add the handler parameter to the Controller function signature, add route mapping
8. **Wire** — Add `create_order_uc.Set` to `cmd/app/wire.go` in the Usecases section
9. **Run `make wire`** to regenerate wire_gen.go
10. **Environment** — Add any new env vars to `.env.development`
11. **Swagger** — Add annotations to the handler, run `make swagger`

---

## ABSOLUTE RULES — NEVER BREAK THESE

1. **Usecase depends on interfaces, not concrete types.** Define the interface in usecase.go, accept concrete adapter in New().
2. **Handler calls Validate() before usecase.** Never validate inside the usecase.
3. **Only httpserver.\* response helpers.** Never c.JSON() directly.
4. **Adapter returns domain types.** Map DB rows to domain structs in the adapter, not in the usecase.
5. **Controller has zero logic.** Only route→handler mapping.
6. **Every package has wire.go.** Every wire.go exports `var Set`.
7. **One usecase = one package.** Do not put multiple usecases in one package.
8. **pkg/ is pure infrastructure.** No business logic, no domain imports.
9. **Domain imports nothing from internal/.** Domain is the innermost layer.
10. **Pass context.Context as first argument.** Always propagate context from handler to usecase to adapter.
11. **Config lives where it's used.** If an env var is only used by one package, put `config.go` with `LoadConfig()` in that package — not in a central config. Each package owns its config via `envconfig`.
12. **All postgres queries go through sqlc.** Never write raw SQL in Go code. Write `.sql` files in `internal/adapter/postgres/queries/`, run `make sqlc`, use the generated `Queries` type in the adapter.
13. **All cross-cutting checks go in middleware.** JWT auth, role verification, rate limiting, and any other pre-business-logic checks are Gin middleware in `internal/controller/http_v1/middleware/`. Controller only does routing + attaching middleware to groups. Handler only parses request → validates → calls usecase.
