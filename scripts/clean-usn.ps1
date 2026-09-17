param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige USN Journal (soft mode)..." "INFO"
Write-Status "ACHTUNG (laut UC-Community): Scanner erkennen wenn USN Journal komplett geloescht wird!" "WARN"
Write-Status "Soft mode = Groesse shrink + Noise, danach normal. Kein Full-Reset (waere Red Flag)." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer USN Journal." "WARN"
    return
}

# Strategie:
# 1. Journal auf kleine Groesse schrumpfen (alte Eintraege werden verdraengt sobald neue kommen)
# 2. Viel harmlose Disk-Aktivitaet erzeugen um Verdraengung zu erzwingen
# 3. Journal wieder auf Standard-Groesse setzen
#
# Vorteil: Journal bleibt "aktiv" (kein Reset-Flag), Cheat-Eintraege werden ueberschrieben
# Nachteil: Nicht garantiert dass ALLE Cheat-Eintraege weg sind (haengt von Reihenfolge ab)

$drives = @("C:")
Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object {
    $_.Root -ne "C:\" -and $_.Used -gt 0 -and $_.Free -gt 100MB
} | ForEach-Object { $drives += $_.Root.TrimEnd('\') }

foreach ($drv in $drives) {
    try {
        # 1) Schrumpfen auf ~4MB (klein, aber nicht 0)
        & fsutil usn createjournal m=4194304 a=1048576 "$drv" 2>&1 | Out-Null

        # 2) Noise erzeugen - Dummy-Dateien in Temp
        $noiseDir = Join-Path $env:TEMP "atlas_noise_$(Get-Random)"
        New-Item -ItemType Directory -Path $noiseDir -Force -ErrorAction SilentlyContinue | Out-Null

        if (Test-Path $noiseDir) {
            # ~200 kleine Files erstellen und wieder loeschen (harmlose Namen)
            for ($i = 0; $i -lt 200; $i++) {
                $f = Join-Path $noiseDir "cache_$i.tmp"
                try {
                    [System.IO.File]::WriteAllBytes($f, (New-Object byte[] 8192))
                } catch {}
            }
            Get-ChildItem $noiseDir -File -ErrorAction SilentlyContinue | ForEach-Object {
                try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
            }
            Remove-Item $noiseDir -Force -Recurse -ErrorAction SilentlyContinue
        }

        # 3) Journal auf Windows-Standard zuruecksetzen (32MB max, 2MB delta)
        & fsutil usn createjournal m=33554432 a=2097152 "$drv" 2>&1 | Out-Null

        Write-Detail "USN Journal $drv verdraengt + normalisiert"
    } catch {
        Write-Status "USN $drv Fehler: $($_.Exception.Message)" "WARN"
    }
}

Write-Status "USN Journal bereinigt (soft mode)." "OK"
Write-Status "Fuer harten Reset (verdaechtig): fsutil usn deletejournal /d C: manuell." "INFO"
