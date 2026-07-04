# Windows PowerShell Statusline for Google Antigravity CLI (agy)
# Native, zero-dependency script utilizing built-in .NET classes and ANSI sequences.
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ─── Define Unicode Characters via Hex Codes (PowerShell 5.1 Safe) ───────────
$charCircleFull  = [char]0x25cf
$charCircleEmpty = [char]0x25cb
$charDiamond     = [char]0x25c6
$charGear        = [char]0x2699
$charWrench      = [string][char[]]@(0xd83d, 0xdd27) # 🔧 (surrogate pair)
$charHourglass   = [char]0x231b
$charBlockFull   = [char]0x2588
$charBlockDark   = [char]0x2593
$charBlockMed    = [char]0x2592
$charBlockLight  = [char]0x2591
$charDot         = [char]0x00b7
$charSlash       = [char]0x2571
$charPipe        = [char]0x2502
$charCornerTop   = [char]0x256d
$charLine        = [char]0x2500
$charCornerBot   = [char]0x2570
$charReset       = [char]0x27f3

# ─── Read Stdin ─────────────────────────────────────────────────────────────
$jsonText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($jsonText)) {
    Write-Output "agy"
    exit 0
}

try {
    $data = ConvertFrom-Json $jsonText
} catch {
    Write-Output "agy (JSON parse error)"
    exit 0
}

# ─── Configuration Loader (Optional ~/.gemini/statusline.json) ───────────────
$configPath = Join-Path ([System.Environment]::GetFolderPath("UserProfile")) ".gemini\statusline.json"
$config = @{
    show_quota = $true
    show_additional_stats = $true
    hide_zero_stats = $true
    show_state_indicator = $true
}

if (Test-Path $configPath) {
    try {
        $loaded = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($null -ne $loaded) {
            foreach ($key in $config.Keys.Clone()) {
                if ($null -ne $loaded.$key) {
                    $config[$key] = [bool]$loaded.$key
                }
            }
        }
    } catch {}
}

# ─── ANSI Colors & Formatting ───────────────────────────────────────────────
$esc = [char]27
$R = "$esc[0m"          # Reset
$B = "$esc[1m"          # Bold
$D = "$esc[2m"          # Dim
$I = "$esc[3m"          # Italic

$FG_GREEN = "$esc[32m"
$FG_YELLOW = "$esc[33m"
$FG_CYAN = "$esc[36m"
$FG_MAGENTA = "$esc[35m"
$FG_WHITE = "$esc[37m"
$FG_GRAY = "$esc[90m"
$FG_BRIGHT_RED = "$esc[91m"
$FG_BRIGHT_GREEN = "$esc[92m"
$FG_BRIGHT_YELLOW = "$esc[93m"
$FG_BRIGHT_BLUE = "$esc[94m"
$FG_BRIGHT_MAGENTA = "$esc[95m"
$FG_BRIGHT_CYAN = "$esc[96m"
$FG_BRIGHT_WHITE = "$esc[97m"

$NUM_COLOR = "$FG_BRIGHT_WHITE$B"

# ─── Extract Data Fields ─────────────────────────────────────────────────────
$state = if ($null -ne $data.agent_state) { $data.agent_state.ToString() } else { "idle" }
$usedPct = 0.0
if ($null -ne $data.context_window -and $null -ne $data.context_window.used_percentage) {
    $usedPct = [double]$data.context_window.used_percentage
}
$vcsBranch = if ($null -ne $data.vcs.branch) { $data.vcs.branch.ToString() } else { "" }
$vcsDirty = $false
if ($null -ne $data.vcs -and $null -ne $data.vcs.dirty) {
    $vcsDirty = [bool]$data.vcs.dirty
}
$sandboxEnabled = $false
if ($null -ne $data.sandbox -and $null -ne $data.sandbox.enabled) {
    $sandboxEnabled = [bool]$data.sandbox.enabled
}
$artifactCount = 0
if ($null -ne $data.artifact_count) {
    $artifactCount = [int]$data.artifact_count
}

$subagentCount = 0
if ($null -ne $data.subagents) {
    if ($data.subagents -is [System.Array]) {
        $subagentCount = $data.subagents.Length
    } elseif ($data.subagents -is [System.Collections.IEnumerable]) {
        $subagentCount = ($data.subagents | Measure-Object).Count
    } else {
        $subagentCount = 1
    }
}
$taskCount = 0
if ($null -ne $data.task_count) {
    $taskCount = [int]$data.task_count
}
$modelDisplayName = if ($null -ne $data.model.display_name) { $data.model.display_name.ToString() } else { "" }
$modelId = if ($null -ne $data.model.id) { $data.model.id.ToString().ToLower() } else { "" }
$planTier = if ($null -ne $data.plan_tier) { $data.plan_tier.ToString() } else { "" }
$cols = 80
if ($null -ne $data.terminal_width) {
    $cols = [int]$data.terminal_width
}

