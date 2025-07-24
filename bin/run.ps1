#!/usr/bin/env pwsh
# Run script for MCP Filesystem Server

param(
    [string[]]$AllowedDirectories = @("."),
    [string]$LogLevel = "info",
    [switch]$Verbose,
    [switch]$Help
)

if ($Help) {
    Write-Host "MCP Filesystem Server Runner" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: ./run.ps1 [options]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  -AllowedDirectories  Array of directories to allow access to (default: current directory)"
    Write-Host "  -LogLevel           Logging level: debug, info, warn, error (default: info)"
    Write-Host "  -Verbose            Enable verbose output"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  ./run.ps1"
    Write-Host "  ./run.ps1 -AllowedDirectories @('C:\\dev', 'C:\\projects')"
    Write-Host "  ./run.ps1 -LogLevel debug -Verbose"
    exit 0
}

Write-Host "=== Starting MCP Filesystem Server ===" -ForegroundColor Green

# Check if binary exists
if (-not (Test-Path "./mcp-filesystem-server.exe")) {
    Write-Host "Error: mcp-filesystem-server.exe not found in current directory" -ForegroundColor Red
    Write-Host "Run 'go build -o bin/mcp-filesystem-server.exe .' from the project root first" -ForegroundColor Yellow
    exit 1
}

# Load configuration
$config = $null
if (Test-Path "./config.json") {
    try {
        $config = Get-Content "./config.json" | ConvertFrom-Json
        Write-Host "Configuration loaded from config.json" -ForegroundColor Cyan
    } catch {
        Write-Host "Warning: Failed to load config.json: $_" -ForegroundColor Yellow
    }
}

# Set environment variables
$env:LOG_LEVEL = $LogLevel
if ($config -and $config.security.max_file_size) {
    $env:MAX_FILE_SIZE = $config.security.max_file_size
}

# Display startup information
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Allowed Directories: $($AllowedDirectories -join ', ')" -ForegroundColor White
Write-Host "  Log Level: $LogLevel" -ForegroundColor White
Write-Host "  Working Directory: $(Get-Location)" -ForegroundColor White

if ($Verbose) {
    Write-Host "  Binary Path: $(Resolve-Path './mcp-filesystem-server.exe')" -ForegroundColor White
    Write-Host "  Environment Variables:" -ForegroundColor White
    Write-Host "    LOG_LEVEL = $env:LOG_LEVEL" -ForegroundColor White
    if ($env:MAX_FILE_SIZE) {
        Write-Host "    MAX_FILE_SIZE = $env:MAX_FILE_SIZE" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Starting server..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Start the server
try {
    & "./mcp-filesystem-server.exe" @AllowedDirectories
} catch {
    Write-Host "Error starting server: $_" -ForegroundColor Red
    exit 1
}
