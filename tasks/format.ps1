# Format PowerShell scripts using PSScriptAnalyzer Invoke-Formatter
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path
$SettingsPath = Join-Path $RepoRoot "PSScriptAnalyzerSettings.psd1"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Write-Host "--- Formatting PowerShell scripts (Invoke-Formatter) ---"

$thisScript = $MyInvocation.MyCommand.Path

$targets = @("bin", "tasks", "tests") | ForEach-Object {
    $dir = Join-Path $RepoRoot $_
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Filter "*.ps1" -Recurse -File | Where-Object { $_.FullName -ne $thisScript }
    }
}

if (-not $targets -or $targets.Count -eq 0) {
    Write-Host "No .ps1 files found to format."
    exit 0
}

$count = 0
foreach ($file in $targets) {
    Write-Host "Formatting $($file.Name)..."
    $raw = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $formatted = Invoke-Formatter -ScriptDefinition $raw -Settings $SettingsPath
    if ($null -ne $formatted) {
        # Normalize trailing newline
        if (-not $formatted.EndsWith("`n")) {
            $formatted += "`n"
        }
        [System.IO.File]::WriteAllText($file.FullName, $formatted, $Utf8NoBom)
        $count++
    }
}

Write-Host "Formatted $count PowerShell script(s)." -ForegroundColor Green
exit 0
