param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Prefetch..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer Prefetch." "WARN"
    return
}

$cleared = 0
Get-ChildItem -Path "$env:SystemRoot\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue | Where-Object {
    Test-IsSuspicious $_.Name
} | ForEach-Object {
    try { Remove-Item $_.FullName -Force -ErrorAction Stop; Write-Detail $_.Name; $cleared++ } catch {}
}
Write-Status "$cleared verdaechtige Prefetch-Dateien entfernt (Rest unangetastet)." "OK"
