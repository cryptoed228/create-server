You are working on a Go backend project that follows a strict vertical-slice clean architecture. When implementing any feature, follow EVERY rule below exactly. Do not deviate.

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
    "{{MODULE}}/internal/adapter/postgres"
    "{{MODULE}}/internal/domain"
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

type Usecase struct {
    logger   *zap.SugaredLogger
    postgres Postgres
    redis    Redis
}

func New(log *zap.SugaredLogger, pg *postgres.Adapter, rd *redis.Adapter) *Usecase {
    return &Usecase{
        logger:   log,
        postgres: pg,
        redis:    rd,
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

### http_v1.go — full pattern:

```go
package create_user_uc

import (
    "{{MODULE}}/pkg/httpserver"
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

**CRITICAL RULES for http_v1.go:**
- Parse request body / query params → fill Input
- Call `input.Validate()` → return 400/422 on error
- Call `usecase.Execute()` → return error or success
- ALWAYS use `httpserver.*` response helpers, never `c.JSON()` directly
- Pass `c.Request.Context()` to the usecase, not `c` itself
- Add Swagger annotations for every handler

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

```go
package http_v1

import (
    "{{MODULE}}/internal/health"
    "{{MODULE}}/internal/create_user_uc"
    "{{MODULE}}/internal/get_user_uc"
    "{{MODULE}}/internal/list_users_uc"
    "github.com/gin-contrib/cors"
    "github.com/gin-gonic/gin"
    swaggerFiles "github.com/swaggo/files"
    ginSwagger "github.com/swaggo/gin-swagger"
)

func Controller(
    createUser *create_user_uc.HTTPv1,
    getUser *get_user_uc.HTTPv1,
    listUsers *list_users_uc.HTTPv1,
) *gin.Engine {
    r := gin.Default()

    r.Use(cors.New(cors.Config{
        AllowOrigins:     []string{"*"},
        AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
        AllowHeaders:     []string{"Content-Type", "Authorization"},
        ExposeHeaders:    []string{"Content-Length"},
        AllowCredentials: true,
    }))

    r.GET("/ping", health.Handle)
    r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

    api := r.Group("/api")
    v1 := api.Group("/v1")

    // Users
    v1.POST("/users", createUser.Handle)
    v1.GET("/users/:id", getUser.Handle)
    v1.GET("/users", listUsers.Handle)

    return r
}
```

**CRITICAL RULES for Controller:**
- The Controller function accepts usecase handlers as arguments (Wire injects them)
- Route mapping is: `v1.METHOD("/path", handler.Handle)`
- Controller has ZERO business logic — just routing
- Controller does NOT import adapters or domain — only usecase packages and infrastructure (cors, swagger)
- Group routes logically: `/api/v1/users`, `/api/v1/orders`, etc.

---

## 4. Domain

Location: `internal/domain/`

Domain contains shared models used across usecases and adapters.

```go
// internal/domain/user.go
package domain

import "time"

type User struct {
    ID        string    `json:"id"`
    Email     string    `json:"email"`
    Name      string    `json:"name"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}
```

**CRITICAL RULES for Domain:**
- Domain models are pure data structs — no methods with business logic
- Adapters return domain types (map DB rows → domain structs)
- Usecases accept and return domain types (or their own Input/Output DTOs)
- Domain NEVER imports from adapter, usecase, or controller packages
- One file per entity: `user.go`, `order.go`, `product.go`, etc.

---

## 5. Adapter

Location: `internal/adapter/{name}/`

Each external service gets its own adapter package.

### adapter.go:

```go
// internal/adapter/postgres/adapter.go
package postgres

import (
    pgxPool "{{MODULE}}/pkg/postgres"
)

type Adapter struct {
    pool *pgxPool.Pool
}

func New(pgPool *pgxPool.Pool) *Adapter {
    return &Adapter{
        pool: pgPool,
    }
}
```

### Business methods in separate files:

```go
// internal/adapter/postgres/user.go
package postgres

import (
    "context"
    "fmt"

    "{{MODULE}}/internal/domain"
)

func (a *Adapter) CreateUser(ctx context.Context, user domain.User) (domain.User, error) {
    query := `INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id, email, name, created_at, updated_at`

    var result domain.User
    err := a.pool.QueryRow(ctx, query, user.Email, user.Name).Scan(
        &result.ID, &result.Email, &result.Name, &result.CreatedAt, &result.UpdatedAt,
    )
    if err != nil {
        return domain.User{}, fmt.Errorf("insert user: %w", err)
    }

    return result, nil
}

func (a *Adapter) GetUserByEmail(ctx context.Context, email string) (domain.User, error) {
    query := `SELECT id, email, name, created_at, updated_at FROM users WHERE email = $1`

    var user domain.User
    err := a.pool.QueryRow(ctx, query, email).Scan(
        &user.ID, &user.Email, &user.Name, &user.CreatedAt, &user.UpdatedAt,
    )
    if err != nil {
        return domain.User{}, fmt.Errorf("get user by email: %w", err)
    }

    return user, nil
}
```

### wire.go:

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
- Adapter methods return `domain.*` types — map DB/external data to domain models
- Adapter NEVER imports from usecase packages
- Name the adapter package after the service: `postgres`, `redis`, `telegram`, `s3`, `heleket`, etc.
- The adapter's Wire Set is added to `cmd/app/wire.go` → `InitializeApp()`

---

## 6. Pkg Layer (Infrastructure)

Location: `pkg/{name}/`

Pure connection/client wrappers. Zero business logic.

Each pkg package has:
- Main file (e.g., `postgres.go`) — connection setup
- `config.go` — config struct with `LoadConfig()` via envconfig
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

---

## 7. Wire Dependency Injection

Every package exports `var Set = wire.NewSet(...)`. All sets are composed in `cmd/app/wire.go`:

```go
//go:build wireinject

package main

import (
    "context"
    "github.com/google/wire"
    "{{MODULE}}/internal/adapter/postgres"
    "{{MODULE}}/internal/controller/http_v1"
    "{{MODULE}}/internal/create_user_uc"
    "{{MODULE}}/pkg/httpserver"
    "{{MODULE}}/pkg/logger"
    pgPkg "{{MODULE}}/pkg/postgres"
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

All responses follow the unified format:
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
- Log at appropriate levels: Debug for dev, Info for operations, Warn for concerns, Error for failures

---

## 10. Step-by-Step Checklist for New Features

When creating a new feature (e.g., "create order"), follow this exact sequence:

1. **Domain model** — Add `internal/domain/order.go` if the entity doesn't exist yet
2. **Adapter methods** — Add methods to the relevant adapter (e.g., `internal/adapter/postgres/order.go`) that return domain types
3. **Usecase package** — Create `internal/create_order_uc/` with:
   - `dto.go` — Input (with Validate), Output
   - `usecase.go` — Interface for dependencies, Usecase struct, New(), Execute()
   - `http_v1.go` — HTTPv1 struct, NewHTTPv1(), Handle()
   - `wire.go` — `var Set = wire.NewSet(New, NewHTTPv1)`
   - `helpers.go` — if needed
4. **Controller** — Add the handler parameter to the Controller function signature, add route mapping
5. **Wire** — Add `create_order_uc.Set` to `cmd/app/wire.go` in the Usecases section
6. **Update Controller Wire** — If the Controller function signature changed, Wire will pick it up automatically
7. **Run `make wire`** to regenerate wire_gen.go
8. **Environment** — Add any new env vars to `.env.development`
9. **Migrations** — Add SQL migration in `migrations/` if needed
10. **Swagger** — Add annotations to the handler, run `make swagger`

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
