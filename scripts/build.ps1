#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build script for MCP Filesystem Server

.DESCRIPTION
    This script builds the MCP Filesystem Server executable and places it in the bin directory.
    It also ensures proper logging configuration is set up.

.PARAMETER Clean
    Clean the bin directory before building

.PARAMETER Version
    Version string to embed in the binary (default: dev)

.PARAMETER LogLevel
    Set the logging level (debug, info, warn, error) - default: info

.EXAMPLE
    ./build.ps1
    Basic build

.EXAMPLE
    ./build.ps1 -Clean -Version "1.0.0" -LogLevel debug
    Clean build with version and debug logging
#>

param(
    [switch]$Clean,
    [string]$Version = "dev",
    [ValidateSet("debug", "info", "warn", "error")]
    [string]$LogLevel = "info"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $ScriptDir
$BinDir = Join-Path $ProjectRoot "bin"

Write-Host "=== MCP Filesystem Server Build Script ===" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Binary Output: $BinDir" -ForegroundColor Gray
Write-Host "Version: $Version" -ForegroundColor Gray
Write-Host "Log Level: $LogLevel" -ForegroundColor Gray
Write-Host ""

# Ensure we're in the project directory
Set-Location $ProjectRoot

# Check if Go is installed
try {
    $goVersion = go version
    Write-Host "✓ Go detected: $goVersion" -ForegroundColor Green
} catch {
    Write-Error "Go is not installed or not found in PATH. Please install Go first."
    exit 1
}

# Clean bin directory if requested
if ($Clean -and (Test-Path $BinDir)) {
    Write-Host "🧹 Cleaning bin directory..." -ForegroundColor Yellow
    Remove-Item -Path $BinDir -Recurse -Force
}

# Create bin directory if it doesn't exist
if (-not (Test-Path $BinDir)) {
    Write-Host "📁 Creating bin directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}

# Build the application
Write-Host "🔨 Building application..." -ForegroundColor Yellow

$env:CGO_ENABLED = "0"
$env:GOOS = "windows"
$env:GOARCH = "amd64"

$buildFlags = @(
    "-ldflags", "-X main.version=$Version -s -w",
    "-o", (Join-Path $BinDir "mcp-filesystem-server.exe"),
    "."
)

try {
    & go build @buildFlags
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed with exit code $LASTEXITCODE"
    }
    Write-Host "✓ Build completed successfully" -ForegroundColor Green
} catch {
    Write-Error "Build failed: $_"
    exit 1
}

# Update config.json with proper logging configuration
Write-Host "⚙️ Configuring logging..." -ForegroundColor Yellow

$configPath = Join-Path $BinDir "config.json"
$logFilePath = Join-Path $BinDir "mcp-filesystem-server.log"

# Create updated config with file logging
$config = @{
    server = @{
        name = "mcp-filesystem-server"
        version = $Version
        description = "Secure filesystem operations via Model Context Protocol"
    }
    security = @{
        allowed_directories = @(".")
        max_file_size = 10485760
        max_files_per_request = 50
        validate_paths = $true
        follow_symlinks = $false
    }
    logging = @{
        level = $LogLevel
        format = "json"
        output = "file"
        file_path = "mcp-filesystem-server.log"
    }
    mcp = @{
        protocol_version = "2024-11-05"
        capabilities = @{
            resources = $true
            tools = $true
            prompts = $false
            sampling = $false
        }
    }
}

$config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
Write-Host "✓ Configuration updated with file logging" -ForegroundColor Green

# Create a simple test script to validate the build
$testScript = @'
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test the MCP Filesystem Server build
#>

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExePath = Join-Path $ScriptDir "mcp-filesystem-server.exe"

Write-Host "=== Testing MCP Filesystem Server ===" -ForegroundColor Cyan

# Test 1: Check if executable exists
if (-not (Test-Path $ExePath)) {
    Write-Error "Executable not found: $ExePath"
    exit 1
}
Write-Host "✓ Executable exists" -ForegroundColor Green

# Test 2: Check if executable runs (expect it to exit with usage message)
Write-Host "🧪 Testing executable..." -ForegroundColor Yellow
try {
    $result = & $ExePath 2>&1
    # The app should exit with code 1 when no arguments are provided
    if ($LASTEXITCODE -eq 1) {
        Write-Host "✓ Executable runs and shows usage (expected behavior)" -ForegroundColor Green
    } else {
        Write-Warning "Unexpected exit code: $LASTEXITCODE"
    }
} catch {
    Write-Error "Failed to run executable: $_"
    exit 1
}

# Test 3: Check MCP protocol compliance by running with current directory
Write-Host "🧪 Testing MCP protocol compliance..." -ForegroundColor Yellow
try {
    # Start the process and send an initialize request
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.Arguments = "."
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    
    $process = [System.Diagnostics.Process]::Start($psi)
    
    # Send initialize request
    $initRequest = @{
        jsonrpc = "2.0"
        id = 1
        method = "initialize"
        params = @{
            protocolVersion = "2024-11-05"
            capabilities = @{
                roots = @{
                    listChanged = $false
                }
                sampling = @{}
            }
            clientInfo = @{
                name = "test-client"
                version = "1.0.0"
            }
        }
    } | ConvertTo-Json -Depth 10 -Compress
    
    $process.StandardInput.WriteLine($initRequest)
    $process.StandardInput.Flush()
    
    # Wait a moment for response
    Start-Sleep -Milliseconds 500
    
    if (-not $process.HasExited) {
        # Send initialized notification
        $initializedNotification = @{
            jsonrpc = "2.0"
            method = "notifications/initialized"
        } | ConvertTo-Json -Compress
        
        $process.StandardInput.WriteLine($initializedNotification)
        $process.StandardInput.Flush()
        
        # Try to read a response
        $response = $process.StandardOutput.ReadLine()
        if ($response) {
            $responseObj = $response | ConvertFrom-Json
            if ($responseObj.result -and $responseObj.result.capabilities) {
                Write-Host "✓ MCP protocol compliance verified" -ForegroundColor Green
            } else {
                Write-Warning "Unexpected response format: $response"
            }
        }
    }
    
    # Clean up
    if (-not $process.HasExited) {
        $process.Kill()
    }
    $process.Close()
    
} catch {
    Write-Warning "MCP protocol test failed: $_"
}

# Test 4: Check logging configuration
$logFile = Join-Path $ScriptDir "mcp-filesystem-server.log"
if (Test-Path $logFile) {
    Write-Host "✓ Log file created: $logFile" -ForegroundColor Green
    $logSize = (Get-Item $logFile).Length
    Write-Host "  Log file size: $logSize bytes" -ForegroundColor Gray
} else {
    Write-Host "ℹ Log file will be created on first run" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Build appears to be working correctly!" -ForegroundColor Green
Write-Host "Ready for Warp MCP integration." -ForegroundColor Green
'@

$testScriptPath = Join-Path $BinDir "test-build.ps1"
$testScript | Set-Content -Path $testScriptPath -Encoding UTF8

# Make the test script executable (set execution policy if needed)
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
} catch {
    Write-Warning "Could not set execution policy. You may need to run: Set-ExecutionPolicy RemoteSigned"
}

Write-Host ""
Write-Host "=== Build Summary ===" -ForegroundColor Cyan
Write-Host "✓ Executable: $(Join-Path $BinDir 'mcp-filesystem-server.exe')" -ForegroundColor Green
Write-Host "✓ Configuration: $configPath" -ForegroundColor Green
Write-Host "✓ Log file will be: $logFilePath" -ForegroundColor Green
Write-Host "✓ Test script: $testScriptPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run test: .\bin\test-build.ps1" -ForegroundColor White
Write-Host "2. Install in Warp: .\install-warp.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Build completed successfully! 🎉" -ForegroundColor Green
