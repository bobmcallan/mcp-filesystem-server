#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Save current Warp session context to a file for restoration

.DESCRIPTION
    This script saves your current working directory, environment variables,
    and project context to help maintain continuity when Warp needs to be restarted.

.PARAMETER Action
    Action to perform: 'save' to save current context, 'restore' to restore context, 'show' to display saved context

.PARAMETER SessionFile
    Path to the session file (defaults to .warp-session.json)
#>

param(
    [ValidateSet('save', 'restore', 'show')]
    [string]$Action = 'save',
    [string]$SessionFile = '.\.warp-session.json'
)

function Save-Session {
    param([string]$FilePath)
    
    Write-Host "💾 Saving Warp session context..." -ForegroundColor Cyan
    
    $sessionData = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        workingDirectory = Get-Location | Select-Object -ExpandProperty Path
        environmentVariables = @{}
        gitInfo = @{}
        projectInfo = @{}
        recentCommands = @()
    }
    
    # Save important environment variables
    $importantVars = @('PATH', 'GOPATH', 'GOROOT', 'NODE_PATH', 'PYTHON_PATH', 'JAVA_HOME', 'MCP_SERVER_PATH')
    foreach ($var in $importantVars) {
        $value = [Environment]::GetEnvironmentVariable($var)
        if ($value) {
            $sessionData.environmentVariables[$var] = $value
        }
    }
    
    # Save Git information if in a git repo
    try {
        if (Test-Path '.git') {
            $currentBranch = git branch --show-current 2>$null
            $lastCommit = git log -1 --oneline 2>$null
            $gitStatus = git status --porcelain 2>$null
            
            $sessionData.gitInfo = @{
                branch = $currentBranch
                lastCommit = $lastCommit
                hasChanges = ($gitStatus.Count -gt 0)
                changedFiles = $gitStatus
            }
        }
    } catch {
        Write-Host "⚠ Could not gather Git information: $_" -ForegroundColor Yellow
    }
    
    # Save project information
    $projectFiles = @('package.json', 'go.mod', 'Cargo.toml', 'pyproject.toml', 'pom.xml', '.csproj')
    foreach ($file in $projectFiles) {
        if (Test-Path $file) {
            $sessionData.projectInfo[$file] = Get-Content $file -Raw
            break
        }
    }
    
    # Try to save recent PowerShell history
    try {
        $historyPath = (Get-PSReadlineOption).HistorySavePath
        if (Test-Path $historyPath) {
            $recentHistory = Get-Content $historyPath | Select-Object -Last 20
            $sessionData.recentCommands = $recentHistory
        }
    } catch {
        Write-Host "⚠ Could not access command history" -ForegroundColor Yellow
    }
    
    # Save to file
    $sessionData | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath -Encoding UTF8
    
    Write-Host "✅ Session saved to: $FilePath" -ForegroundColor Green
    Write-Host "📂 Working Directory: $($sessionData.workingDirectory)" -ForegroundColor Gray
    Write-Host "🕒 Timestamp: $($sessionData.timestamp)" -ForegroundColor Gray
    
    if ($sessionData.gitInfo.branch) {
        Write-Host "🌿 Git Branch: $($sessionData.gitInfo.branch)" -ForegroundColor Gray
    }
}

function Restore-Session {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ Session file not found: $FilePath" -ForegroundColor Red
        return
    }
    
    Write-Host "🔄 Restoring Warp session context..." -ForegroundColor Cyan
    
    try {
        $sessionData = Get-Content $FilePath | ConvertFrom-Json
        
        # Restore working directory
        if ($sessionData.workingDirectory -and (Test-Path $sessionData.workingDirectory)) {
            Set-Location $sessionData.workingDirectory
            Write-Host "📂 Restored working directory: $($sessionData.workingDirectory)" -ForegroundColor Green
        } else {
            Write-Host "⚠ Could not restore working directory" -ForegroundColor Yellow
        }
        
        # Display session info
        Write-Host "🕒 Session from: $($sessionData.timestamp)" -ForegroundColor Gray
        
        if ($sessionData.gitInfo.branch) {
            Write-Host "🌿 Git Branch: $($sessionData.gitInfo.branch)" -ForegroundColor Gray
            if ($sessionData.gitInfo.hasChanges) {
                Write-Host "⚠ Session had uncommitted changes" -ForegroundColor Yellow
            }
        }
        
        # Show recent commands
        if ($sessionData.recentCommands -and $sessionData.recentCommands.Count -gt 0) {
            Write-Host "`n📋 Recent commands from previous session:" -ForegroundColor Cyan
            $sessionData.recentCommands | Select-Object -Last 5 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor DarkGray
            }
        }
        
        Write-Host "`n✅ Session context restored!" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Failed to restore session: $_" -ForegroundColor Red
    }
}

function Show-Session {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ Session file not found: $FilePath" -ForegroundColor Red
        return
    }
    
    try {
        $sessionData = Get-Content $FilePath | ConvertFrom-Json
        
        Write-Host "=== Warp Session Information ===" -ForegroundColor Cyan
        Write-Host "🕒 Saved: $($sessionData.timestamp)" -ForegroundColor White
        Write-Host "📂 Directory: $($sessionData.workingDirectory)" -ForegroundColor White
        
        if ($sessionData.gitInfo.branch) {
            Write-Host "🌿 Git Branch: $($sessionData.gitInfo.branch)" -ForegroundColor White
            Write-Host "💾 Last Commit: $($sessionData.gitInfo.lastCommit)" -ForegroundColor Gray
            if ($sessionData.gitInfo.hasChanges) {
                Write-Host "⚠ Had uncommitted changes: $($sessionData.gitInfo.changedFiles.Count) files" -ForegroundColor Yellow
            }
        }
        
        if ($sessionData.environmentVariables.Keys.Count -gt 0) {
            Write-Host "`n🔧 Environment Variables:" -ForegroundColor Cyan
            foreach ($key in $sessionData.environmentVariables.Keys) {
                $value = $sessionData.environmentVariables[$key]
                $displayValue = if ($value.Length -gt 50) { $value.Substring(0, 50) + "..." } else { $value }
                Write-Host "  $key = $displayValue" -ForegroundColor Gray
            }
        }
        
        if ($sessionData.recentCommands -and $sessionData.recentCommands.Count -gt 0) {
            Write-Host "`n📋 Recent Commands:" -ForegroundColor Cyan
            $sessionData.recentCommands | Select-Object -Last 10 | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Gray
            }
        }
        
    } catch {
        Write-Host "❌ Failed to read session file: $_" -ForegroundColor Red
    }
}

# Main execution
switch ($Action) {
    'save' { 
        Save-Session -FilePath $SessionFile 
    }
    'restore' { 
        Restore-Session -FilePath $SessionFile 
    }
    'show' { 
        Show-Session -FilePath $SessionFile 
    }
}
