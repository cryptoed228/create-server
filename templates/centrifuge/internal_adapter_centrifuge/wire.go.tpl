package centrifuge

import "github.com/google/wire"

var Set = wire.NewSet(
	New, // *Adapter
)
