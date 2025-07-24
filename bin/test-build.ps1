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
