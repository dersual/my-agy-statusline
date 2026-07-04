# Windows PowerShell test harness for statusline.ps1
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptPath = Join-Path $PSScriptRoot "..\bin\statusline.ps1"
$fixturesDir = Join-Path $PSScriptRoot "fixtures"

# Back up user config if it exists
$configPath = Join-Path ([System.Environment]::GetFolderPath("UserProfile")) ".gemini\statusline.json"
$configBackup = "$configPath.bak"
$hasBackup = $false

if (Test-Path $configPath) {
    Copy-Item $configPath $configBackup -Force
    $hasBackup = $true
}

function Run-Test {
    param(
        [string]$FixtureName,
        [hashtable]$Config
    )

    Write-Host "`n[TEST] $FixtureName | Config: $(ConvertTo-Json $Config -Compress)" -ForegroundColor Cyan

    # Ensure .gemini folder exists
    $geminiDir = [System.IO.Path]::GetDirectoryName($configPath)
    if (-not (Test-Path $geminiDir)) {
        New-Item -ItemType Directory -Path $geminiDir -Force | Out-Null
    }

    # Write temporary config
    $ConfigJson = ConvertTo-Json $Config
    Set-Content -Path $configPath -Value $ConfigJson -Force

    # Run statusline
    $fixturePath = Join-Path $fixturesDir "$FixtureName.json"
    if (-not (Test-Path $fixturePath)) {
        throw "Fixture not found: $fixturePath"
    }

    Get-Content $fixturePath -Raw | powershell -NoProfile -File $scriptPath
}

try {
    # Test Case 1: Default Config (smart auto-hiding active, quota shown, state badge shown)
    $defaultConfig = @{
        show_quota = $true
        show_additional_stats = $true
        hide_zero_stats = $true
        show_state_indicator = $true
    }
    Run-Test "idle" $defaultConfig
    Run-Test "active_working" $defaultConfig
    Run-Test "claude_quota" $defaultConfig
    Run-Test "gemini_quota" $defaultConfig

    # Test Case 2: Show all zero stats
    $showZeroConfig = @{
        show_quota = $true
        show_additional_stats = $true
        hide_zero_stats = $false
        show_state_indicator = $true
    }
    Run-Test "idle" $showZeroConfig

    # Test Case 3: Disable quota
    $noQuotaConfig = @{
        show_quota = $false
        show_additional_stats = $true
        hide_zero_stats = $true
        show_state_indicator = $true
    }
    Run-Test "claude_quota" $noQuotaConfig

    # Test Case 4: Disable additional stats
    $noStatsConfig = @{
        show_quota = $true
        show_additional_stats = $false
        hide_zero_stats = $true
        show_state_indicator = $true
    }
    Run-Test "active_working" $noStatsConfig

    # Test Case 5: Disable state indicator
    $noStateConfig = @{
        show_quota = $true
        show_additional_stats = $true
        hide_zero_stats = $true
        show_state_indicator = $false
    }
    Run-Test "active_working" $noStateConfig

    Write-Host "`n[SUCCESS] All statusline.ps1 tests completed!" -ForegroundColor Green
}
finally {
    # Restore user config backup
    if ($hasBackup) {
        Move-Item $configBackup $configPath -Force
    } elseif (Test-Path $configPath) {
        Remove-Item $configPath -Force
    }
}
