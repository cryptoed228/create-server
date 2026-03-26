// Файл adapter.go — адаптер Centrifuge для бизнес-логики.
//
// Оборачивает pkg/centrifuge (Node) и предоставляет методы
// для публикации сообщений из use case.
//
// Добавляй сюда методы для серверной публикации, подписки пользователей
// на каналы и т.д.
package centrifuge

import (
	pkgCentrifuge "{{MODULE}}/pkg/centrifuge"
)

// Adapter — мост между use case и Centrifuge Node.
type Adapter struct {
	node *pkgCentrifuge.Node
}

func New(node *pkgCentrifuge.Node) *Adapter {
	return &Adapter{
		node: node,
	}
}

// Publish отправляет сообщение в канал (серверная публикация).
// Ошибку логируй на уровне use case.
func (a *Adapter) Publish(channel string, data []byte) error {
	_, err := a.node.Publish(channel, data)
	return err
}
