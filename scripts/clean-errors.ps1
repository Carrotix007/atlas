param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Error Reporting + Crash Dumps (selektiv)..." "INFO"

$cleared = 0

# WER - Windows Error Reporting (User)
$werPath = "$env:LOCALAPPDATA\Microsoft\Windows\WER"
if (Test-Path $werPath) {
    Get-ChildItem -Path $werPath -Recurse -ErrorAction SilentlyContinue | Where-Object {
        Test-IsSuspicious $_.Name
    } | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Force -Recurse -Confirm:$false; Write-Detail $p; $cleared++ } catch {}
    }
}

# WER - ReportArchive + ReportQueue + Temp
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
    Get-ChildItem -Path $wd -Force -Recurse -ErrorAction SilentlyContinue | Where-Object {
        Test-IsSuspicious $_.Name
    } | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Force -Recurse -Confirm:$false; Write-Detail $p; $cleared++ } catch {}
    }
}

# Crash Dumps - verdaechtige .dmp Files
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

# Memory.dmp im Windows-Root (nur wenn verdaechtig - nicht generell loeschen!)
$memDmp = "$env:SystemRoot\MEMORY.DMP"
if (Test-Path $memDmp) {
    Write-Status "MEMORY.DMP vorhanden - pruefe manuell (wird nicht auto-geloescht)." "WARN"
}

Write-Status "$cleared Error/Crash-Eintraege bereinigt." "OK"
