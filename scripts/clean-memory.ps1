param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige In-Memory Cheat-Strings (Service-Restart)..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer Service-Restart." "WARN"
    return
}

# Scanner (Echo/Ocean/etc.) lesen Memory von diesen Services fuer Cheat-Strings:
# pcasvc, dps, diagtrack, searchindexer, lsass, ntuser.dat
# Service-Restart clert deren Memory - viel simpler + safer als Memory-Editing via PInvoke
# NIEMALS lsass (System-Crash) oder AppInfo (UAC-Kaputt) restart!
$safeToRestart = @(
    @{ Name = "DiagTrack";    Reason = "Connected User Experiences (in-memory Program-Names)" },
    @{ Name = "WSearch";      Reason = "Windows Search Indexer (in-memory File-Metadata)" },
    @{ Name = "PcaSvc";       Reason = "Program Compatibility Assistant (in-memory Program-History)" }
)

$restarted = 0
foreach ($svc in $safeToRestart) {
    try {
        $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if (-not $s) { continue }
        if ($s.Status -ne 'Running') {
            Write-Detail "$($svc.Name): war nicht laufend, skip"
            continue
        }

        # trap sorgt fuer restart auch bei prozess-kill
        try {
            Restart-Service -Name $svc.Name -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 300
            $s2 = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($s2.Status -eq 'Running') {
                Write-Detail "$($svc.Name) restart :: $($svc.Reason)"
                $restarted++
            } else {
                Write-Status "$($svc.Name) startet nicht mehr - versuche zu starten..." "WARN"
                Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Status "$($svc.Name) Restart-Fehler: $($_.Exception.Message)" "WARN"
            Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
        }
    } catch {}
}

Write-Status "$restarted Services restartet (Memory-Strings gecleart)." "OK"
Write-Status "Hinweis: lsass/AppInfo NICHT restartbar (Windows-Stabilitaet). Fuer echtes In-Memory-Editing waere ein C++ Tool mit ReadProcessMemory/WriteProcessMemory noetig." "INFO"
