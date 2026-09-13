param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Amcache (surgical)..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer Amcache." "WARN"
    return
}

$hivePath = "$env:SystemRoot\appcompat\Programs\Amcache.hve"
if (-not (Test-Path $hivePath)) {
    Write-Status "Amcache nicht gefunden." "OK"
    return
}

$cleared = 0
$mountKey = "AMCACHE_TEMP"
$mountPs  = "HKLM:\$mountKey"

try {
    # Trap: AppInfo IMMER wieder starten - auch bei Prozess-Kill
    trap {
        try { & reg unload "HKLM\$mountKey" 2>&1 | Out-Null } catch {}
        try { Start-Service -Name "AppInfo" -ErrorAction SilentlyContinue } catch {}
        continue
    }

    # Pre-Cleanup: falls letzter Run abgebrochen wurde, alten Mount entfernen
    if (Test-Path $mountPs) {
        & reg unload "HKLM\$mountKey" 2>&1 | Out-Null
        Start-Sleep -Milliseconds 200
    }

    # AppInfo Service stoppt Amcache-Zugriff
    Stop-Service -Name "AppInfo" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500

    # Amcache-Hive als Registry mounten (bis zu 3 Versuche mit Backoff)
    $mounted = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $regOut = & reg load "HKLM\$mountKey" "$hivePath" 2>&1
        if ($LASTEXITCODE -eq 0) { $mounted = $true; break }
        Start-Sleep -Milliseconds (500 * $attempt)
    }

    if (-not $mounted) {
        Write-Status "Amcache konnte nicht gemountet werden nach 3 Versuchen: $regOut" "WARN"
        Start-Service -Name "AppInfo" -ErrorAction SilentlyContinue
        return
    }

    # Sub-Keys die Programm-Ausfuehrungen tracken
    $checkPaths = @(
        "$mountPs\Root\InventoryApplicationFile",
        "$mountPs\Root\InventoryApplication",
        "$mountPs\Root\InventoryApplicationShortcut",
        "$mountPs\Root\File"
    )

    foreach ($cp in $checkPaths) {
        if (-not (Test-Path $cp)) { continue }
        Get-ChildItem -Path $cp -ErrorAction SilentlyContinue | ForEach-Object {
            $entry = $_
            try {
                $props = Get-ItemProperty -Path $entry.PSPath -ErrorAction SilentlyContinue
                $matched = $false
                $matchInfo = $entry.PSChildName

                # Verschiedene Property-Namen die Dateipfad/Name enthalten
                foreach ($prop in @("LowerCaseLongPath", "Name", "OriginalFileName", "FileId", "ProgramId")) {
                    $val = $props.$prop
                    if ($val -and (Test-IsSuspicious "$val")) {
                        $matched = $true
                        $matchInfo = "$prop=$val"
                        break
                    }
                }

                # Fallback: SubKey-Name selbst pruefen
                if (-not $matched -and (Test-IsSuspicious $entry.PSChildName)) {
                    $matched = $true
                    $matchInfo = "key=$($entry.PSChildName)"
                }

                if ($matched) {
                    Remove-Item -Path $entry.PSPath -Recurse -Force -ErrorAction Stop
                    Write-Detail "Amcache :: $matchInfo"
                    $cleared++
                }
            } catch {}
        }
    }
} catch {
    Write-Status "Amcache Fehler: $($_.Exception.Message)" "WARN"
} finally {
    # Hive unmounten (GC damit alle Handles frei sind)
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    Start-Sleep -Milliseconds 200
    & reg unload "HKLM\$mountKey" 2>&1 | Out-Null

    # AppInfo restart + verify - kritisch fuer UAC!
    Start-Service -Name "AppInfo" -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    $svc = Get-Service -Name "AppInfo" -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Running') {
        # Nochmal versuchen
        Start-Service -Name "AppInfo" -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        $svc = Get-Service -Name "AppInfo" -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            Write-Status "AppInfo Service konnte nicht wiedergestartet werden! UAC koennte kaputt sein!" "ERR"
        }
    }
}

Write-Status "$cleared Amcache-Eintraege selektiv entfernt (Rest unangetastet)." "OK"
