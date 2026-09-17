param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Error Reporting + Crash Dumps (selektiv)..." "INFO"

$cleared = 0

# Compiled Regex fuer schnelles Content-Matching (Cheat-Keywords)
$escapedKeywords = $SUSPECT_KEYWORDS | ForEach-Object { [regex]::Escape($_) -replace '\\\*', '\S*' }
$combinedPattern = "(?i)(" + ($escapedKeywords -join '|') + ")"
$fastRegex = [regex]::new($combinedPattern, [System.Text.RegularExpressions.RegexOptions]::Compiled)

# WER - Windows Error Reporting (User + System)
$werDirs = @(
    "$env:LOCALAPPDATA\Microsoft\Windows\WER\Temp",
    "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
    "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue",
    "$env:PROGRAMDATA\Microsoft\Windows\WER\Temp",
    "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportArchive",
    "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportQueue"
)

foreach ($wd in $werDirs) {
    if (-not (Test-Path $wd)) { continue }

    # WER Report-Ordner heissen "Report_wer_<hex>" oder "AppCrash_<name>_<hex>"
    # Der ORDNERNAME matched keine Cheat-Keywords, aber der CONTENT (Report.wer INI-File) tut es
    Get-ChildItem -Path $wd -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $reportDir = $_
        $suspiciousContent = $false

        # 1) Ordner-Name check
        if (Test-IsSuspicious $reportDir.Name) {
            $suspiciousContent = $true
        } else {
            # 2) Content check der Report.wer + Report.txt Files (INI/Text)
            Get-ChildItem -Path $reportDir.FullName -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Extension -in @(".wer", ".txt", ".xml", ".log")
            } | ForEach-Object {
                if ($suspiciousContent) { return }
                try {
                    $content = [System.IO.File]::ReadAllText($_.FullName)
                    if ($fastRegex.IsMatch($content)) {
                        $suspiciousContent = $true
                    }
                } catch {}
            }
        }

        if ($suspiciousContent) {
            try {
                $p = $reportDir.FullName
                Remove-Item $p -Force -Recurse -Confirm:$false
                Write-Detail "WER-Report :: $p"
                $cleared++
            } catch {}
        }
    }

    # Loose Files direkt im WER-Dir (Report.wer etc.)
    Get-ChildItem -Path $wd -File -Force -ErrorAction SilentlyContinue | Where-Object {
        Test-IsSuspicious $_.Name
    } | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $cleared++ } catch {}
    }
}

# Crash Dumps - verdaechtige .dmp Files (Name-based, sind bereits klar benannt)
$dumpDirs = @(
    "$env:LOCALAPPDATA\CrashDumps",
    "$env:SystemRoot\Minidump",
    "$env:SystemRoot\LiveKernelReports"
)
foreach ($dd in $dumpDirs) {
    if (-not (Test-Path $dd)) { continue }
    Get-ChildItem -Path $dd -Filter "*.dmp" -Force -ErrorAction SilentlyContinue | Where-Object {
        Test-IsSuspicious $_.Name
    } | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $cleared++ } catch {}
    }
}

# Application Event Log conditional cleanen wenn Cheat-Crashes drin sind
# (Event ID 1000 = Application Error - genau da landet "Software Crash")
if (Test-IsAdmin) {
    try {
        $appEvents = Get-WinEvent -FilterHashtable @{LogName='Application'; ID=1000,1002; StartTime=(Get-Date).AddDays(-30)} -MaxEvents 200 -ErrorAction SilentlyContinue
        $suspicious = $false
        foreach ($e in $appEvents) {
            if ($e.Message -and $fastRegex.IsMatch($e.Message)) {
                $suspicious = $true
                break
            }
        }
        if ($suspicious) {
            wevtutil cl Application 2>$null
            Write-Detail "Application Event Log (hatte Cheat-Crash-Events)"
            $cleared++
        }
    } catch {}
}

# Memory.dmp im Windows-Root
$memDmp = "$env:SystemRoot\MEMORY.DMP"
if (Test-Path $memDmp) {
    Write-Status "MEMORY.DMP vorhanden - pruefe manuell (wird nicht auto-geloescht)." "WARN"
}

Write-Status "$cleared Error/Crash-Eintraege bereinigt." "OK"
