#!/usr/bin/env pwsh
# Install MCP Filesystem Server in Warp Terminal

param(
    [string]$WarpConfigPath = "",
    [string[]]$AllowedDirectories = @("C:\development"),
    [switch]$Force,
    [switch]$Help
)

if ($Help) {
    Write-Host "Warp MCP Filesystem Server Installer" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: ./install-warp.ps1 [options]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  -WarpConfigPath      Path to Warp MCP configuration file (auto-detected if not provided)"
    Write-Host "  -AllowedDirectories  Array of directories to allow access to (default: C:\development)"
    Write-Host "  -Force              Overwrite existing configuration"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  ./install-warp.ps1"
    Write-Host "  ./install-warp.ps1 -AllowedDirectories @('C:\projects', 'C:\code')"
    Write-Host "  ./install-warp.ps1 -WarpConfigPath 'C:\Users\Username\AppData\Local\Warp\mcp.json'"
    exit 0
}

Write-Host "=== Installing MCP Filesystem Server in Warp ===" -ForegroundColor Green

# Step 1: Verify binary exists
Write-Host "`nStep 1: Verifying installation..." -ForegroundColor Yellow
$binaryPath = Resolve-Path "./bin/mcp-filesystem-server.exe" -ErrorAction SilentlyContinue
if (!$binaryPath) {
    Write-Host "Error: mcp-filesystem-server.exe not found in ./bin/" -ForegroundColor Red
    Write-Host "Please run 'go build -o bin/mcp-filesystem-server.exe .' first" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✓ Binary found at: $binaryPath" -ForegroundColor Green

# Step 2: Find Warp configuration directory
Write-Host "`nStep 2: Locating Warp configuration..." -ForegroundColor Yellow
$possiblePaths = @(
    "$env:APPDATA\Warp\mcp.json",
    "$env:LOCALAPPDATA\Warp\mcp.json",
    "$env:USERPROFILE\.warp\mcp.json",
    "$env:USERPROFILE\AppData\Local\Warp\mcp.json"
)

if ($WarpConfigPath) {
    $configPath = $WarpConfigPath
} else {
    $configPath = $null
    foreach ($path in $possiblePaths) {
        $dir = Split-Path $path -Parent
        if (Test-Path $dir) {
            $configPath = $path
            break
        }
    }
    
    if (!$configPath) {
        Write-Host "Warning: Could not auto-detect Warp configuration directory" -ForegroundColor Yellow
        Write-Host "Please specify -WarpConfigPath or ensure Warp is installed" -ForegroundColor Yellow
        
        # Try to create in most likely location
        $configPath = "$env:LOCALAPPDATA\Warp\mcp.json"
        $configDir = Split-Path $configPath -Parent
        if (!(Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            Write-Host "Created directory: $configDir" -ForegroundColor Cyan
        }
    }
}

Write-Host "  Configuration will be saved to: $configPath" -ForegroundColor Green

# Step 3: Create configuration
Write-Host "`nStep 3: Creating Warp MCP configuration..." -ForegroundColor Yellow

$config = @{
    mcpServers = @{
        filesystem = @{
            command = $binaryPath.Path
            args = $AllowedDirectories
            env = @{
                LOG_LEVEL = "info"
            }
            description = "Secure filesystem operations via MCP - allows file reading, writing, directory operations, and search functionality with path validation and security controls."
        }
    }
}

# Check if config already exists
if ((Test-Path $configPath) -and !$Force) {
    Write-Host "Configuration file already exists at: $configPath" -ForegroundColor Yellow
    $existing = Get-Content $configPath | ConvertFrom-Json
    
    if ($existing.mcpServers.filesystem) {
        Write-Host "Filesystem server is already configured in Warp" -ForegroundColor Yellow
        Write-Host "Use -Force to overwrite or manually edit the file" -ForegroundColor Gray
        exit 1
    } else {
        # Merge with existing configuration
        $existing.mcpServers.filesystem = $config.mcpServers.filesystem
        $config = $existing
        Write-Host "  Merging with existing configuration..." -ForegroundColor Cyan
    }
}

# Save configuration
try {
    $configJson = $config | ConvertTo-Json -Depth 10
    $configJson | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "  ✓ Configuration saved successfully" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to save configuration: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Verify installation
Write-Host "`nStep 4: Verifying installation..." -ForegroundColor Yellow
try {
    $savedConfig = Get-Content $configPath | ConvertFrom-Json
    if ($savedConfig.mcpServers.filesystem.command -eq $binaryPath.Path) {
        Write-Host "  ✓ Configuration verified successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Configuration verification failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ✗ Failed to verify configuration: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Test server
Write-Host "`nStep 5: Testing server..." -ForegroundColor Yellow
try {
    $testOutput = & $binaryPath.Path 2>&1
    if ($testOutput -match "Usage:") {
        Write-Host "  ✓ Server responds correctly" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Server test gave unexpected output" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Server test failed: $_" -ForegroundColor Yellow
}

# Success message
Write-Host "`n=== Installation Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration saved to: $configPath" -ForegroundColor Cyan
Write-Host "Allowed directories: $($AllowedDirectories -join ', ')" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Restart Warp Terminal to load the new MCP server"
Write-Host "2. The filesystem server will be available as 'filesystem' in MCP"
Write-Host "3. You can now use MCP tools like read_file, write_file, list_directory, etc."
Write-Host ""
Write-Host "Available tools:" -ForegroundColor Gray
Write-Host "  - read_file, read_multiple_files, write_file"
Write-Host "  - list_directory, create_directory, tree"
Write-Host "  - copy_file, move_file, delete_file"
Write-Host "  - search_files, search_within_files"
Write-Host "  - get_file_info, modify_file"
Write-Host "  - list_allowed_directories"
Write-Host ""
Write-Host "🎉 MCP Filesystem Server is now installed in Warp!" -ForegroundColor Green
