# ATLAS

Native Windows Anti-Forensik-Tool mit dark-purple GUI.

## Nutzung

**Option A: Ephemeral (einmalig, verschwindet komplett danach)** — empfohlen für Panic-vor-PCCheck:

```powershell
iwr -useb https://raw.githubusercontent.com/Carrotix007/atlas/main/atlas-run.ps1 | iex
```

- Downloadet ATLAS in Temp-Ordner mit random Namen
- Random Rename der EXE (Prefetch-Traces landen unter random Namen)
- Startet als Admin
- Beim Schließen: `clean-self` + Temp-Ordner komplett gelöscht

**Option B: Permanent installieren** (mit Desktop-Shortcut):

```powershell
iwr -useb https://raw.githubusercontent.com/Carrotix007/atlas/main/install-atlas.ps1 | iex
```

Der Installer:
- Prüft & installiert WebView2 Runtime (falls fehlt)
- Lädt das aktuelle Release
- Installiert nach `%LOCALAPPDATA%\ATLAS`
- Erstellt Desktop-Shortcut
- Startet ATLAS

## Nutzung

Starte ATLAS via Desktop-Shortcut oder `%LOCALAPPDATA%\ATLAS\DisplayHelper.exe`.

### Tarnung
Das Fenster erscheint als "Display Helper" — 5x auf das Laptop-Icon oben links klicken (innerhalb 1.5s) öffnet die eigentliche ATLAS-Oberfläche.

### Buttons
- **Full Clean** — kompletter Durchgang (30-60s, kann Reboot nötig machen)
- **Quick Clean** — Panic-Mode für 30s vor PCCheck (~15-20s)
- **Einzelne Buttons** — PCCheck / Echo.ac / Last Activity View / Boot-Zeit
- **Scanner-Tab** — prüft ohne zu löschen was Forensik-Tools finden würden
- **Log-Tab** — Live-Ausgabe aller Actions
- **🔧 Services reparieren** — Notfall wenn Windows-Services kaputt

## Bauen (Developer)

Voraussetzungen: Visual Studio Build Tools 2022 (Community reicht).

```
setup.bat        # installiert Build Tools via winget (nur einmal)
build.bat        # kompiliert DisplayHelper.exe
build-release.bat  # kompiliert + packt Release-ZIP
```

## Repo-Struktur

```
src/                    - C++ Source
scripts/                - PowerShell Cleaner + Scanner
atlas-gui.html          - GUI (WebView2)
boot-scanner-standalone.ps1  - Standalone Boot-Scanner (verschickbar)
build.bat               - Build-Script
build-release.bat       - Release-ZIP-Builder
install-atlas.ps1       - End-User Installer
```

## Setup GitHub Release

1. Repo erstellen (public oder private)
2. Files pushen (siehe .gitignore für Excludes)
3. Lokal `build-release.bat` ausführen → `atlas-release.zip`
4. GitHub → Releases → New release
5. Tag: `v1.0` (oder was du magst)
6. `atlas-release.zip` als Asset hochladen
7. Publish

Dann kann jeder mit dem One-Liner installieren.

## Wichtig

- **Nur Admin**: viele Cleaner brauchen Admin (Prefetch, BAM, Amcache etc.)
- **Windows 10/11**: getestet auf 10 Pro 19045, sollte auf 11 auch laufen
- **WebView2**: bei Win10 Frühjahr 2022+ und Win11 vorinstalliert
