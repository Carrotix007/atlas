# ============================================================
#   ATLAS Installer
#   Lädt ATLAS von GitHub, extrahiert und startet
#
#   Nutzung:
#     iwr -useb https://raw.githubusercontent.com/USERNAME/REPO/main/install-atlas.ps1 | iex
#   Oder Rechtsklick -> "Mit PowerShell ausfuehren"
# ============================================================

# ---- KONFIGURATION ----
$GithubUser  = "Carrotix007"
$GithubRepo  = "atlas"
$ReleaseTag  = "latest"  # oder z.B. "v1.0"
# -----------------------

$InstallDir = Join-Path $env:LOCALAPPDATA "ATLAS"
$ZipUrl     = if ($ReleaseTag -eq "latest") {
    "https://github.com/$GithubUser/$GithubRepo/releases/latest/download/atlas-release.zip"
} else {
    "https://github.com/$GithubUser/$GithubRepo/releases/download/$ReleaseTag/atlas-release.zip"
}

trap {
    Write-Host ""
    Write-Host "  [FEHLER] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Beenden mit Enter"
    exit 1
}

Write-Host ""
Write-Host "  ============================================" -ForegroundColor DarkCyan
Write-Host "     ATLAS Installer" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor DarkCyan
Write-Host ""

# ---- 1. WebView2 Runtime pruefen -----------------------------
Write-Host "  [1/5] Pruefe WebView2 Runtime..." -ForegroundColor Yellow
$wv2Installed = $false
$wv2Keys = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
)
foreach ($k in $wv2Keys) {
    if (Test-Path $k) { $wv2Installed = $true; break }
}

if (-not $wv2Installed) {
    Write-Host "         WebView2 Runtime nicht gefunden - lade Installer..." -ForegroundColor Yellow
    $wv2Setup = Join-Path $env:TEMP "MicrosoftEdgeWebview2Setup.exe"
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $wv2Setup -UseBasicParsing
    Start-Process -FilePath $wv2Setup -ArgumentList "/silent /install" -Wait
    Remove-Item $wv2Setup -Force -ErrorAction SilentlyContinue
    Write-Host "         WebView2 Runtime installiert." -ForegroundColor Green
} else {
    Write-Host "         WebView2 Runtime bereits installiert." -ForegroundColor Green
}

# ---- 2. Install-Ordner erstellen -----------------------------
Write-Host "  [2/5] Erstelle Install-Ordner: $InstallDir" -ForegroundColor Yellow
if (Test-Path $InstallDir) {
    # Alten Content sichern falls Update
    $backup = "$InstallDir.old"
    if (Test-Path $backup) { Remove-Item $backup -Recurse -Force -ErrorAction SilentlyContinue }
    Move-Item $InstallDir $backup -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

# ---- 3. Download Release-ZIP ---------------------------------
Write-Host "  [3/5] Lade ATLAS von GitHub..." -ForegroundColor Yellow
Write-Host "         URL: $ZipUrl" -ForegroundColor DarkGray
$zipFile = Join-Path $env:TEMP "atlas-release.zip"
try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zipFile -UseBasicParsing
} catch {
    Write-Host "         [FEHLER] Download fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "         Pruefe: existiert das Release '$ReleaseTag' im Repo $GithubUser/$GithubRepo?" -ForegroundColor Yellow
    Read-Host "  Beenden mit Enter"
    exit 1
}

# ---- 4. Extrahieren ------------------------------------------
Write-Host "  [4/5] Extrahiere Dateien..." -ForegroundColor Yellow
Expand-Archive -Path $zipFile -DestinationPath $InstallDir -Force
Remove-Item $zipFile -Force

# ---- 5. Shortcut erstellen -----------------------------------
Write-Host "  [5/5] Erstelle Desktop-Shortcut..." -ForegroundColor Yellow
$exePath = Join-Path $InstallDir "DisplayHelper.exe"
if (Test-Path $exePath) {
    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "ATLAS.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exePath
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.IconLocation = "$exePath, 0"
    $shortcut.Save()
    Write-Host "         Shortcut: $shortcutPath" -ForegroundColor Green
} else {
    Write-Host "         [WARN] DisplayHelper.exe nicht gefunden im Release-ZIP" -ForegroundColor Yellow
}

# ---- Fertig --------------------------------------------------
Write-Host ""
Write-Host "  ============================================" -ForegroundColor DarkCyan
Write-Host "     Installation abgeschlossen!" -ForegroundColor Green
Write-Host "     Ort: $InstallDir" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor DarkCyan
Write-Host ""

$start = Read-Host "  ATLAS jetzt starten? (j/n)"
if ($start -eq "j") {
    Start-Process -FilePath $exePath -WorkingDirectory $InstallDir
}
