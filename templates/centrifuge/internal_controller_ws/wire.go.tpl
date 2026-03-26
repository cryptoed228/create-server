package ws

import "github.com/google/wire"

var Set = wire.NewSet(
	NewHandler, // *Handler
)
