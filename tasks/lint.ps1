$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path
$SettingsPath = Join-Path $RepoRoot "PSScriptAnalyzerSettings.psd1"

Write-Output "--- Linting PowerShell scripts (PSScriptAnalyzer) ---"

$targets = @("bin", "tasks", "tests") | ForEach-Object {
    $dir = Join-Path $RepoRoot $_
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Filter "*.ps1" -Recurse -File
    }
}

if (-not $targets -or $targets.Count -eq 0) {
    Write-Output "No .ps1 files found to lint."
    exit 0
}

$issues = foreach ($file in $targets) {
    Invoke-ScriptAnalyzer -Path $file.FullName -Settings $SettingsPath
}

if ($issues) {
    $issues | Format-Table -Property ScriptName, Line, Severity, RuleName, Message -AutoSize
    $errorCount = ($issues | Where-Object { $_.Severity -eq "Error" -or $_.Severity -eq "Warning" }).Count
    if ($errorCount -gt 0) {
        Write-Error "Found $errorCount issue(s) in PowerShell scripts."
        exit 1
    }
}

Write-Output "All PowerShell scripts passed lint checks."
exit 0
