package main

import (
	"errors"
	"flag"
	"fmt"
	"os"

	"github.com/charmbracelet/huh"
)

func main() {
	// Флаги для неинтерактивного режима
	moduleName := flag.String("module", "", "Go module name (e.g. github.com/user/project)")
	withPostgres := flag.Bool("postgres", false, "Include PostgreSQL")
	withRedis := flag.Bool("redis", false, "Include Redis")
	withJWT := flag.Bool("jwt", false, "Include JWT")
	withAll := flag.Bool("all", false, "Include all modules")
	flag.Parse()

	// Имя проекта — первый позиционный аргумент
	var projectName string
	if flag.NArg() > 0 {
		projectName = flag.Arg(0)
	}

	var cfg ProjectConfig
	var err error

	// Если передан --module, используем неинтерактивный режим
	if *moduleName != "" {
		if projectName == "" {
			fmt.Fprintln(os.Stderr, "Ошибка: укажите имя проекта")
			os.Exit(1)
		}
		cfg = ProjectConfig{
			ProjectName: projectName,
			ModuleName:  *moduleName,
			Postgres:    *withPostgres || *withAll,
			Redis:       *withRedis || *withAll,
			JWT:         *withJWT || *withAll,
		}
	} else {
		// Интерактивный режим
		cfg, err = runCLI(projectName)
		if err != nil {
			if errors.Is(err, huh.ErrUserAborted) {
				fmt.Println("\n  Отменено.")
				os.Exit(0)
			}
			fmt.Fprintf(os.Stderr, "Ошибка: %v\n", err)
			os.Exit(1)
		}
	}

	// Генерация проекта
	fmt.Println()
	fmt.Println("  Создаю проект...")
	if err := generate(cfg); err != nil {
		fmt.Fprintf(os.Stderr, "Ошибка генерации: %v\n", err)
		os.Exit(1)
	}

	// Итог
	fmt.Println()
	fmt.Println("  Готово! Следующие шаги:")
	fmt.Printf("    cd %s\n", cfg.ProjectName)
	if cfg.Postgres || cfg.Redis {
		fmt.Println("    make docker-db-up")
	}
	if cfg.Postgres {
		fmt.Println("    make migrate-up")
	}
	fmt.Println("    make run")
	fmt.Println()
}
