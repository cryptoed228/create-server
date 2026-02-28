// Файл response.go — стандартные HTTP ответы API.
//
// Все эндпоинты используют единый формат: {"success": bool, "data": ..., "error": ...}
// Вместо c.JSON() используй хелперы: httpserver.OK(), httpserver.BadRequest() и т.д.
// Это обеспечивает единообразие ответов по всему API.
package httpserver

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Response — единый формат ответа. Фронтенд всегда проверяет поле success.
type Response struct {
	Success bool           `json:"success"`
	Data    interface{}    `json:"data,omitempty"`
	Error   *ErrorResponse `json:"error,omitempty"`
}

// ErrorResponse — описание ошибки с машиночитаемым кодом и деталями.
type ErrorResponse struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

// ======================
// SUCCESS RESPONSES (2xx)
// ======================

// OK - успешный ответ с данными (200)
func OK(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, Response{
		Success: true,
		Data:    data,
	})
}

// Created - ресурс успешно создан (201)
func Created(c *gin.Context, data interface{}) {
	c.JSON(http.StatusCreated, Response{
		Success: true,
		Data:    data,
	})
}

// NoContent - успешно, но без содержимого (204)
func NoContent(c *gin.Context) {
	c.Status(http.StatusNoContent)
}

// ======================
// CLIENT ERROR RESPONSES (4xx)
// ======================

// BadRequest - неверный запрос (400)
func BadRequest(c *gin.Context, message string, details interface{}) {
	c.JSON(http.StatusBadRequest, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    "BAD_REQUEST",
			Message: message,
			Details: details,
		},
	})
}

// Unauthorized - не авторизован (401)
func Unauthorized(c *gin.Context, message string) {
	c.JSON(http.StatusUnauthorized, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    "UNAUTHORIZED",
			Message: message,
		},
	})
}

// Forbidden - доступ запрещен (403)
func Forbidden(c *gin.Context, message string) {
	c.JSON(http.StatusForbidden, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    "FORBIDDEN",
			Message: message,
		},
	})
}

// NotFound - ресурс не найден (404)
func NotFound(c *gin.Context, message string) {
	c.JSON(http.StatusNotFound, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    "NOT_FOUND",
			Message: message,
		},
	})
}

// Conflict - конфликт данных (409)
func Conflict(c *gin.Context, message string) {
	c.JSON(http.StatusConflict, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    "CONFLICT",
			Message: message,
		},
	})
}

// ValidationError - ошибка валидации (422)
func ValidationError(c *gin.Context, details interface{}) {
	c.JSON(http.StatusUnprocessableEntity, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    "VALIDATION_ERROR",
			Message: "Validation failed",
			Details: details,
		},
	})
}

// TooManyRequests - слишком много запросов (429)
func TooManyRequests(c *gin.Context, message string) {
	c.JSON(http.StatusTooManyRequests, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    "TOO_MANY_REQUESTS",
			Message: message,
		},
	})
}

// ======================
// SERVER ERROR RESPONSES (5xx)
// ======================

// InternalServerError - внутренняя ошибка сервера (500)
func InternalServerError(c *gin.Context, message string) {
	c.JSON(http.StatusInternalServerError, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    "INTERNAL_SERVER_ERROR",
			Message: message,
		},
	})
}

// ServiceUnavailable - сервис недоступен (503)
func ServiceUnavailable(c *gin.Context, message string) {
	c.JSON(http.StatusServiceUnavailable, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    "SERVICE_UNAVAILABLE",
			Message: message,
		},
	})
}

// ======================
// CUSTOM ERROR RESPONSE
// ======================

// Error - кастомная ошибка с произвольным статус кодом
func Error(c *gin.Context, statusCode int, code string, message string, details interface{}) {
	c.JSON(statusCode, Response{
		Success: false,
		Error: &ErrorResponse{
			Code:    code,
			Message: message,
			Details: details,
		},
	})
}
