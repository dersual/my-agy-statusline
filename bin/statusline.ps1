# Windows PowerShell Statusline for Google Antigravity CLI (agy)
# Native, zero-dependency script utilizing built-in .NET classes and ANSI sequences.
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ─── Define Unicode Characters via Hex Codes (PowerShell 5.1 Safe) ───────────
$charCircleFull  = [char]0x25cf
$charCircleEmpty = [char]0x25cb
$charDiamond     = [char]0x25c6
$charGear        = [char]0x2699
$charWrench      = [char]::ConvertFromUtf32(0x1F527) # 🔧
$charHourglass   = [char]0x231b
$charBlockFull   = [char]0x2588
$charBlockDark   = [char]0x2593
$charBlockMed    = [char]0x2592
$charBlockLight  = [char]0x2591
$charDot         = [char]0x00b7
$charSlash       = [char]0x002f
$charPipe        = [char]0x2502
$charCornerTop   = [char]0x256d # ╭
$charLine        = [char]0x2500 # ─
$charCornerBot   = [char]0x2570 # ╰
$charJoin        = [char]0x251c # ├
$charReset       = [char]0x27f3

# ─── Configuration Constants ──────────────────────────────────────────────────
$CONFIG_LAYOUT_WIDE_COLS = 120
$CONFIG_LAYOUT_MED_COLS  = 100
$CONFIG_BAR_LEN_CTX      = 15
$CONFIG_BAR_LEN_QUOTA    = 10
$CONFIG_CTX_WARN_PCT     = 60
$CONFIG_CTX_CRIT_PCT     = 90
$CONFIG_QUOTA_INFO_PCT   = 50
$CONFIG_QUOTA_WARN_PCT   = 70
$CONFIG_QUOTA_CRIT_PCT   = 90

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

# ─── Fallback Git Branch Detection ───────────────────────────────────────────
if ([string]::IsNullOrEmpty($vcsBranch) -and -not [string]::IsNullOrEmpty($cwd)) {
    try {
        $gitBranch = git -C $cwd branch --show-current 2>$null
        if (-not [string]::IsNullOrEmpty($gitBranch)) {
            $vcsBranch = $gitBranch.Trim()
            $status = git -C $cwd status --porcelain 2>$null
            $vcsDirty = -not [string]::IsNullOrEmpty($status)
        }
    } catch {}
}

# ─── LINE 1: State, Model, VCS Branch, Plan ──────────────────────────────────
$agentStateBadge = ""
if ($config.show_state_indicator) {
    switch ($state) {
        "idle"     { $agentStateBadge = "$FG_BRIGHT_GREEN$B$charCircleFull READY$R" }
        "thinking" { $agentStateBadge = "$FG_BRIGHT_YELLOW$B$charDiamond THINKING$R" }
        "working"  { $agentStateBadge = "$FG_BRIGHT_CYAN$B$charGear WORKING$R" }
        "tool_use" { $agentStateBadge = "$FG_BRIGHT_MAGENTA$B$charWrench TOOL$R" }
        default    { $agentStateBadge = "$FG_WHITE$B$charHourglass $($state.ToUpper())$R" }
    }
}

$gitDirStatusBadge = "$FG_BRIGHT_CYAN$dirName$R"
if (-not [string]::IsNullOrEmpty($vcsBranch)) {
    if ($vcsDirty) {
        $gitDirStatusBadge += " $FG_BRIGHT_GREEN($FG_BRIGHT_RED$vcsBranch$FG_BRIGHT_YELLOW*$FG_BRIGHT_GREEN)$R"
    } else {
        $gitDirStatusBadge += " $FG_BRIGHT_GREEN($FG_BRIGHT_BLUE$vcsBranch$FG_BRIGHT_GREEN)$R"
    }
}

$parts = [System.Collections.Generic.List[string]]::new()
if (-not [string]::IsNullOrEmpty($agentStateBadge)) {
    $parts.Add($agentStateBadge)
}
if (-not [string]::IsNullOrEmpty($modelDisplayName)) {
    $parts.Add("$FG_BRIGHT_MAGENTA$I$modelDisplayName$R")
}
if (-not [string]::IsNullOrEmpty($gitDirStatusBadge)) {
    $parts.Add($gitDirStatusBadge)
}

