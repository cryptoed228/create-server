// Файл logger.go — глобальный логгер на базе Zap с ротацией файлов.
//
// Инициализируется первым (до Wire) в main.go через Init().
// Два выхода: консоль (с цветами) + файл (без цветов, с ротацией через lumberjack).
// В development: debug-уровень в консоль, info в файл.
// В production: info-уровень для обоих.
//
// Использование в коде: logger.Sugar.Infow("сообщение", "key", value)
// Через Wire: logger.New() возвращает *zap.SugaredLogger для DI.
package logger

import (
	"os"
	"time"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"gopkg.in/natefinch/lumberjack.v2"
)

// Logger и Sugar — глобальные переменные. Init() должен быть вызван до их использования.
var Logger *zap.Logger
var Sugar *zap.SugaredLogger

func Init(env string) error {
	// Ротация логов: максимум 50MB на файл, 5 бэкапов, хранение 30 дней
	fileSyncer := zapcore.AddSync(&lumberjack.Logger{
		Filename:   "logs/app.log",
		MaxSize:    50,   // MB
		MaxBackups: 5,
		MaxAge:     30,   // days
		Compress:   true,
	})

	// Кастомный формат времени (читаемый)
	customTimeEncoder := func(t time.Time, enc zapcore.PrimitiveArrayEncoder) {
		enc.AppendString(t.Format("2006-01-02 15:04:05"))
	}

	// Console Encoder для терминала (с цветами)
	consoleEncoderConfig := zap.NewDevelopmentEncoderConfig()
	consoleEncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	consoleEncoderConfig.EncodeTime = customTimeEncoder
	consoleEncoderConfig.EncodeCaller = zapcore.ShortCallerEncoder
	consoleEncoder := zapcore.NewConsoleEncoder(consoleEncoderConfig)

	// File Encoder - читаемый формат (НЕ JSON!)
	fileEncoderConfig := zap.NewDevelopmentEncoderConfig()
	fileEncoderConfig.EncodeLevel = zapcore.CapitalLevelEncoder  // БЕЗ цветов для файла
	fileEncoderConfig.EncodeTime = customTimeEncoder
	fileEncoderConfig.EncodeCaller = zapcore.ShortCallerEncoder
	fileEncoder := zapcore.NewConsoleEncoder(fileEncoderConfig)

	// Уровни логирования в зависимости от окружения
	consoleLevel := zapcore.DebugLevel
	fileLevel := zapcore.InfoLevel

	if env == "production" {
		consoleLevel = zapcore.InfoLevel
		fileLevel = zapcore.InfoLevel
	}

	// MultiCore: stdout + file
	core := zapcore.NewTee(
		zapcore.NewCore(consoleEncoder, zapcore.AddSync(os.Stdout), consoleLevel),
		zapcore.NewCore(fileEncoder, fileSyncer, fileLevel),
	)

	// Создаём логгер
	Logger = zap.New(
		core,
		zap.AddCaller(),
		zap.AddStacktrace(zapcore.ErrorLevel),
	)
	Sugar = Logger.Sugar()

	return nil
}

// New — провайдер для Wire. Возвращает глобальный Sugar logger.
// Требует предварительного вызова Init() в main.go.
func New() *zap.SugaredLogger {
	if Sugar == nil {
		panic("logger not initialized, call Init() first")
	}
	return Sugar
}

// WithFields создает логгер с предзаполненными полями
func WithFields(fields ...interface{}) *zap.SugaredLogger {
	if Sugar == nil {
		panic("logger not initialized, call Init() first")
	}
	return Sugar.With(fields...)
}
