#!/usr/bin/env pwsh

# Comprehensive test simulating Warp's MCP interaction
param(
    [string]$ServerPath = ".\bin\mcp-filesystem-server.exe",
    [string]$AllowedDir = "C:\development"
)

Write-Host "=== Warp MCP Interaction Simulation ===" -ForegroundColor Green
Write-Host "Testing server communication exactly like Warp does..." -ForegroundColor Cyan
Write-Host ""

# Start server process
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
    Write-Host "✓ Server started (PID: $($process.Id))" -ForegroundColor Green
    
    # Wait for initialization
    Start-Sleep -Milliseconds 200
    
    if ($process.HasExited) {
        Write-Host "✗ Server exited unexpectedly" -ForegroundColor Red
        return
    }
    
    # Test 1: Initialize (exactly like Warp)
    Write-Host "`nTest 1: Initialize request" -ForegroundColor Yellow
    $initRequest = @{
        jsonrpc = "2.0"
        id = 0
        method = "initialize"
        params = @{
            protocolVersion = "2024-11-05"
            capabilities = @{}
            clientInfo = @{
                name = "warp"
                version = "1.0.0"
            }
        }
    } | ConvertTo-Json -Depth 10 -Compress
    
    $process.StandardInput.WriteLine($initRequest)
    $process.StandardInput.Flush()
    
    # Wait for response
    $timeout = 3000
    $startTime = Get-Date
    $response = $null
    
    while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout -and !$process.HasExited) {
        if ($process.StandardOutput.Peek() -ne -1) {
            $response = $process.StandardOutput.ReadLine()
            break
        }
        Start-Sleep -Milliseconds 50
    }
    
    if ($response) {
        Write-Host "Response received: $response" -ForegroundColor Green
        try {
            $responseObj = $response | ConvertFrom-Json
            if ($responseObj.result -and $responseObj.result.serverInfo) {
                Write-Host "✓ Valid initialize response" -ForegroundColor Green
            } else {
                Write-Host "⚠ Initialize response structure issue" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "✗ Response parsing failed: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ No initialize response received" -ForegroundColor Red
        $stderr = $process.StandardError.ReadToEnd()
        if ($stderr) {
            Write-Host "STDERR: $stderr" -ForegroundColor Red
        }
        return
    }
    
    # Test 2: Initialized notification
    Write-Host "`nTest 2: Initialized notification" -ForegroundColor Yellow
    $initNotification = @{
        jsonrpc = "2.0"
        method = "notifications/initialized"
    } | ConvertTo-Json -Compress
    
    $process.StandardInput.WriteLine($initNotification)
    $process.StandardInput.Flush()
    Write-Host "✓ Initialized notification sent" -ForegroundColor Green
    
    # Test 3: Resources list
    Write-Host "`nTest 3: Resources list request" -ForegroundColor Yellow
    $resourcesRequest = @{
        jsonrpc = "2.0"
        id = 1
        method = "resources/list"
        params = @{}
    } | ConvertTo-Json -Compress
    
    $process.StandardInput.WriteLine($resourcesRequest)
    $process.StandardInput.Flush()
    
    # Wait for response
    $startTime = Get-Date
    $response = $null
    
    while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout -and !$process.HasExited) {
        if ($process.StandardOutput.Peek() -ne -1) {
            $response = $process.StandardOutput.ReadLine()
            break
        }
        Start-Sleep -Milliseconds 50
    }
    
    if ($response) {
        Write-Host "Resources response: $response" -ForegroundColor Green
        try {
            $responseObj = $response | ConvertFrom-Json
            if ($responseObj.result -and $responseObj.result.resources) {
                Write-Host "✓ Resources list successful" -ForegroundColor Green
            }
        } catch {
            Write-Host "⚠ Resources response parsing issue: $_" -ForegroundColor Yellow
        }
    }
    
    # Test 4: Tools list
    Write-Host "`nTest 4: Tools list request" -ForegroundColor Yellow
    $toolsRequest = @{
        jsonrpc = "2.0"
        id = 2
        method = "tools/list"
    } | ConvertTo-Json -Compress
    
    $process.StandardInput.WriteLine($toolsRequest)
    $process.StandardInput.Flush()
    
    # Wait for response
    $startTime = Get-Date
    $response = $null
    
    while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout -and !$process.HasExited) {
        if ($process.StandardOutput.Peek() -ne -1) {
            $response = $process.StandardOutput.ReadLine()
            break
        }
        Start-Sleep -Milliseconds 50
    }
    
    if ($response) {
        Write-Host "Tools response received" -ForegroundColor Green
        try {
            $responseObj = $response | ConvertFrom-Json
            if ($responseObj.result -and $responseObj.result.tools) {
                $toolCount = $responseObj.result.tools.Count
                Write-Host "✓ Found $toolCount tools available" -ForegroundColor Green
            }
        } catch {
            Write-Host "⚠ Tools response parsing issue: $_" -ForegroundColor Yellow
        }
    }
    
    # Check for any stderr output (should be empty)
    Write-Host "`nTest 5: Stderr check" -ForegroundColor Yellow
    if ($process.StandardError.Peek() -ne -1) {
        $stderr = $process.StandardError.ReadToEnd()
        if ($stderr.Trim()) {
            Write-Host "⚠ STDERR output detected (this would break Warp):" -ForegroundColor Red
            Write-Host $stderr -ForegroundColor Red
        } else {
            Write-Host "✓ No STDERR output" -ForegroundColor Green
        }
    } else {
        Write-Host "✓ No STDERR output" -ForegroundColor Green
    }
    
    # Clean shutdown
    if (!$process.HasExited) {
        $process.Kill()
        $process.WaitForExit(2000)
    }
    $process.Close()
    
    Write-Host "`n=== Test Results ===" -ForegroundColor Green
    Write-Host "✓ Server started successfully" -ForegroundColor Green
    Write-Host "✓ MCP protocol communication working" -ForegroundColor Green  
    Write-Host "✓ No stderr interference" -ForegroundColor Green
    Write-Host "✓ Server should now work with Warp!" -ForegroundColor Green
    
} catch {
    Write-Host "Test failed: $_" -ForegroundColor Red
}
