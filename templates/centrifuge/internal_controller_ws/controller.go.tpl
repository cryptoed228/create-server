// Файл controller.go — обработчики событий Centrifuge.
//
// Жизненный цикл WebSocket соединения:
//   1. HTTP апгрейд (http_v1.go) → заголовки в контекст
//   2. OnConnecting              → валидация, можно отклонить
//   3. OnConnect                 → клиент подключён, регистрация per-client handlers
//   4. OnSubscribe / OnPublish   → работа с каналами
//   5. OnDisconnect              → клиент отключился
//
// Все обработчики регистрируются в setupEventHandlers() при создании Handler.
// Это происходит ДО node.Run() — порядок гарантирован Wire.
package ws

import (
	"context"

	cf "github.com/centrifugal/centrifuge"
)

// setupEventHandlers регистрирует обработчики событий на Node.
func (h *Handler) setupEventHandlers() {
	h.node.OnConnecting(h.onConnecting)
	h.node.OnConnect(h.onConnect)
}

// onConnecting вызывается перед установкой соединения.
// Контекст содержит Credentials, установленные в http_v1.go (SetCredentials).
//
// Для дополнительной валидации (например, по токену из Centrifuge протокола):
//   userID, err := validateJWT(e.Token)
//   if err != nil { return cf.ConnectReply{}, cf.DisconnectInvalidToken }
func (h *Handler) onConnecting(ctx context.Context, e cf.ConnectEvent) (cf.ConnectReply, error) {
	h.logger.Debugw("Клиент подключается",
		"transport", e.Transport.Name(),
	)

	return cf.ConnectReply{}, nil
}

// onConnect вызывается после успешного установления соединения.
// Здесь регистрируются per-client обработчики.
func (h *Handler) onConnect(client *cf.Client) {
	h.logger.Infow("Клиент подключился",
		"client_id", client.ID(),
		"user_id", client.UserID(),
		"transport", client.Transport().Name(),
	)

	client.OnSubscribe(func(e cf.SubscribeEvent, cb cf.SubscribeCallback) {
		h.onSubscribe(client, e, cb)
	})

	client.OnPublish(func(e cf.PublishEvent, cb cf.PublishCallback) {
		h.onPublish(client, e, cb)
	})

	client.OnDisconnect(func(e cf.DisconnectEvent) {
		h.onDisconnect(client, e)
	})
}

// onSubscribe — авторизация подписки на канал.
//
// По умолчанию разрешает все подписки.
// Добавь проверку прав доступа:
//   if !canSubscribe(client.UserID(), e.Channel) {
//       cb(cf.SubscribeReply{}, cf.ErrorPermissionDenied)
//       return
//   }
func (h *Handler) onSubscribe(client *cf.Client, e cf.SubscribeEvent, cb cf.SubscribeCallback) {
	h.logger.Debugw("Подписка на канал",
		"client_id", client.ID(),
		"user_id", client.UserID(),
		"channel", e.Channel,
	)

	cb(cf.SubscribeReply{}, nil)
}

// onPublish — валидация публикации в канал.
//
// По умолчанию разрешает все публикации.
// Добавь валидацию данных и проверку прав:
//   if !canPublish(client.UserID(), e.Channel) {
//       cb(cf.PublishReply{}, cf.ErrorPermissionDenied)
//       return
//   }
func (h *Handler) onPublish(client *cf.Client, e cf.PublishEvent, cb cf.PublishCallback) {
	h.logger.Debugw("Публикация в канал",
		"client_id", client.ID(),
		"user_id", client.UserID(),
		"channel", e.Channel,
		"data_len", len(e.Data),
	)

	cb(cf.PublishReply{}, nil)
}

// onDisconnect — клиент отключился.
func (h *Handler) onDisconnect(client *cf.Client, e cf.DisconnectEvent) {
	h.logger.Infow("Клиент отключился",
		"client_id", client.ID(),
		"user_id", client.UserID(),
		"code", e.Code,
		"reason", e.Reason,
	)
}
