// Файл adapter.go — адаптер Redis для бизнес-логики.
//
// Оборачивает pkg/redis (чистое подключение) и добавляет бизнес-методы.
// Use cases работают с этим адаптером, а не с Redis клиентом напрямую.
//
// Добавляй сюда методы для кэширования, сессий, rate limiting и т.д.
package redis

import (
	pkgRedis "{{MODULE}}/pkg/redis"
)

// Adapter — мост между use case и Redis.
type Adapter struct {
	client *pkgRedis.Client
}

func New(client *pkgRedis.Client) *Adapter {
	return &Adapter{
		client: client,
	}
}
