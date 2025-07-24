# -----------------------------------------------------------------------
# File Created: Thursday, 24th July 2025 8:00:00 am
# Author: Claude AI (claude@anthropic.com)
# 
# Last Modified: Thursday, 24th July 2025 8:00:00 am
# Modified By: Claude AI (claude@anthropic.com)
# 
# Copyright - 2025 MCP Project
# -----------------------------------------------------------------------

param (
    [switch]$UpdatePackages
)

<#
.SYNOPSIS
    Build script for Custos MCP Filesystem Server

.DESCRIPTION
    This script builds the Custos MCP Filesystem Server application with secure filesystem capabilities.

.PARAMETER UpdatePackages
    Update all Go packages to their latest versions before building

.EXAMPLE
    .\build.ps1
    Build the application with default settings

.EXAMPLE
    .\build.ps1 -UpdatePackages
    Update all packages to latest versions and then build
#>

Push-Location (Split-Path $MyInvocation.MyCommand.Path)

try {
    Write-Host "Building Custos MCP Filesystem Server" -ForegroundColor Cyan

    $path = Join-Path -Path $PSScriptRoot -ChildPath 'bin'

    if (-not ($path | Test-Path)) {
        New-Item $path -force -itemtype directory
    }

    # Create logs directory (matching application expectation)
    $logsPath = Join-Path -Path $path -ChildPath 'logs'
    if (-not (Test-Path $logsPath)) {
        New-Item $logsPath -Force -ItemType Directory
        Write-Host "Created bin/logs directory"
    }

    # Generate version with datetime suffix
    $baseVersion = "1.0.0"
    $datetime = Get-Date -Format "MMddHHmm"
    $fullVersion = "$baseVersion.$datetime"
    
    # Handle bin/config.toml creation/update logic
    $binConfigPath = "$path/config.toml"
    $srcConfigPath = "./config.toml"
    
    Write-Host "Creating/updating bin/config.toml with version $fullVersion"
    
    # Read source config to extract sections
    $srcContent = Get-Content $srcConfigPath -Raw
    
    # Parse TOML to extract values
    $appName = "Custos MCP Filesystem Server"  # Default name
    
    # Extract directories section from source
    $directoriesSection = ""
    if ($srcContent -match '(?ms)\[directories\](.*?)(?=\[|$)') {
        $directoriesSection = "[directories]" + $matches[1].TrimEnd()
    }
    
    # Extract logging sections from source  
    $loggingSections = ""
    $matches = [regex]::Matches($srcContent, '(?ms)\[\[logging\]\](.*?)(?=\[\[|\[(?!\[)|$)')
    foreach ($match in $matches) {
        $loggingSections += "[[logging]]" + $match.Groups[1].Value.TrimEnd() + "`n`n"
    }
    
    # Create new config content with app section
    $newConfigContent = @"
# Custos MCP Filesystem Server Configuration
# Version: $fullVersion

$directoriesSection

$loggingSections
"@
    
    Set-Content -Path $binConfigPath -Value $newConfigContent -NoNewline
    Write-Host "Updated bin/config.toml with version '$fullVersion'"

    $currentlocation = $(get-location)
    $invokelocation = (Split-Path $MyInvocation.MyCommand.Path)

    Write-Host "Source dir:`t$currentlocation"
    Write-Host "Script dir:`t$invokelocation"

    $env:GOOS = "windows";
    $env:GOARCH = "amd64";
    $env:CGO_ENABLED = 0  # Disabled for MCP server
    $env:GO111MODULE = "on"
    
    # Update Go modules and ensure dependencies are available
    Write-Host "Updating Go modules..." -ForegroundColor Yellow
    go mod tidy
    if ($LASTEXITCODE -ne 0) {
        Write-Error "go mod tidy failed with exit code $LASTEXITCODE"
        return
    }
    Write-Host "Go modules updated successfully" -ForegroundColor Green
    
    # Update packages to latest versions if requested
    if ($UpdatePackages) {
        Write-Host "Updating all packages to latest versions..." -ForegroundColor Cyan
        
        try {
            # Check for available updates first
            Write-Host "Checking for available updates..." -ForegroundColor Yellow
            $updateCheck = go list -m -u all 2>$null
            $dependencies = $updateCheck | Where-Object { $_ -match '\[' }
            
            if ($dependencies) {
                Write-Host "Found packages with available updates:" -ForegroundColor Yellow
                $dependencies | ForEach-Object {
                    Write-Host "  $_" -ForegroundColor Gray
                }
                
                Write-Host "Updating all packages to latest versions..." -ForegroundColor Yellow
                
                # Update all dependencies at once
                $updateResult = go get -u ./...
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully updated all packages" -ForegroundColor Green
                } else {
                    Write-Warning "Some package updates may have failed"
                }
                
                # Run tidy again after updates
                Write-Host "Running go mod tidy after updates..." -ForegroundColor Yellow
                go mod tidy
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "go mod tidy after updates had issues, but continuing..."
                } else {
                    Write-Host "Go modules tidied successfully after updates" -ForegroundColor Green
                }
                
            } else {
                Write-Host "All packages are already up to date" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Error during package updates: $($_.Exception.Message)"
            Write-Host "Continuing with build using current package versions..." -ForegroundColor Yellow
        }
    }
    
    # Download any missing dependencies
    Write-Host "Downloading Go dependencies..." -ForegroundColor Yellow
    go mod download
    if ($LASTEXITCODE -ne 0) {
        Write-Error "go mod download failed with exit code $LASTEXITCODE"
        return
    }
    Write-Host "Go dependencies downloaded successfully" -ForegroundColor Green
    
    # Verify module dependencies
    Write-Host "Verifying Go module dependencies..." -ForegroundColor Yellow
    go mod verify
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "go mod verify reported issues, but continuing with build"
    } else {
        Write-Host "Go module dependencies verified successfully" -ForegroundColor Green
    }
    
    # Format Go source code
    Write-Host "Formatting Go source code..." -ForegroundColor Yellow
    go fmt ./...
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "go fmt reported formatting issues, but continuing with build"
    } else {
        Write-Host "Go source code formatted successfully" -ForegroundColor Green
    }

    # Run Go tests if test files exist
    $testFiles = Get-ChildItem -Path . -Name "*_test.go" -Recurse
    if ($testFiles) {
        Write-Host "Running Go tests..." -ForegroundColor Yellow
        go test ./... -v
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Go tests failed with exit code $LASTEXITCODE"
            return
        } else {
            Write-Host "All Go tests passed successfully" -ForegroundColor Green
        }
    } else {
        Write-Host "No test files found, skipping tests" -ForegroundColor Gray
    }

    $output = Join-Path -Path $path -ChildPath "custos-mcp.exe"
    Write-Host "Output path: $output"
    
    # Stop executing process if it's running
    try {
        $process = Get-Process -Name "custos-mcp" -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "Stopping existing custos-mcp process..." -ForegroundColor Yellow
            Stop-Process -Name "custos-mcp" -Force
            Write-Host "Process stopped successfully" -ForegroundColor Green
        } else {
            Write-Host "No custos-mcp process found running" -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "Could not stop custos-mcp process: $($_.Exception.Message)"
    }
    
    Write-Host "Building custos-mcp version $fullVersion..." -ForegroundColor Yellow
    
    # Build the MCP server with version info
    go build -ldflags "-X main.Version=$fullVersion" -o $output .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed with exit code $LASTEXITCODE"
        return
    }
    
    Write-Host "Build completed successfully!" -ForegroundColor Green
    Write-Host "Executable created at: $output" -ForegroundColor Cyan

}
catch {
    Write-Host "An error occurred that could not be resolved."
    Write-Host $_.ScriptStackTrace
}
finally {
    Pop-Location
}

Write-Host "Build Complete"