// Файл centrifuge.go — создание Centrifuge Node (встроенный real-time сервер).
//
// Node — центральный объект Centrifuge. Создаётся здесь, передаётся
// в контроллер (internal/controller/ws) для регистрации обработчиков
// и в адаптер (internal/adapter/centrifuge) для публикации сообщений.
//
// Жизненный цикл:
//   node.Run()          — вызывается в App.Run() ДО запуска HTTP сервера.
//   node.Shutdown(ctx)  — вызывается в App.shutdown() ПЕРЕД закрытием HTTP сервера.
package centrifuge

import (
	"fmt"

	cf "github.com/centrifugal/centrifuge"
)

// Node — обёртка над cf.Node. Передаётся через Wire.
type Node struct {
	*cf.Node
}

func New(cfg Config) (*Node, error) {
	node, err := cf.New(cf.Config{
		// Ping/pong: автоматический keepalive.
		// Centrifuge сам отправляет ping каждые PingInterval секунд
		// и ждёт pong PongTimeout секунд. Кастомный ping/pong не нужен.
		PingPongConfig: cf.PingPongConfig{
			PingInterval: cfg.PingInterval,
			PongTimeout:  cfg.PongTimeout,
		},
	})
	if err != nil {
		return nil, fmt.Errorf("centrifuge node: %w", err)
	}

	return &Node{Node: node}, nil
}
