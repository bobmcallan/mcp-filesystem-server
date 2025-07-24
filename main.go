package main

import (
	"fmt"
	"log/slog"
	"os"

	"github.com/bobmcallan/mcp-filesystem-server/filesystemserver"
	"github.com/mark3labs/mcp-go/server"
)

func main() {
	// Initialize structured logger
	logger := slog.New(slog.NewJSONHandler(os.Stderr, nil))

	// Parse command line arguments
	if len(os.Args) < 2 {
		fmt.Fprintf(
			os.Stderr,
			"Usage: %s <allowed-directory> [additional-directories...]\n",
			os.Args[0],
		)
		os.Exit(1)
	}

	// Create and start the server
	fss, err := filesystemserver.NewFilesystemServer(os.Args[1:])
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
