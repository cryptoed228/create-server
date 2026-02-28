package health

import (
	"{{MODULE}}/pkg/httpserver"
	"github.com/gin-gonic/gin"
)

// Handle godoc
// @Summary Health check
// @Tags health
// @Produce json
// @Success 200 {object} httpserver.Response{data=gin.H}
// @Router /ping [get]
func Handle(ctx *gin.Context) {
	httpserver.OK(ctx, gin.H{
		"message": "pong",
	})
}
