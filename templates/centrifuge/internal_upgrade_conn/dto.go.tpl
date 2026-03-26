package upgrade_conn

// UpgradeResult — результат обработки апгрейда соединения.
type UpgradeResult struct {
	// UserID — идентификатор пользователя. Пустая строка = анонимный.
	UserID string

	// Info — JSON meta-данные, передаются в Centrifuge Credentials.Info.
	// Доступны в обработчиках (OnConnecting, OnConnect) и через presence.
	Info []byte

	// ExpireAt — unix timestamp истечения соединения.
	// 0 = соединение не истекает.
	ExpireAt int64
}

// ConnMeta — данные из HTTP заголовков, сериализуются в Info.
type ConnMeta struct {
	// Authorization — значение заголовка Authorization (JWT/Bearer/API key).
	Authorization string `json:"authorization,omitempty"`

	// ClientIP — реальный IP клиента (учитывает X-Forwarded-For).
	ClientIP string `json:"client_ip"`

	// UserAgent — User-Agent клиента.
	UserAgent string `json:"user_agent,omitempty"`

	// RequestID — ID запроса для трейсинга (X-Request-ID).
	RequestID string `json:"request_id,omitempty"`

	// Origin — Origin заголовок.
	Origin string `json:"origin,omitempty"`
}
