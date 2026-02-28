// Файл wire.go — Wire Set для Redis адаптера.
package redis

import "github.com/google/wire"

var Set = wire.NewSet(
	New, // *Adapter — адаптер с бизнес-методами для кэша
)
