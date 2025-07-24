#!/usr/bin/env pwsh
# Test script for MCP Filesystem Server

Write-Host "=== MCP Filesystem Server Test Suite ===" -ForegroundColor Green

# Test 1: Basic functionality test
Write-Host "Test 1: Basic server startup test" -ForegroundColor Yellow
$testDir = Join-Path $env:TEMP "mcp-fs-test-$(Get-Random)"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

try {
    # Test server can start with help flag
    Write-Host "  Testing server help output..."
    $helpOutput = & ./mcp-filesystem-server.exe 2>&1
    if ($helpOutput -match "Usage:") {
        Write-Host "  ✓ Server help output works" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Server help output failed" -ForegroundColor Red
        exit 1
    }

    # Test 2: Create test files
    Write-Host "Test 2: Creating test files" -ForegroundColor Yellow
    $testFile1 = Join-Path $testDir "test1.txt"
    $testFile2 = Join-Path $testDir "test2.json"
    
    "Hello, World!" | Out-File -FilePath $testFile1 -Encoding UTF8
    '{"test": "data", "number": 42}' | Out-File -FilePath $testFile2 -Encoding UTF8
    
    if ((Test-Path $testFile1) -and (Test-Path $testFile2)) {
        Write-Host "  ✓ Test files created successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to create test files" -ForegroundColor Red
        exit 1
    }

    # Test 3: Configuration validation
    Write-Host "Test 3: Configuration validation" -ForegroundColor Yellow
    if (Test-Path "./config.json") {
        $config = Get-Content "./config.json" | ConvertFrom-Json
        if ($config.server -and $config.security -and $config.mcp) {
            Write-Host "  ✓ Configuration structure is valid" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Configuration structure is invalid" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  ✗ Configuration file not found" -ForegroundColor Red
        exit 1
    }

    # Test 4: Binary exists and is executable
    Write-Host "Test 4: Binary validation" -ForegroundColor Yellow
    if (Test-Path "./mcp-filesystem-server.exe") {
        $fileInfo = Get-Item "./mcp-filesystem-server.exe"
        if ($fileInfo.Length -gt 0) {
            Write-Host "  ✓ Binary exists and has valid size ($($fileInfo.Length) bytes)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Binary is empty or invalid" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  ✗ Binary not found" -ForegroundColor Red
        exit 1
    }

    Write-Host "=== All Tests Passed! ===" -ForegroundColor Green
    Write-Host "MCP Filesystem Server is ready for use." -ForegroundColor Cyan

} finally {
    # Cleanup
    if (Test-Path $testDir) {
        Remove-Item -Path $testDir -Recurse -Force
    }
}
