package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	"github.com/bobmcallan/mcp-filesystem-server/filesystemserver"
	"github.com/mark3labs/mcp-go/server"
)

// LogConfig represents logging configuration
type LogConfig struct {
	Level    string `json:"level"`
	Format   string `json:"format"`
	Output   string `json:"output"`
	FilePath string `json:"file_path"`
}

// Config represents the application configuration
type Config struct {
	Logging LogConfig `json:"logging"`
}

func setupLogger() *slog.Logger {
	// Get the directory of the executable
	execPath, err := os.Executable()
	if err != nil {
		// Fallback to disabled logging if we can't determine executable path
		return slog.New(slog.NewJSONHandler(io.Discard, nil))
	}

	execDir := filepath.Dir(execPath)
	configPath := filepath.Join(execDir, "config.json")

	// Try to read config file
	var config Config
	if configData, err := os.ReadFile(configPath); err == nil {
		if err := json.Unmarshal(configData, &config); err != nil {
			// If config parsing fails, disable logging to avoid stderr interference
			return slog.New(slog.NewJSONHandler(io.Discard, nil))
		}
	} else {
		// Default configuration if config file doesn't exist
		config.Logging = LogConfig{
			Level:    "info",
			Format:   "json",
			Output:   "stderr",
			FilePath: "mcp-filesystem-server.log",
		}
	}

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
		// Create log file in the same directory as the executable
		logFilePath := filepath.Join(execDir, config.Logging.FilePath)
		
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
	// Create default log file in executable directory
	defaultLogPath := filepath.Join(execDir, "mcp-filesystem-server.log")
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

func main() {
	// Initialize structured logger with file logging support
	logger := setupLogger()
	
	// Log startup message
	logger.Info("MCP Filesystem Server starting", "version", "dev", "pid", os.Getpid())

	// Parse command line arguments
	if len(os.Args) < 2 {
		// Log usage to logger instead of stderr to avoid MCP protocol interference
		logger.Error("Invalid usage", "usage", fmt.Sprintf("%s <allowed-directory> [additional-directories...]", os.Args[0]))
		os.Exit(1)
	}

	// Validate that arguments are actual directories, not flags
	var validDirs []string
	for _, arg := range os.Args[1:] {
		if strings.HasPrefix(arg, "-") {
			logger.Error("Invalid argument - flags not supported", "arg", arg, "usage", fmt.Sprintf("%s <allowed-directory> [additional-directories...]", os.Args[0]))
			os.Exit(1)
		}
		validDirs = append(validDirs, arg)
	}

	// Create and start the server
	fss, err := filesystemserver.NewFilesystemServer(validDirs)
	if err != nil {
		logger.Error("Failed to create server", "error", err)
		os.Exit(1)
	}

	// Serve requests
	if err := server.ServeStdio(fss); err != nil {
		logger.Error("Server error", "error", err)
		os.Exit(1)
	}
}
