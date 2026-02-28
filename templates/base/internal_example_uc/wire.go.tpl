package example_uc

import "github.com/google/wire"

var Set = wire.NewSet(
	New,
	NewHTTPv1,
)
