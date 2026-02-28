// Файл hash.go — утилиты для хэширования паролей (bcrypt) и работы с UUID.
package hash

import (
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// GenerateHash — хэширует строку (пароль) с помощью bcrypt.
func GenerateHash(v string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(v), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}
// CompareHash — проверяет соответствие строки и bcrypt хэша.
func CompareHash(v, hash string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(v)) == nil
}

// ParseUUID парсит строку в UUID
func ParseUUID(s string) (uuid.UUID, error) {
	return uuid.Parse(s)
}
