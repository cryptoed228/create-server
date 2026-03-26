// Файл usecase.go — бизнес-логика апгрейда WebSocket соединения.
//
// Извлекает данные из HTTP заголовков при подключении к WebSocket
// и формирует meta-информацию для Centrifuge Credentials.
//
// Вызывается из ws handler (internal/controller/ws) перед SetCredentials.
package upgrade_conn

import (
	"context"
	"encoding/json"
	"net/http"

	"go.uber.org/zap"
)

type Usecase struct {
	logger *zap.SugaredLogger
}

func New(log *zap.SugaredLogger) *Usecase {
	return &Usecase{
		logger: log,
	}
}

// Execute извлекает данные из HTTP заголовков и формирует meta для Centrifuge.
//
// Возвращает UpgradeResult с:
//   - UserID: идентификатор пользователя (пустая строка = анонимный)
//   - Info:   JSON meta-данные, доступные в обработчиках и через presence
//   - ExpireAt: unix timestamp истечения соединения (0 = не истекает)
//
// Для аутентификации: добавь валидацию токена из Authorization заголовка,
// получи userID и верни его в UpgradeResult.UserID.
func (u *Usecase) Execute(ctx context.Context, headers http.Header) (UpgradeResult, error) {
	meta := ConnMeta{
		Authorization: headers.Get("Authorization"),
		ClientIP:      extractClientIP(headers),
		UserAgent:     headers.Get("User-Agent"),
		RequestID:     headers.Get("X-Request-ID"),
		Origin:        headers.Get("Origin"),
	}

	// === Аутентификация ===
	// Раскомментируй и реализуй валидацию токена:
	//
	//   userID, err := validateToken(meta.Authorization)
	//   if err != nil {
	//       return UpgradeResult{}, fmt.Errorf("невалидный токен: %w", err)
	//   }
	userID := ""

	info, err := json.Marshal(meta)
	if err != nil {
		u.logger.Errorw("Ошибка сериализации meta", "error", err)
		return UpgradeResult{}, err
	}

	u.logger.Debugw("Апгрейд соединения",
		"user_id", userID,
		"client_ip", meta.ClientIP,
		"user_agent", meta.UserAgent,
	)

	return UpgradeResult{
		UserID:   userID,
		Info:     info,
		ExpireAt: 0,
	}, nil
}
