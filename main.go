// -----------------------------------------------------------------------
// File Created: Thursday, 24th July 2025 10:20:10 pm
// Author: Bob McAllan (bobmcallan@gmail.com)
//
// Last Modified: Thursday, 24th July 2025 10:28:35 pm
// Modified By: Bob McAllan (bobmcallan@gmail.com)
// -----------------------------------------------------------------------

package main

import (
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/BurntSushi/toml"
	"github.com/bobmcallan/mcp-filesystem-server/filesystemserver"
	"github.com/common-nighthawk/go-figure"
	"github.com/mark3labs/mcp-go/server"
)

// LogConfig represents logging configuration
type LogConfig struct {
	Level    string `toml:"level"`
	Format   string `toml:"format"`
	Output   string `toml:"output"`
	FilePath string `toml:"file_path"`
}

// DirectoriesConfig represents directories configuration
type DirectoriesConfig struct {
	Allowed []string `toml:"allowed"`
}

// Config represents the application configuration
type Config struct {
	Directories DirectoriesConfig `toml:"directories"`
	Logging     LogConfig         `toml:"logging"`
}

func loadConfig() (Config, error) {
	// Get the directory of the executable
	execPath, err := os.Executable()
	if err != nil {
		return Config{}, fmt.Errorf("failed to get executable path: %w", err)
	}

	execDir := filepath.Dir(execPath)
	configPath := filepath.Join(execDir, "config.toml")

	// Try to read and parse TOML config file
	var config Config
	if _, err := toml.DecodeFile(configPath, &config); err != nil {
		// Return default configuration if config file doesn't exist or can't be parsed
		config = Config{
			Directories: DirectoriesConfig{
				Allowed: []string{"."},
			},
			Logging: LogConfig{
				Level:    "info",
				Format:   "json",
				Output:   "file",
				FilePath: "mcp-filesystem-server.log", // This will be replaced with executable name
			},
		}
	}

	return config, nil
}

func setupLogger(config Config) *slog.Logger {
	// Get the directory of the executable
	execPath, err := os.Executable()
	if err != nil {
		// Fallback to disabled logging if we can't determine executable path
		return slog.New(slog.NewJSONHandler(io.Discard, nil))
	}
	execDir := filepath.Dir(execPath)
	execName := filepath.Base(execPath)
	// Remove .exe extension if present and add .log
	logFileName := execName
	if filepath.Ext(logFileName) == ".exe" {
		logFileName = logFileName[:len(logFileName)-4]
	}
	logFileName += ".log"

	// Parse log level
	var logLevel slog.Level
	switch config.Logging.Level {
	case "debug":
		logLevel = slog.LevelDebug
	case "info":
		logLevel = slog.LevelInfo
	case "warn":
		logLevel = slog.LevelWarn
	case "error":
		logLevel = slog.LevelError
	default:
		logLevel = slog.LevelInfo
	}

	handlerOpts := &slog.HandlerOptions{Level: logLevel}

	// If configured for file logging, use file output
	if config.Logging.Output == "file" && config.Logging.FilePath != "" {
		// Use configured file path, but if it matches default, use executable name
		logPath := config.Logging.FilePath
		if logPath == "mcp-filesystem-server.log" {
			logPath = logFileName
		}
		logFilePath := filepath.Join(execDir, logPath)

		// Open log file for writing (create if not exists, append if exists)
		logFile, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			// Don't write to stderr as it interferes with MCP protocol
			// Fallback to a temp file or disable logging
			return slog.New(slog.NewJSONHandler(io.Discard, handlerOpts))
		}

		// Use only file for logging to avoid stderr interference with MCP protocol
		// Create handler based on format
		if config.Logging.Format == "text" {
			return slog.New(slog.NewTextHandler(logFile, handlerOpts))
		} else {
			return slog.New(slog.NewJSONHandler(logFile, handlerOpts))
		}
	}

	// Default to file logging to avoid stderr interference with MCP protocol
	// Create default log file in executable directory using executable name
	defaultLogPath := filepath.Join(execDir, logFileName)
	logFile, err := os.OpenFile(defaultLogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		// If we can't create log file, disable logging entirely to avoid protocol interference
		return slog.New(slog.NewJSONHandler(io.Discard, handlerOpts))
	}

	if config.Logging.Format == "text" {
		return slog.New(slog.NewTextHandler(logFile, handlerOpts))
	} else {
		return slog.New(slog.NewJSONHandler(logFile, handlerOpts))
	}
}

