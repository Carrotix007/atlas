param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Cloud-Drive Logs (Google Drive / OneDrive / Dropbox)..." "INFO"

$cleared = 0

# Compiled Regex mit ALLEN keywords in EINEM pattern - viel schneller als 60 einzelne Checks
$escapedKeywords = $SUSPECT_KEYWORDS | ForEach-Object { [regex]::Escape($_) -replace '\\\*', '\S*' }
$combinedPattern = "(?i)(" + ($escapedKeywords -join '|') + ")"
$fastRegex = [regex]::new($combinedPattern, [System.Text.RegularExpressions.RegexOptions]::Compiled)

# Bulk-Check via Get-Content -Raw (liest Datei als eine grosse String, dann EIN Regex-Match)
function Test-FileHasCheatContent([string]$path) {
    try {
        $content = [System.IO.File]::ReadAllText($path)
        return $fastRegex.IsMatch($content)
    } catch { return $false }
}

function Clean-LogFile([string]$file, [string]$label) {
    if (-not (Test-FileHasCheatContent $file)) { return 0 }
    try {
        $lines = [System.IO.File]::ReadAllLines($file)
        if (-not $lines) { return 0 }
        $keep = New-Object System.Collections.Generic.List[string]
        $removed = 0
        foreach ($line in $lines) {
            # Fast pre-check per Zeile mit Compiled Regex
            if ($fastRegex.IsMatch($line) -and -not (Test-IsPathWhitelisted $line) -and (Test-IsSuspiciousText $line)) {
                $removed++
            } else {
                [void]$keep.Add($line)
            }
        }
        if ($removed -gt 0) {
            [System.IO.File]::WriteAllLines($file, $keep, [System.Text.UTF8Encoding]::new($false))
            Write-Detail "$label :: $(Split-Path $file -Leaf) ($removed Zeilen)"
            return $removed
        }
    } catch {}
    return 0
}

# Google Drive Desktop Prozesse stoppen damit Log-Files freigeben werden
$driveProcesses = @("GoogleDriveFS", "GoogleDrive", "drive_fs")
$stopped = @()
foreach ($pn in $driveProcesses) {
    Get-Process -Name $pn -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $stopped += $_.Path
            $_.Kill()
        } catch {}
    }
}
if ($stopped.Count -gt 0) {
    Start-Sleep -Milliseconds 800
    Write-Status "Google Drive Desktop temporaer gestoppt ($($stopped.Count) Prozesse)" "INFO"
}

# Google Drive DriveFS Logs
$driveFsLogs = "$env:LOCALAPPDATA\Google\DriveFS\logs"
if (Test-Path $driveFsLogs) {
    Get-ChildItem $driveFsLogs -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $cleared += (Clean-LogFile $_.FullName "DriveFS")
    }
}

# DriveFS SQLite DBs - Warning only
$driveFsDbs = @(
    "$env:LOCALAPPDATA\Google\DriveFS\metrics_store_sqlite.db",
    "$env:LOCALAPPDATA\Google\DriveFS\experiments.db",
    "$env:LOCALAPPDATA\Google\DriveFS\boot_preference_sqlite.db"
)
foreach ($db in $driveFsDbs) {
    if (-not (Test-Path $db)) { continue }
    if (Test-FileHasCheatContent $db) {
        Write-Status "DriveFS DB $(Split-Path $db -Leaf) enthaelt verdaechtige Namen - manuell pruefen!" "WARN"
    }
}

# OneDrive Logs
$oneDriveLogs = @(
    "$env:LOCALAPPDATA\Microsoft\OneDrive\logs",
    "$env:LOCALAPPDATA\Microsoft\OneDrive\setup\logs"
)
foreach ($ldir in $oneDriveLogs) {
    if (-not (Test-Path $ldir)) { continue }
    Get-ChildItem $ldir -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -in @(".log", ".txt")
    } | ForEach-Object {
        $cleared += (Clean-LogFile $_.FullName "OneDrive")
    }
}

# Dropbox Logs
$dropboxLog = "$env:LOCALAPPDATA\Dropbox\instance1\logs"
if (Test-Path $dropboxLog) {
    Get-ChildItem $dropboxLog -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -in @(".log", ".txt")
    } | ForEach-Object {
        $cleared += (Clean-LogFile $_.FullName "Dropbox")
    }
}

# DriveFS Content-Cache - Warning only
$dfsCache = "$env:LOCALAPPDATA\Google\DriveFS"
if (Test-Path $dfsCache) {
    $cacheDirs = Get-ChildItem $dfsCache -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^\d+$'
    }
    foreach ($cd in $cacheDirs) {
        $contentCache = Join-Path $cd.FullName "content_cache"
        if (Test-Path $contentCache) {
            $suspFiles = Get-ChildItem $contentCache -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
                Test-IsSuspicious $_.Name
            }
            if ($suspFiles) {
                Write-Status "DriveFS Content-Cache enthaelt $($suspFiles.Count) verdaechtige gecachte Files - pruefe $contentCache" "WARN"
            }
        }
    }
}

# Google Drive Desktop wieder starten
foreach ($p in $stopped | Select-Object -Unique) {
    if ($p -and (Test-Path $p)) {
        try { Start-Process -FilePath $p -ErrorAction SilentlyContinue } catch {}
    }
}

Write-Status "$cleared Cloud-Drive Log-Zeilen entfernt." "OK"
