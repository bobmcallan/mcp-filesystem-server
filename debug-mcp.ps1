#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Debug MCP server communication to identify Warp connection issues

.DESCRIPTION
    This script tests the MCP server's protocol implementation step by step
    to identify why Warp is failing to start the client.
#>

param(
    [string]$ServerPath = ".\bin\mcp-filesystem-server.exe",
    [string]$AllowedDir = "C:\development"
)

$ErrorActionPreference = "Stop"

# Global process variable for cleanup
$global:mcpProcess = $null

# Cleanup function
function Cleanup-Process {
    if ($global:mcpProcess -and !$global:mcpProcess.HasExited) {
        try {
            Write-Host "`n🧹 Cleaning up MCP process..." -ForegroundColor Yellow
            $global:mcpProcess.Kill()
            $global:mcpProcess.WaitForExit(2000)
        } catch {
            Write-Host "⚠ Cleanup warning: $_" -ForegroundColor Yellow
        } finally {
            try {
                $global:mcpProcess.Close()
            } catch { }
        }
    }
}

# Register cleanup on Ctrl+C
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Cleanup-Process
}

# Also handle Ctrl+C explicitly
$null = [Console]::TreatControlCAsInput = $false
[Console]::CancelKeyPress += {
    param($sender, $e)
    $e.Cancel = $true
    Write-Host "`n⚠ Ctrl+C detected - cleaning up..." -ForegroundColor Yellow
    Cleanup-Process
    exit 0
}

Write-Host "=== MCP Server Protocol Debug ===" -ForegroundColor Cyan
Write-Host "Server: $ServerPath" -ForegroundColor Gray
Write-Host "Allowed Directory: $AllowedDir" -ForegroundColor Gray
Write-Host ""

# Test 1: Basic server startup
Write-Host "Test 1: Server Startup" -ForegroundColor Yellow
try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ServerPath
    $psi.Arguments = $AllowedDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    
    $global:mcpProcess = [System.Diagnostics.Process]::Start($psi)
    $process = $global:mcpProcess
    
    Write-Host "✓ Server process started (PID: $($process.Id))" -ForegroundColor Green
    
    # Give server time to initialize
    Start-Sleep -Milliseconds 500
    
    if ($process.HasExited) {
        Write-Host "✗ Server exited unexpectedly with code: $($process.ExitCode)" -ForegroundColor Red
        $stderr = $process.StandardError.ReadToEnd()
        if ($stderr) {
            Write-Host "STDERR: $stderr" -ForegroundColor Red
        }
        return
    }
    
    Write-Host "✓ Server is running and waiting for input" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to start server: $_" -ForegroundColor Red
    return
}

# Test 2: MCP Initialize Request
Write-Host "`nTest 2: MCP Initialize Request" -ForegroundColor Yellow

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
            name = "debug-client"
            version = "1.0.0"
        }
    }
} | ConvertTo-Json -Depth 10 -Compress

Write-Host "Sending initialize request:" -ForegroundColor Gray
Write-Host $initRequest -ForegroundColor DarkGray

