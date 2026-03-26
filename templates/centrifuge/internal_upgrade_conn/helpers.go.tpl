package upgrade_conn

import "net/http"

// extractClientIP извлекает реальный IP клиента из заголовков.
// Приоритет: X-Forwarded-For → X-Real-IP → RemoteAddr не доступен на уровне заголовков.
func extractClientIP(headers http.Header) string {
	if ip := headers.Get("X-Forwarded-For"); ip != "" {
		return ip
	}
	if ip := headers.Get("X-Real-IP"); ip != "" {
		return ip
	}
	return ""
}
