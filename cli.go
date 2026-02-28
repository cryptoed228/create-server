package main

import (
	"fmt"
	"strings"

	"github.com/manifoldco/promptui"
)

// ProjectConfig — параметры для генерации проекта
type ProjectConfig struct {
	ProjectName string
	ModuleName  string
	Postgres    bool
	Redis       bool
	JWT         bool
}

// runCLI — интерактивный ввод параметров проекта
func runCLI(projectName string) (ProjectConfig, error) {
	cfg := ProjectConfig{}

	// 1. Имя проекта
	if projectName == "" {
		prompt := promptui.Prompt{
			Label:   "Имя проекта",
			Default: "my-server",
		}
		result, err := prompt.Run()
		if err != nil {
			return cfg, err
		}
		cfg.ProjectName = result
	} else {
		cfg.ProjectName = projectName
		fmt.Printf("  Проект: %s\n", projectName)
	}

	// 2. Имя Go модуля
	modulePrompt := promptui.Prompt{
		Label:   "Go модуль (github.com/user/project)",
		Default: "github.com/user/" + cfg.ProjectName,
	}
	moduleName, err := modulePrompt.Run()
	if err != nil {
		return cfg, err
	}
	cfg.ModuleName = moduleName

	// 3. Выбор модулей
	modules, err := selectModules()
	if err != nil {
		return cfg, err
	}
	for _, m := range modules {
		switch m {
		case "PostgreSQL":
			cfg.Postgres = true
		case "Redis":
			cfg.Redis = true
		case "JWT":
			cfg.JWT = true
		}
	}

	return cfg, nil
}

// moduleOption — элемент списка модулей
type moduleOption struct {
	Name     string
	Desc     string
	Selected bool
}

// selectModules — интерактивный мультивыбор модулей
func selectModules() ([]string, error) {
	options := []moduleOption{
		{Name: "PostgreSQL", Desc: "БД + SQLC + миграции + Docker", Selected: true},
		{Name: "Redis", Desc: "Кэш + Docker + адаптер", Selected: true},
		{Name: "JWT", Desc: "Авторизация + генерация токенов", Selected: false},
	}

	fmt.Println()
	fmt.Println("  Выберите модули (Enter — переключить, 'd' — готово):")
	fmt.Println()

	cursor := 0
	for {
		// Отрисовка списка
		for i, opt := range options {
			check := "  "
			if opt.Selected {
				check = "✓ "
			}
			arrow := "  "
			if i == cursor {
				arrow = "> "
			}
			fmt.Printf("  %s%s%s — %s\n", arrow, check, opt.Name, opt.Desc)
		}

		// Чтение ввода
		var input string
		fmt.Scanln(&input)
		input = strings.TrimSpace(strings.ToLower(input))

		// Очистка строк (перемещение курсора вверх)
		for range options {
			fmt.Print("\033[A\033[2K")
		}

		switch input {
		case "d", "done", "":
			if input == "" {
				// Enter — переключить текущий
				options[cursor].Selected = !options[cursor].Selected
			} else {
				// "d" — завершить выбор
				var selected []string
				for _, opt := range options {
					if opt.Selected {
						selected = append(selected, opt.Name)
					}
				}
				// Показать итог
				for _, opt := range options {
					check := "  "
					if opt.Selected {
						check = "✓ "
					}
					fmt.Printf("  %s%s — %s\n", check, opt.Name, opt.Desc)
				}
				return selected, nil
			}
		case "j", "2": // вниз
			if cursor < len(options)-1 {
				cursor++
			}
		case "k", "1": // вверх
			if cursor > 0 {
				cursor--
			}
		default:
			// Попробуем как номер
			for i, opt := range options {
				if strings.EqualFold(input, opt.Name) || input == fmt.Sprintf("%d", i+1) {
					options[i].Selected = !options[i].Selected
				}
			}
		}
	}
}
