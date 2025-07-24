#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Convenient aliases for Warp session management

.DESCRIPTION
    Source this file to get convenient session management commands:
    - save-warp-session: Save current session
    - restore-warp-session: Restore previous session  
    - show-warp-session: Show saved session info
#>

# Create convenient functions
function save-warp-session {
    & "$PSScriptRoot\save-session.ps1" -Action save
}

function restore-warp-session {
    & "$PSScriptRoot\save-session.ps1" -Action restore
}

function show-warp-session {
    & "$PSScriptRoot\save-session.ps1" -Action show
}

# Also create shorter aliases
Set-Alias -Name sws -Value save-warp-session -Description "Save Warp session"
Set-Alias -Name rws -Value restore-warp-session -Description "Restore Warp session"
Set-Alias -Name ws -Value show-warp-session -Description "Show Warp session"

Write-Host "🔧 Session management loaded!" -ForegroundColor Green
Write-Host "Commands available:" -ForegroundColor Cyan
Write-Host "  save-warp-session (sws)    - Save current session" -ForegroundColor Gray
Write-Host "  restore-warp-session (rws) - Restore previous session" -ForegroundColor Gray
Write-Host "  show-warp-session (ws)     - Show saved session info" -ForegroundColor Gray
