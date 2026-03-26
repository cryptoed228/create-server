package centrifuge

import "github.com/google/wire"

var Set = wire.NewSet(
	LoadConfig, // Config
	New,        // *Node
)