try {
    $process.StandardInput.WriteLine($initRequest)
    $process.StandardInput.Flush()
    
    # Wait for response with timeout
    $timeout = 5000 # 5 seconds
    $startTime = Get-Date
    $response = $null
    
    while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout -and !$process.HasExited) {
        # Check for Ctrl+C more frequently
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::C -and $key.Modifiers -eq [ConsoleModifiers]::Control) {
                Write-Host "`n⚠ Ctrl+C detected during initialize response wait" -ForegroundColor Yellow
                Cleanup-Process
                exit 0
            }
        }
        
        if ($process.StandardOutput.Peek() -ne -1) {
            $response = $process.StandardOutput.ReadLine()
            break
        }
        Start-Sleep -Milliseconds 50  # Reduced sleep for better responsiveness
    }
    
    if ($response) {
        Write-Host "✓ Received response:" -ForegroundColor Green
        Write-Host $response -ForegroundColor White
        
        # Try to parse response
        try {
            $responseObj = $response | ConvertFrom-Json
            if ($responseObj.result -and $responseObj.result.capabilities) {
                Write-Host "✓ Valid MCP initialize response structure" -ForegroundColor Green
            } else {
                Write-Host "⚠ Response structure may be incomplete" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "✗ Response is not valid JSON: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ No response received within timeout" -ForegroundColor Red
        
        # Check if there's anything in stderr
        if ($process.StandardError.Peek() -ne -1) {
            $stderr = $process.StandardError.ReadToEnd()
            Write-Host "STDERR: $stderr" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "✗ Failed to send initialize request: $_" -ForegroundColor Red
}

# Test 3: Send initialized notification
Write-Host "`nTest 3: Initialized Notification" -ForegroundColor Yellow

$initializedNotification = @{
    jsonrpc = "2.0"
    method = "notifications/initialized"
} | ConvertTo-Json -Compress

Write-Host "Sending initialized notification:" -ForegroundColor Gray
Write-Host $initializedNotification -ForegroundColor DarkGray

try {
    $process.StandardInput.WriteLine($initializedNotification)
    $process.StandardInput.Flush()
    
    Write-Host "✓ Initialized notification sent" -ForegroundColor Green
    
    # Give the server a moment to process
    Start-Sleep -Milliseconds 500
    
} catch {
    Write-Host "✗ Failed to send initialized notification: $_" -ForegroundColor Red
}

# Test 4: Test a simple tools/list request
Write-Host "`nTest 4: Tools List Request" -ForegroundColor Yellow

$toolsRequest = @{
    jsonrpc = "2.0"
    id = 2
    method = "tools/list"
} | ConvertTo-Json -Compress

Write-Host "Sending tools/list request:" -ForegroundColor Gray
Write-Host $toolsRequest -ForegroundColor DarkGray

try {
    $process.StandardInput.WriteLine($toolsRequest)
    $process.StandardInput.Flush()
    
    # Wait for response
    $timeout = 3000 # 3 seconds
    $startTime = Get-Date
    $response = $null
    
    while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout -and !$process.HasExited) {
        # Check for Ctrl+C more frequently
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::C -and $key.Modifiers -eq [ConsoleModifiers]::Control) {
                Write-Host "`n⚠ Ctrl+C detected during tools request" -ForegroundColor Yellow
                Cleanup-Process
                exit 0
            }
        }
        
        if ($process.StandardOutput.Peek() -ne -1) {
            $response = $process.StandardOutput.ReadLine()
            break
        }
        Start-Sleep -Milliseconds 50  # Reduced sleep for better responsiveness
    }
    
    if ($response) {
        Write-Host "✓ Received tools list response:" -ForegroundColor Green
        Write-Host $response -ForegroundColor White
        
        try {
            $responseObj = $response | ConvertFrom-Json
            if ($responseObj.result -and $responseObj.result.tools) {
                $toolCount = $responseObj.result.tools.Count
                Write-Host "✓ Found $toolCount tools available" -ForegroundColor Green
            }
        } catch {
            Write-Host "⚠ Could not parse tools response: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ No tools response received" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Failed to send tools request: $_" -ForegroundColor Red
}

# Test 5: Check server health
Write-Host "`nTest 5: Server Health Check" -ForegroundColor Yellow

if (!$process.HasExited) {
    Write-Host "✓ Server is still running" -ForegroundColor Green
    
    # Check for any pending stderr output
    if ($process.StandardError.Peek() -ne -1) {
        $stderr = $process.StandardError.ReadToEnd()
        if ($stderr.Trim()) {
            Write-Host "Server STDERR output:" -ForegroundColor Yellow
            Write-Host $stderr -ForegroundColor DarkYellow
        }
    }
} else {
    Write-Host "✗ Server has exited with code: $($process.ExitCode)" -ForegroundColor Red
}

# Cleanup
Write-Host "`nCleaning up..." -ForegroundColor Gray
Cleanup-Process

Write-Host "`n=== Debug Complete ===" -ForegroundColor Cyan
Write-Host "Check the output above for any issues that might prevent Warp from connecting." -ForegroundColor White

# Check log file
$logFile = ".\bin\mcp-filesystem-server.log"
if (Test-Path $logFile) {
    Write-Host "`nServer log file contents:" -ForegroundColor Yellow
    Get-Content $logFile | ForEach-Object {
        Write-Host $_ -ForegroundColor DarkGray
    }
}