$LINE1 = [string]::Join("$FG_GRAY $charSlash $R", $parts)

# ─── LINE 2: Context Bar & Stats ─────────────────────────────────────────────
$filled = [int][Math]::Floor(($usedPct * $CONFIG_BAR_LEN_CTX) / 100)
$remainder = ($usedPct * $CONFIG_BAR_LEN_CTX) % 100

$barColor = $FG_BRIGHT_WHITE
if ($usedPct -ge $CONFIG_CTX_CRIT_PCT) {
    $barColor = $FG_BRIGHT_RED
} elseif ($usedPct -ge $CONFIG_CTX_WARN_PCT) {
    $barColor = $FG_BRIGHT_YELLOW
}

$bar = ""
for ($idx = 0; $idx -lt $CONFIG_BAR_LEN_CTX; $idx++) {
    if ($idx -lt $filled) {
        $bar += $charBlockFull
    } elseif ($idx -eq $filled) {
        if ($remainder -ge 75) { $bar += $charBlockDark }
        elseif ($remainder -ge 50) { $bar += $charBlockMed }
        elseif ($remainder -ge 25) { $bar += $charBlockLight }
        else { $bar += $charDot }
    } else {
        $bar += $charDot
    }
}

$pctFmt = $usedPct.ToString("F1", [System.Globalization.CultureInfo]::InvariantCulture)
$contextBarBadge = "${FG_GRAY}ctx $barColor$bar $NUM_COLOR$pctFmt%$R"

$statParts = [System.Collections.Generic.List[string]]::new()
$statParts.Add($contextBarBadge)

if ($config.show_additional_stats) {
    if (-not $config.hide_zero_stats -or $artifactCount -gt 0) {
        $statParts.Add("${FG_GRAY}artifacts $NUM_COLOR$artifactCount$R")
    }
    if (-not $config.hide_zero_stats -or $subagentCount -gt 0) {
        $statParts.Add("${FG_GRAY}subagents $NUM_COLOR$subagentCount$R")
    }
    if (-not $config.hide_zero_stats -or $taskCount -gt 0) {
        $statParts.Add("${FG_GRAY}tasks $NUM_COLOR$taskCount$R")
    }
    if ($sandboxEnabled) {
        $statParts.Add("${FG_GRAY}sandbox $FG_BRIGHT_GREEN${B}ON$R")
    } elseif (-not $config.hide_zero_stats) {
        $statParts.Add("${FG_GRAY}sandbox off$R")
    }
}

$LINE2 = " " + [string]::Join("$FG_GRAY $charDot $R", $statParts)

# ─── Quota Progress Bars ─────────────────────────────────────────────────────
function Get-QuotaBar {
    param(
        [double]$pct,
        [int]$width = $CONFIG_BAR_LEN_QUOTA
    )
    $filled = [int][Math]::Round(($pct * $width) / 100)
    $empty = $width - $filled
    
    $barColor = $FG_BRIGHT_GREEN
    if ($pct -ge $CONFIG_QUOTA_CRIT_PCT) { $barColor = $FG_BRIGHT_RED }
    elseif ($pct -ge $CONFIG_QUOTA_WARN_PCT) { $barColor = $FG_BRIGHT_YELLOW }
    elseif ($pct -ge $CONFIG_QUOTA_INFO_PCT) { $barColor = $FG_BRIGHT_CYAN }
    
    $fStr = [string]::new($charCircleFull, $filled)
    $eStr = [string]::new($charCircleEmpty, $empty)
    return "$barColor$fStr$FG_GRAY$eStr$R"
}

