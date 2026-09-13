param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Pruefe laufende Prozesse..." "INFO"

$killed = 0
Get-Process | Where-Object {
    Test-IsSuspicious $_.ProcessName
} | ForEach-Object {
    try { $n = "$($_.ProcessName) (PID $($_.Id))"; $_.Kill(); Write-Detail $n; $killed++ } catch {}
}

$specific = @("x64dbg", "x32dbg", "ollydbg", "dnspy", "dnSpy",
               "SystemInformer", "autohotkey")
foreach ($name in $specific) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
        try { $n = "$($_.ProcessName) (PID $($_.Id))"; $_.Kill(); Write-Detail $n; $killed++ } catch {}
    }
}

if ($killed -eq 0) {
    Write-Status "Keine verdaechtigen Prozesse gefunden." "OK"
} else {
    Write-Status "$killed Prozesse beendet." "OK"
}
