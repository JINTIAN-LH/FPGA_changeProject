param(
    [string]$RepoPath = "d:/FPGADevelopMent/fpga_exchangeSerdes",
    [string]$LogPath = ""
)

if (-not $LogPath) {
    $LogPath = Join-Path $RepoPath "fpga_side/logs/git_maintenance.log"
}

$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [git-maintenance] $Message"
    Add-Content -Path $LogPath -Value $line
}

Write-Log "Start"

if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    Write-Log "Skip: .git not found at $RepoPath"
    exit 1
}

$activeGit = Get-Process -Name git -ErrorAction SilentlyContinue
if ($activeGit) {
    Write-Log "Skip: detected active git process, avoid conflict"
    exit 0
}

$tmpObjects = Get-ChildItem -Path (Join-Path $RepoPath ".git/objects") -Recurse -Force -File -Filter "tmp_obj_*" -ErrorAction SilentlyContinue
$tmpCount = ($tmpObjects | Measure-Object).Count
if ($tmpCount -gt 0) {
    $tmpObjects | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Log "Removed temporary object files: $tmpCount"
} else {
    Write-Log "No temporary object files found"
}

$indexLock = Join-Path $RepoPath ".git/index.lock"
if (Test-Path $indexLock) {
    $ageMinutes = ((Get-Date) - (Get-Item $indexLock).LastWriteTime).TotalMinutes
    if ($ageMinutes -ge 120) {
        Remove-Item -Force $indexLock -ErrorAction SilentlyContinue
        Write-Log "Removed stale index.lock (age=$([math]::Round($ageMinutes,1)) min)"
    } else {
        Write-Log "Keep index.lock (age=$([math]::Round($ageMinutes,1)) min)"
    }
}

git -C $RepoPath reflog expire --expire=30.days --expire-unreachable=7.days --all | Out-Null
git -C $RepoPath gc --prune=now | Out-Null

$summary = git -C $RepoPath count-objects -vH
Write-Log "count-objects summary:"
$summary | ForEach-Object { Write-Log $_ }
Write-Log "Done"
