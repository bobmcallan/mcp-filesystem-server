#!/usr/bin/env pwsh

# Simple test for MCP server
param(
    [string]$ServerPath = ".\bin\mcp-filesystem-server.exe",
    [string]$AllowedDir = "C:\development"
)

Write-Host "Testing MCP server directly..." -ForegroundColor Cyan

# Test server startup
try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ServerPath
    $psi.Arguments = $AllowedDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    
    $process = [System.Diagnostics.Process]::Start($psi)
    
    Write-Host "Server started with PID: $($process.Id)" -ForegroundColor Green
    
    # Wait for server to initialize
    Start-Sleep -Milliseconds 500
    
    if ($process.HasExited) {
        Write-Host "Server exited with code: $($process.ExitCode)" -ForegroundColor Red
        $stderr = $process.StandardError.ReadToEnd()
        Write-Host "STDERR: $stderr" -ForegroundColor Red
        return
    }
    
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
    
    Write-Host "Sending initialize request..." -ForegroundColor Yellow
    $process.StandardInput.WriteLine($initRequest)
    $process.StandardInput.Flush()
    
    # Wait for response
    $timeout = 5000
    $startTime = Get-Date
    
    while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout -and !$process.HasExited) {
        if ($process.StandardOutput.Peek() -ne -1) {
            $response = $process.StandardOutput.ReadLine()
            Write-Host "Response: $response" -ForegroundColor Green
            
            try {
                $responseObj = $response | ConvertFrom-Json
                if ($responseObj.result) {
                    Write-Host "✓ Valid initialize response" -ForegroundColor Green
                } else {
                    Write-Host "⚠ Initialize response may have issues" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "✗ Response parsing failed: $_" -ForegroundColor Red
            }
            break
        }
        Start-Sleep -Milliseconds 100
    }
    
    # Clean up
    if (!$process.HasExited) {
        $process.Kill()
        $process.WaitForExit(2000)
    }
    $process.Close()
    
} catch {
    Write-Host "Test failed: $_" -ForegroundColor Red
}

Write-Host "Test complete." -ForegroundColor Cyan
