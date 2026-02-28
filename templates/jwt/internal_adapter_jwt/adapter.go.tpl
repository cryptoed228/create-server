// Файл adapter.go — адаптер JWT для бизнес-логики.
//
// Хранит конфигурацию (секреты, TTL) и вызывает чистые функции из pkg/jwt.
// Use cases работают с этим адаптером для генерации и валидации токенов.
//
// Добавь в Config поля JWT_SECRET, ACCESS_TTL, REFRESH_TTL
// и реализуй методы GenerateAccessToken(), ValidateToken() и т.д.
package jwt

// Adapter — мост между use case и JWT утилитами (pkg/jwt).
type Adapter struct {
	cfg Config
}

func New(cfg Config) *Adapter {
	return &Adapter{
		cfg: cfg,
	}
}
