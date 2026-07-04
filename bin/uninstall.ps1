# Uninstaller script for Windows (PowerShell)
# Reverts settings.json statusLine configuration and removes installed files.
$ErrorActionPreference = "Stop"

$userProfile = [System.Environment]::GetFolderPath("UserProfile")
$geminiDir = Join-Path $userProfile ".gemini"
$destScript = Join-Path $geminiDir "statusline.ps1"
$configFile = Join-Path $geminiDir "statusline.json"
$settingsFile = Join-Path $geminiDir "antigravity-cli\settings.json"

Write-Host "Uninstalling Unified AGY Statusline..." -ForegroundColor Cyan

# 1. Update settings.json statusLine
if (Test-Path $settingsFile) {
    try {
        $settingsJson = Get-Content $settingsFile -Raw
        $settings = ConvertFrom-Json $settingsJson

        if ($null -ne $settings.statusLine) {
            $settings.statusLine.type = ""
            $settings.statusLine.command = ""
            $settings.statusLine.enabled = $false
        }

        # Convert back to JSON and write to file
        $newJson = ConvertTo-Json $settings -Depth 10
        Set-Content -Path $settingsFile -Value $newJson -Force
        Write-Host "Reverted settings.json statusLine configuration." -ForegroundColor Green
    } catch {
        Write-Warning "Could not update settings.json: $_"
    }
}

# 2. Remove script file
if (Test-Path $destScript) {
    Remove-Item $destScript -Force
    Write-Host "Removed script file: $destScript" -ForegroundColor Green
}

# 3. Prompt or ask about removing the config file
if (Test-Path $configFile) {
    # Non-interactive default: keep the config file so settings aren't lost
    Write-Host "Note: Configuration file left at $configFile to preserve your settings." -ForegroundColor Yellow
}

Write-Host "Uninstall complete!" -ForegroundColor Green
