package example_uc

import (
	"{{MODULE}}/pkg/httpserver"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

type HTTPv1 struct {
	logger  *zap.SugaredLogger
	usecase *Usecase
}

func NewHTTPv1(log *zap.SugaredLogger, uc *Usecase) *HTTPv1 {
	return &HTTPv1{
		logger:  log,
		usecase: uc,
	}
}

func (h *HTTPv1) Handle(c *gin.Context) {
	var input Input

	output, err := h.usecase.Execute(c.Request.Context(), input)
	if err != nil {
		httpserver.InternalServerError(c, "error message")
		return
	}

	httpserver.OK(c, output)
}
