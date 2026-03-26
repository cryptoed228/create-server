// Файл http_v1.go — HTTP-эндпоинт для WebSocket апгрейда.
//
// Использует upgrade_conn usecase для извлечения данных из HTTP заголовков
// и формирования meta-информации для Centrifuge Credentials.
//
// Все данные из HTTP запроса (Authorization, IP, User-Agent и т.д.)
// сериализуются в JSON и передаются в Credentials.Info,
// что делает их доступными в обработчиках событий и через presence.
package ws

import (
	"net/http"

	cf "github.com/centrifugal/centrifuge"
	"go.uber.org/zap"

	pkgCentrifuge "{{MODULE}}/pkg/centrifuge"
	"{{MODULE}}/internal/upgrade_conn"
)

// Handler — HTTP обработчик WebSocket соединений.
type Handler struct {
	node      *pkgCentrifuge.Node
	logger    *zap.SugaredLogger
	upgradeUC *upgrade_conn.Usecase
	wsHandler http.Handler
}

func NewHandler(node *pkgCentrifuge.Node, logger *zap.SugaredLogger, upgradeUC *upgrade_conn.Usecase) *Handler {
	h := &Handler{
		node:      node,
		logger:    logger,
		upgradeUC: upgradeUC,
	}

	// WebSocket handler с продакшен-конфигурацией.
	h.wsHandler = cf.NewWebsocketHandler(node.Node, cf.WebsocketConfig{
		// CheckOrigin: в продакшене замени на проверку разрешённых доменов.
		// Пример:
		//   origin := r.Header.Get("Origin")
		//   return origin == "https://your-domain.com"
		CheckOrigin: func(r *http.Request) bool {
			return true
		},
	})

	// Регистрируем обработчики событий на Node.
	// Все On* вызовы должны быть до node.Run() (вызывается в App.Run).
	// Wire гарантирует: NewHandler() → NewApp() → App.Run().
	h.setupEventHandlers()

	return h
}

// ServeHTTP — точка входа для WebSocket апгрейда.
// Вызывает upgrade_conn usecase для извлечения данных из заголовков
// и установки Credentials в контексте Centrifuge.
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// Вызываем usecase для обработки заголовков.
	result, err := h.upgradeUC.Execute(ctx, r.Header)
	if err != nil {
		h.logger.Errorw("Ошибка апгрейда соединения", "error", err)
		http.Error(w, "upgrade failed", http.StatusUnauthorized)
		return
	}

	// Устанавливаем Credentials для Centrifuge из результата usecase.
	ctx = cf.SetCredentials(ctx, &cf.Credentials{
		UserID:   result.UserID,
		Info:     result.Info,
		ExpireAt: result.ExpireAt,
	})

	// Передаём обновлённый контекст в WebSocket handler.
	// Centrifuge получит этот контекст в OnConnecting и OnConnect.
	h.wsHandler.ServeHTTP(w, r.WithContext(ctx))
}