func showSplashScreen(config Config) {
	// ANSI color codes for non-figure text
	const (
		ColorReset    = "\033[0m"
		ColorGreen    = "\033[32m"
		ColorDarkBlue = "\033[34m"
	)

	// Create colored ASCII art banner using go-figure with built-in color support
	appName := "FILESYSTEM"
	appNameFigure := figure.NewColorFigure(appName, "banner", "blue", true)
	appSeparator := "===================================================================================================="

	fmt.Println(ColorDarkBlue + appSeparator + ColorReset)
	fmt.Println(ColorDarkBlue + appSeparator + ColorReset)
	fmt.Println()
	appNameFigure.Print()
	fmt.Println(ColorDarkBlue + appSeparator + ColorReset)
	fmt.Println(ColorDarkBlue + appSeparator + ColorReset)
	fmt.Println()
	fmt.Printf(ColorGreen + "Version: 1.0.0.07241752\n\n" + ColorReset)
	fmt.Println(ColorGreen + "» Filesystem MCP Server «" + ColorReset)
	fmt.Println()
	fmt.Println(ColorGreen + "Configuration:" + ColorReset)
	fmt.Printf(ColorGreen+"» Log Level:          %s\n"+ColorReset, config.Logging.Level)
	fmt.Printf(ColorGreen+"» Log Format:         %s\n"+ColorReset, config.Logging.Format)
	fmt.Printf(ColorGreen+"» Log Output:         %s\n"+ColorReset, config.Logging.Output)
	fmt.Printf(ColorGreen+"» Allowed Dirs:       %d configured\n"+ColorReset, len(config.Directories.Allowed))
	fmt.Println()
	fmt.Println(ColorGreen + "[ INITIALIZING FILESYSTEM SERVER... ]" + ColorReset)

	// Add some retro loading animation
	loadingChars := []string{"▰", "▱"}
	fmt.Print("\n Loading")
	for i := 0; i < 10; i++ {
		fmt.Printf(" %s", loadingChars[i%2])
		time.Sleep(100 * time.Millisecond)
	}
	fmt.Println("\n\n ✓ System Ready! MCP Filesystem Server Online")
	fmt.Println(strings.Repeat("═", 79))
}

func main() {
	// Load configuration from config.toml
	config, err := loadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	// Show splash screen
	showSplashScreen(config)

	// Initialize structured logger with file logging support
	logger := setupLogger(config)

	// Log startup message
	logger.Info("Starting application", "name", "Filesystem Server MCP", "version", "1.0.0.07241752", "pid", os.Getpid())

	// Validate that we have allowed directories from config
	if len(config.Directories.Allowed) == 0 {
		logger.Error("No allowed directories configured in config.toml")
		os.Exit(1)
	}

	// Log configuration loaded
	logger.Info("Configuration loaded", "directories", config.Directories.Allowed)

	// Create and start the server
	fss, err := filesystemserver.NewFilesystemServer(config.Directories.Allowed)
	if err != nil {
		logger.Error("Failed to create server", "error", err)
		os.Exit(1)
	}

	// Log server start
	logger.Info("Starting MCP server", "name", "Filesystem Server MCP", "version", "1.0.0.07241752")

	// Serve requests
	if err := server.ServeStdio(fss); err != nil {
		logger.Error("Server error", "error", err)
		os.Exit(1)
	}
}