function Get-QuotaLine {
    param(
        [string]$label,
        $quotaData,
        [string]$timeFormat
    )
    if ($null -eq $quotaData) { return $null }

    $remaining = 1.0
    if ($null -ne $quotaData.remaining_fraction) {
        $remaining = [double]$quotaData.remaining_fraction
    }
    $pct = [int][Math]::Round((1.0 - $remaining) * 100)
    $pct = [Math]::Max(0, [Math]::Min(100, $pct))
    
    $qBar = Get-QuotaBar -pct $pct
    $pctFmt = "{0,3}" -f $pct
    
    $resetIso = if ($null -ne $quotaData.reset_time) { $quotaData.reset_time.ToString() } else { "" }
    $resetFmt = ""
    if (-not [string]::IsNullOrEmpty($resetIso) -and $resetIso -ne "null") {
        try {
            $dateTime = [DateTimeOffset]::Parse($resetIso)
            $localTime = $dateTime.LocalDateTime
            $timeStr = $localTime.ToString($timeFormat).ToLower()
            $resetFmt = " $FG_GRAY$charReset$R $FG_WHITE$timeStr$R"
        } catch {}
    }
    
    $pColor = $FG_BRIGHT_GREEN
    if ($pct -ge $CONFIG_QUOTA_CRIT_PCT) { $pColor = $FG_BRIGHT_RED }
    elseif ($pct -ge $CONFIG_QUOTA_WARN_PCT) { $pColor = $FG_BRIGHT_YELLOW }
    elseif ($pct -ge $CONFIG_QUOTA_INFO_PCT) { $pColor = $FG_BRIGHT_CYAN }
    
    return "$FG_WHITE$label$R $qBar $pColor$pctFmt%$R$resetFmt"
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
    $line5h = Get-QuotaLine -label "$poolLabel 5h" -quotaData $data.quota.$q5hKey -timeFormat "HH:mm"
    if ($null -ne $line5h) { $quotaLines.Add($line5h) }

    # Weekly Quota
    $lineWk = Get-QuotaLine -label "$poolLabel 7d" -quotaData $data.quota.$qwkKey -timeFormat "MMM d, HH:mm"
    if ($null -ne $lineWk) { $quotaLines.Add($lineWk) }
}

if (-not [string]::IsNullOrEmpty($planTier) -and $planTier -ne "null") {
    $quotaLines.Insert(0, "${FG_GRAY}plan:${R} $FG_WHITE$planTier$R")
}

# ─── Render Layout Based on Terminal Width ───────────────────────────────────
if ($cols -ge $CONFIG_LAYOUT_WIDE_COLS) {
    # Wide layout: everything on one line, quotas below
    Write-Output "$LINE1$FG_GRAY  $charPipe  $R$LINE2"
} elseif ($cols -ge $CONFIG_LAYOUT_MED_COLS) {
    # Medium layout: two lines with box border characters
    Write-Output "$FG_GRAY$charCornerTop$charLine$R $LINE1"
    Write-Output "$FG_GRAY$charCornerBot$charLine$R$LINE2"
} else {
    # Narrow layout: split into 4 structured lines
    $parts1A = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrEmpty($agentStateBadge)) { $parts1A.Add($agentStateBadge) }
    if (-not [string]::IsNullOrEmpty($modelDisplayName)) { $parts1A.Add("$FG_BRIGHT_MAGENTA$I$modelDisplayName$R") }
    $LINE1A = [string]::Join("$FG_GRAY $charSlash $R", $parts1A)
    
    $LINE1B = $gitDirStatusBadge
    $LINE2A = " $contextBarBadge"
    
    $statsOnly = $statParts | Select-Object -Skip 1
    if (($statsOnly | Measure-Object).Count -gt 0) {
        $LINE2B = " " + [string]::Join("$FG_GRAY $charDot $R", $statsOnly)
        Write-Output "$FG_GRAY$charCornerTop$charLine$R $LINE1A"
        Write-Output "$FG_GRAY$charJoin$charLine$R $LINE1B"
        Write-Output "$FG_GRAY$charJoin$charLine$R$LINE2A"
        Write-Output "$FG_GRAY$charCornerBot$charLine$R$LINE2B"
    } else {
        Write-Output "$FG_GRAY$charCornerTop$charLine$R $LINE1A"
        Write-Output "$FG_GRAY$charJoin$charLine$R $LINE1B"
        Write-Output "$FG_GRAY$charCornerBot$charLine$R$LINE2A"
    }
}

foreach ($qLine in $quotaLines) {
    Write-Output $qLine
}

# Add a trailing empty line for padding at the bottom of the terminal
Write-Output ""
