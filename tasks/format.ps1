$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path
$SettingsPath = Join-Path $RepoRoot "PSScriptAnalyzerSettings.psd1"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Write-Output "--- Formatting PowerShell scripts (Invoke-Formatter) ---"

$targets = @("bin", "tasks", "tests") | ForEach-Object {
    $dir = Join-Path $RepoRoot $_
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Filter "*.ps1" -Recurse -File
    }
}

if (-not $targets -or $targets.Count -eq 0) {
    Write-Output "No .ps1 files found to format."
    exit 0
}

$count = 0
foreach ($file in $targets) {
    Write-Output "Formatting $($file.Name)..."
    $raw = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $formatted = Invoke-Formatter -ScriptDefinition $raw -Settings $SettingsPath
    if ($null -ne $formatted) {
        if (-not $formatted.EndsWith("`n")) {
            $formatted += "`n"
        }
        [System.IO.File]::WriteAllText($file.FullName, $formatted, $Utf8NoBom)
        $count++
    }
}

Write-Output "Formatted $count PowerShell script(s)."
exit 0
