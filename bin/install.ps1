# Installer script for Windows (PowerShell)
# Copies statusline.ps1 to ~/.gemini/ and updates settings.json statusLine command.
$ErrorActionPreference = "Stop"

$userProfile = [System.Environment]::GetFolderPath("UserProfile")
$geminiDir = Join-Path $userProfile ".gemini"
$destScript = Join-Path $geminiDir "statusline.ps1"
$configFile = Join-Path $geminiDir "statusline.json"
$settingsFile = Join-Path $geminiDir "antigravity-cli\settings.json"

Write-Host "Installing Unified AGY Statusline..." -ForegroundColor Cyan

# 1. Create .gemini directory if it doesn't exist
if (-not (Test-Path $geminiDir)) {
    New-Item -ItemType Directory -Path $geminiDir -Force | Out-Null
    Write-Host "Created directory: $geminiDir"
}

# 2. Copy the script
$srcScript = Join-Path $PSScriptRoot "statusline.ps1"
if (-not (Test-Path $srcScript)) {
    # If run outside bin/ directory, check root or current dir
    $srcScript = Join-Path $PSScriptRoot "bin\statusline.ps1"
    if (-not (Test-Path $srcScript)) {
        $srcScript = "bin\statusline.ps1"
    }
}

Copy-Item -Path $srcScript -Destination $destScript -Force
Write-Host "Copied statusline.ps1 to: $destScript" -ForegroundColor Green

# 3. Create default configuration if not present
if (-not (Test-Path $configFile)) {
    $defaultConfig = @{
        show_quota = $true
        show_additional_stats = $true
        hide_zero_stats = $true
        show_state_indicator = $true
    }
    $defaultConfig | ConvertTo-Json | Set-Content -Path $configFile -Force
    Write-Host "Created default configuration at: $configFile" -ForegroundColor Green
} else {
    Write-Host "Configuration file already exists at $configFile (skipping override)." -ForegroundColor Yellow
}

# 4. Update settings.json
if ($destScript.Contains(" ")) {
    $cmd = "powershell -NoProfile -File '$destScript'"
} else {
    $cmd = "powershell -NoProfile -File $destScript"
}
$jsonEscapedCmd = $cmd.Replace('\', '\\')
$manualSnippet = "{`n  `"statusLine`": {`n    `"type`": `"command`",`n    `"command`": `"$jsonEscapedCmd`",`n    `"enabled`": true`n  }`n}"

if (Test-Path $settingsFile) {
    try {
        $settingsJson = Get-Content $settingsFile -Raw
        $settings = ConvertFrom-Json $settingsJson

        # Ensure statusLine member exists
        if ($null -eq $settings.statusLine) {
            $settings | Add-Member -MemberType NoteProperty -Name "statusLine" -Value (New-Object PSObject)
        }

        $settings.statusLine.type = "command"
        $settings.statusLine.command = $cmd
        $settings.statusLine.enabled = $true

        # Convert back to JSON and write to file
        $newJson = ConvertTo-Json $settings -Depth 10
        Set-Content -Path $settingsFile -Value $newJson -Force
        Write-Host "Successfully updated settings.json statusLine configuration!" -ForegroundColor Green
    } catch {
        Write-Warning "Could not update settings.json: $_"
        Write-Host "Please manually add this to your ${settingsFile}:" -ForegroundColor Yellow
        Write-Host $manualSnippet -ForegroundColor Cyan
    }
} else {
    Write-Warning "settings.json not found at ${settingsFile}. Please configure agy statusline manually."
    Write-Host "Please manually add this to your ${settingsFile}:" -ForegroundColor Yellow
    Write-Host $manualSnippet -ForegroundColor Cyan
}