# Resolve CWD basename
$cwd = if ($null -ne $data.cwd) { $data.cwd.ToString() } else { "" }
if ([string]::IsNullOrEmpty($cwd) -or $cwd -eq "null") {
    $cwd = Get-Location
}
$dirName = [System.IO.Path]::GetFileName($cwd)
if ([string]::IsNullOrEmpty($dirName)) {
    $dirName = $cwd
}

# ─── LINE 1: State, Model, VCS Branch, Plan ──────────────────────────────────
$S = ""
if ($config.show_state_indicator) {
    switch ($state) {
        "idle"     { $S = "$FG_BRIGHT_GREEN$B$charCircleFull READY$R" }
        "thinking" { $S = "$FG_BRIGHT_YELLOW$B$charDiamond THINKING$R" }
        "working"  { $S = "$FG_BRIGHT_CYAN$B$charGear WORKING$R" }
        "tool_use" { $S = "$FG_BRIGHT_MAGENTA$B$charWrench TOOL$R" }
        default    { $S = "$FG_WHITE$B$charHourglass $($state.ToUpper())$R" }
    }
}

$DBlock = "$FG_BRIGHT_CYAN$dirName$R"
if (-not [string]::IsNullOrEmpty($vcsBranch)) {
    if ($vcsDirty) {
        $DBlock += " $FG_BRIGHT_GREEN($FG_BRIGHT_RED$vcsBranch$FG_BRIGHT_YELLOW*$FG_BRIGHT_GREEN)$R"
    } else {
        $DBlock += " $FG_BRIGHT_GREEN($FG_BRIGHT_BLUE$vcsBranch$FG_BRIGHT_GREEN)$R"
    }
}

$parts = [System.Collections.Generic.List[string]]::new()
if (-not [string]::IsNullOrEmpty($S)) {
    $parts.Add($S)
}
if (-not [string]::IsNullOrEmpty($modelDisplayName)) {
    $parts.Add("$FG_BRIGHT_MAGENTA$I$modelDisplayName$R")
}
if (-not [string]::IsNullOrEmpty($DBlock)) {
    $parts.Add($DBlock)
}
if (-not [string]::IsNullOrEmpty($planTier) -and $planTier -ne "null") {
    $parts.Add("$FG_GRAY$planTier$R")
}

$LINE1 = [string]::Join("$FG_GRAY $charSlash $R", $parts)

# ─── LINE 2: Context Bar & Stats ─────────────────────────────────────────────
$barLen = 15
$filled = [int][Math]::Floor(($usedPct * $barLen) / 100)
$remainder = ($usedPct * $barLen) % 100

$barColor = $FG_BRIGHT_WHITE
if ($usedPct -ge 90) {
    $barColor = $FG_BRIGHT_RED
} elseif ($usedPct -ge 60) {
    $barColor = $FG_BRIGHT_YELLOW
}

$bar = ""
for ($i = 0; $i -lt $barLen; $i++) {
    if ($i -lt $filled) {
        $bar += $charBlockFull
    } elseif ($i -eq $filled) {
        if ($remainder -ge 75) { $bar += $charBlockDark }
        elseif ($remainder -ge 50) { $bar += $charBlockMed }
        elseif ($remainder -ge 25) { $bar += $charBlockLight }
        else { $bar += $charDot }
    } else {
        $bar += $charDot
    }
}

$pctFmt = $usedPct.ToString("F1", [System.Globalization.CultureInfo]::InvariantCulture)
$CTX = "$FG_GRAYctx $barColor$bar $NUM_COLOR$pctFmt%$R"

$statParts = [System.Collections.Generic.List[string]]::new()
$statParts.Add($CTX)

if ($config.show_additional_stats) {
    if (-not $config.hide_zero_stats -or $artifactCount -gt 0) {
        $statParts.Add("$FG_GRAYartifacts $NUM_COLOR$artifactCount$R")
    }
    if (-not $config.hide_zero_stats -or $subagentCount -gt 0) {
        $statParts.Add("$FG_GRAYsubagents $NUM_COLOR$subagentCount$R")
    }
    if (-not $config.hide_zero_stats -or $taskCount -gt 0) {
        $statParts.Add("$FG_GRAYtasks $NUM_COLOR$taskCount$R")
    }
    if ($sandboxEnabled) {
        $statParts.Add("$FG_GRAYsandbox $FG_BRIGHT_GREEN${B}ON$R")
    } elseif (-not $config.hide_zero_stats) {
        $statParts.Add("$FG_GRAYsandbox off$R")
    }
}

$LINE2 = " " + [string]::Join("$FG_GRAY $charDot $R", $statParts)

