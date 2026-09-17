# ============================================================
#   ATLAS - Ephemeral Runner
#   Downloadet, fuehrt aus, loescht alles nach Beendigung
#
#   Nutzung:
#     iwr -useb https://raw.githubusercontent.com/Carrotix007/atlas/main/atlas-run.ps1 | iex
#
#   Nach dem Schliessen von ATLAS wird ALLES vom PC entfernt.
# ============================================================

$GithubUser = "Carrotix007"
$GithubRepo = "atlas"
$ReleaseTag = "latest"

$ZipUrl = if ($ReleaseTag -eq "latest") {
    "https://github.com/$GithubUser/$GithubRepo/releases/latest/download/atlas-release.zip"
} else {
    "https://github.com/$GithubUser/$GithubRepo/releases/download/$ReleaseTag/atlas-release.zip"
}

# Random Temp-Directory mit unauffaelligem Namen
$randomSuffix = -join ((0..7) | ForEach-Object { [char](Get-Random -Min 97 -Max 123) })
$tempDir = Join-Path $env:TEMP "sys_$randomSuffix"

# Header
Clear-Host
Write-Host ""
Write-Host "  ============================================" -ForegroundColor DarkCyan
Write-Host "     ATLAS Ephemeral Runner" -ForegroundColor Cyan
Write-Host "     Download -> Run -> Auto-Cleanup" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  [i] Temp-Ordner: $tempDir" -ForegroundColor Yellow
Write-Host "  [i] Nach dem Schliessen von ATLAS wird alles automatisch geloescht." -ForegroundColor Yellow
Write-Host ""

try {
    # ---- 1. WebView2 Runtime Check ---------------------------
    Write-Host "  [1/5] Pruefe WebView2 Runtime..." -ForegroundColor Yellow
    $wv2Installed = $false
    $wv2Keys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
    )
    foreach ($k in $wv2Keys) { if (Test-Path $k) { $wv2Installed = $true; break } }

    if (-not $wv2Installed) {
        Write-Host "         WebView2 fehlt - lade Installer..." -ForegroundColor Yellow
        $wv2Setup = Join-Path $env:TEMP "wv2setup.exe"
        Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $wv2Setup -UseBasicParsing
        Start-Process -FilePath $wv2Setup -ArgumentList "/silent /install" -Wait
        Remove-Item $wv2Setup -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "         WebView2 vorhanden." -ForegroundColor Green
    }

    # ---- 2. Temp-Ordner erstellen ----------------------------
    Write-Host "  [2/5] Erstelle Temp-Ordner..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # ---- 3. Download ATLAS -----------------------------------
    Write-Host "  [3/5] Lade ATLAS herunter..." -ForegroundColor Yellow
    $zipFile = Join-Path $tempDir "a.zip"
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zipFile -UseBasicParsing

    # ---- 4. Extract + Rename ---------------------------------
    Write-Host "  [4/5] Extrahiere..." -ForegroundColor Yellow
    Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
    Remove-Item $zipFile -Force

    # Random Rename der EXE damit Prefetch/UserAssist unter random Name landen
    $originalExe = Join-Path $tempDir "DisplayHelper.exe"
    $randomExeName = "sys_" + (-join ((0..5) | ForEach-Object { [char](Get-Random -Min 97 -Max 123) })) + ".exe"
    $renamedExe = Join-Path $tempDir $randomExeName
    if (Test-Path $originalExe) {
        Rename-Item -Path $originalExe -NewName $randomExeName -Force
    }

    # ---- 5. Start ATLAS (mit UAC-Elevation) ------------------
    Write-Host "  [5/5] Starte ATLAS als Admin (UAC-Prompt)..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor DarkCyan
    Write-Host "     ATLAS laeuft jetzt." -ForegroundColor Green
    Write-Host "     Zum Cleanup: einfach ATLAS schliessen." -ForegroundColor Green
    Write-Host "  ============================================" -ForegroundColor DarkCyan

    try {
        $proc = Start-Process -FilePath $renamedExe -Verb RunAs -PassThru -ErrorAction Stop
        $proc.WaitForExit()
        # Beim Beenden auch WebView2-Sub-Prozesse warten lassen
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "  [FEHLER] Konnte ATLAS nicht starten: $($_.Exception.Message)" -ForegroundColor Red
    }

} finally {
    # ---- CLEANUP: alles weg -----------------------------------
    Write-Host ""
    Write-Host "  [Cleanup] Entferne ATLAS-Files..." -ForegroundColor Yellow

    if (Test-Path $tempDir) {
        # clean-self mit expliziten EXE-Namen (Grandparent-Detection funktioniert
        # nicht mehr weil ATLAS-Prozess schon beendet ist)
        $selfClean = Join-Path $tempDir "scripts\clean-self.ps1"
        if (Test-Path $selfClean) {
            try {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $selfClean -Silent -SelfName $randomExeName 2>&1 | Out-Null
            } catch {}
        }

        # Manuell WebView2-UserData-Ordner loeschen (falls clean-self ihn nicht findet)
        $wv2Path = Join-Path $env:LOCALAPPDATA "$randomExeName.WebView2"
        if (Test-Path $wv2Path) {
            try { Remove-Item $wv2Path -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }

        # Multiple Attempts weil WebView2-Prozesse noch File-Handles halten koennen
        for ($i = 0; $i -lt 5; $i++) {
            try {
                Remove-Item $tempDir -Recurse -Force -ErrorAction Stop
                break
            } catch {
                Start-Sleep -Seconds 1
            }
        }
    }

    # Verify
    if (Test-Path $tempDir) {
        Write-Host "  [WARN] Konnte $tempDir nicht komplett loeschen - manuell entfernen!" -ForegroundColor Red
    } else {
        Write-Host "  [OK] Alle Files entfernt. Kein Trace mehr im Temp-Ordner." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  Fertig. Fenster schliesst in 3 Sekunden..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
}
