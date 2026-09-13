param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige SRUM..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer SRUM." "WARN"
    return
}

$srumPath = "$env:SystemRoot\System32\sru\SRUDB.dat"
if (-not (Test-Path $srumPath)) {
    Write-Status "SRUM DB nicht gefunden." "OK"
    return
}

try {
    # Trap: Services immer wieder starten - auch wenn Prozess hart gekillt wird
    trap {
        try { Start-Service -Name "DPS" -ErrorAction SilentlyContinue } catch {}
        try { Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue } catch {}
        continue
    }

    Stop-Service -Name "DPS" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500

    Remove-Item $srumPath -Force -Confirm:$false -ErrorAction Stop
    Write-Detail $srumPath

    Start-Service -Name "DPS" -ErrorAction SilentlyContinue
    Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue

    Write-Status "SRUM DB geloescht (wird automatisch neu erstellt)." "OK"
} catch {
    Write-Status "SRUM DB gesperrt - wird beim naechsten Boot bereinigt." "WARN"
    Start-Service -Name "DPS" -ErrorAction SilentlyContinue
    Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
}
