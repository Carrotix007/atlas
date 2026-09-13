param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Windows Timeline..." "INFO"

$cdpPath = "$env:LOCALAPPDATA\ConnectedDevicesPlatform"
if (-not (Test-Path $cdpPath)) { return }

$removed = 0
Get-ChildItem -Path $cdpPath -Directory | ForEach-Object {
    $acDb = Join-Path $_.FullName "ActivitiesCache.db"
    $acDbShm = Join-Path $_.FullName "ActivitiesCache.db-shm"
    $acDbWal = Join-Path $_.FullName "ActivitiesCache.db-wal"
    foreach ($f in @($acDb, $acDbShm, $acDbWal)) {
        if (Test-Path $f) {
            try { Remove-Item $f -Force -Confirm:$false; Write-Detail $f; $removed++ } catch {}
        }
    }
}

Write-Status "$removed Timeline-Dateien entfernt." "OK"
