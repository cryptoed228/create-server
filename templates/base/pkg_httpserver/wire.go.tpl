package httpserver

import (
	"github.com/gin-gonic/gin"
	"github.com/google/wire"
)

var Set = wire.NewSet(
	LoadConfig,
	ProvideHTTPServer,
)

func ProvideHTTPServer(cfg Config, router *gin.Engine) *Server {
	return New(&cfg, router)
}
