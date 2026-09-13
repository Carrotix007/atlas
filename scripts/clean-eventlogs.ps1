param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Event Logs (selektiv)..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer Event Logs." "WARN"
    return
}

# Diese Logs koennen komplett geleert werden (normal, waeren sonst auch fast leer)
$alwaysClean = @(
    "Windows PowerShell",
    "Microsoft-Windows-PowerShell/Operational",
    "Microsoft-Windows-PowerShell/Analytic",
    "Microsoft-Windows-WinRM/Operational"
)

# Diese Logs enthalten Windows-Compatibility-Infos die NORMAL sind
# Komplett leeren waere verdaechtig - nur wenn Cheat-Eintraege drin sind
$conditionalClean = @(
    "Microsoft-Windows-Application-Experience/Program-Compatibility-Assistant",
    "Microsoft-Windows-Application-Experience/Program-Telemetry",
    "Microsoft-Windows-Application-Experience/Program-Compatibility-Troubleshooter",
    "Microsoft-Windows-Application-Experience/Program-Inventory"
)

$cleared = 0

# Immer clearen (PS-Logs sind normal auch mal leer)
foreach ($log in $alwaysClean) {
    try {
        wevtutil cl $log 2>$null
        Write-Detail $log
        $cleared++
    } catch {}
}

# Nur clearen wenn Cheat-Content drin ist
foreach ($log in $conditionalClean) {
    try {
        # Fast pre-check: hat Log ueberhaupt Records?
        $info = Get-WinEvent -ListLog $log -ErrorAction SilentlyContinue
        if (-not $info -or $info.RecordCount -eq 0) { continue }

        # Nur letzte 100 Events statt 1000 - Cheat-Sessions sind meist recent
        $events = Get-WinEvent -LogName $log -MaxEvents 100 -ErrorAction SilentlyContinue
        if (-not $events) { continue }

        $suspiciousFound = $false
        foreach ($e in $events) {
            if ($e.Message -and (Test-IsSuspiciousText $e.Message)) {
                $suspiciousFound = $true
                break
            }
        }

        if ($suspiciousFound) {
            wevtutil cl $log 2>$null
            Write-Detail "$log (hatte verdaechtige Events)"
            $cleared++
        }
    } catch {}
}

Write-Status "$cleared Event-Logs geleert (Compatibility-Logs nur wenn noetig)." "OK"