# ─── Quota Progress Bars ─────────────────────────────────────────────────────
function Get-QuotaBar {
    param(
        [double]$pct,
        [int]$width = 10
    )
    $filled = [int][Math]::Round(($pct * $width) / 100)
    $empty = $width - $filled
    
    $barColor = $FG_BRIGHT_GREEN
    if ($pct -ge 90) { $barColor = $FG_BRIGHT_RED }
    elseif ($pct -ge 70) { $barColor = $FG_BRIGHT_YELLOW }
    elseif ($pct -ge 50) { $barColor = $FG_BRIGHT_CYAN }
    
    $fStr = [string]::new($charCircleFull, $filled)
    $eStr = [string]::new($charCircleEmpty, $empty)
    return "$barColor$fStr$FG_GRAY$eStr$R"
}

$quotaLines = [System.Collections.Generic.List[string]]::new()

if ($config.show_quota -and $null -ne $data.quota) {
    # Detect pool: Claude (3p) vs Gemini (Google)
    $quotaPool = "gemini"
    if ($modelId -like "*claude*" -or $modelId -like "*anthropic*" -or $modelId -like "*3p*") {
        $quotaPool = "3p"
    }

    $q5hKey = if ($quotaPool -eq "3p") { "3p-5h" } else { "gemini-5h" }
    $qwkKey = if ($quotaPool -eq "3p") { "3p-weekly" } else { "gemini-weekly" }
    $poolLabel = if ($quotaPool -eq "3p") { "claude" } else { "gemini" }

    # 5h Quota
    $q5h = $data.quota.$q5hKey
    if ($null -ne $q5h) {
        $remaining = 1.0
        if ($null -ne $q5h.remaining_fraction) {
            $remaining = [double]$q5h.remaining_fraction
        }
        $pct = [int][Math]::Round((1.0 - $remaining) * 100)
        $pct = [Math]::Max(0, [Math]::Min(100, $pct))
        
        $qBar = Get-QuotaBar -pct $pct
        $pctFmt = "{0,3}" -f $pct
        
        $resetIso = if ($null -ne $q5h.reset_time) { $q5h.reset_time.ToString() } else { "" }
        $resetFmt = ""
        if (-not [string]::IsNullOrEmpty($resetIso) -and $resetIso -ne "null") {
            try {
                $dateTime = [DateTimeOffset]::Parse($resetIso)
                $localTime = $dateTime.LocalDateTime
                $resetFmt = " $FG_GRAY$charReset$R $FG_WHITE$($localTime.ToString("HH:mm"))$R"
            } catch {}
        }
        
        $pColor = $FG_BRIGHT_GREEN
        if ($pct -ge 90) { $pColor = $FG_BRIGHT_RED }
        elseif ($pct -ge 70) { $pColor = $FG_BRIGHT_YELLOW }
        elseif ($pct -ge 50) { $pColor = $FG_BRIGHT_CYAN }
        
        $quotaLines.Add("$FG_WHITE$poolLabel 5h$R $qBar $pColor$pctFmt%$R$resetFmt")
    }

    # Weekly Quota
    $qwk = $data.quota.$qwkKey
    if ($null -ne $qwk) {
        $remaining = 1.0
        if ($null -ne $qwk.remaining_fraction) {
            $remaining = [double]$qwk.remaining_fraction
        }
        $pct = [int][Math]::Round((1.0 - $remaining) * 100)
        $pct = [Math]::Max(0, [Math]::Min(100, $pct))
        
        $qBar = Get-QuotaBar -pct $pct
        $pctFmt = "{0,3}" -f $pct
        
        $resetIso = if ($null -ne $qwk.reset_time) { $qwk.reset_time.ToString() } else { "" }
        $resetFmt = ""
        if (-not [string]::IsNullOrEmpty($resetIso) -and $resetIso -ne "null") {
            try {
                $dateTime = [DateTimeOffset]::Parse($resetIso)
                $localTime = $dateTime.LocalDateTime
                $resetFmt = " $FG_GRAY$charReset$R $FG_WHITE$($localTime.ToString("MMM d, HH:mm").ToLower())$R"
            } catch {}
        }
        
        $pColor = $FG_BRIGHT_GREEN
        if ($pct -ge 90) { $pColor = $FG_BRIGHT_RED }
        elseif ($pct -ge 70) { $pColor = $FG_BRIGHT_YELLOW }
        elseif ($pct -ge 50) { $pColor = $FG_BRIGHT_CYAN }
        
        $quotaLines.Add("$FG_WHITE$poolLabel 7d$R $qBar $pColor$pctFmt%$R$resetFmt")
    }
}

# ─── Render Layout Based on Terminal Width ───────────────────────────────────
if ($cols -ge 120) {
    # Wide layout: everything on one line, quotas below
    Write-Output "$LINE1$FG_GRAY  $charPipe  $R$LINE2"
} elseif ($cols -ge 80) {
    # Medium layout: two lines with box border characters
    Write-Output "$FG_GRAY$charCornerTop$charLine$R $LINE1"
    Write-Output "$FG_GRAY$charCornerBot$charLine$R$LINE2"
} else {
    # Narrow layout: simple multi-line format
    Write-Output $LINE1
    Write-Output $LINE2
}

foreach ($qLine in $quotaLines) {
    Write-Output $qLine
}
