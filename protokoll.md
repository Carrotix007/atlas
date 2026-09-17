# ATLAS — Anti-Forensik-Tool für Windows

Native Windows-Desktop-App mit dark-purple GUI. Bereinigt surgical alle Windows-Artefakte die von Forensik-Scannern (PCCheck, Echo.ac, detect.ac, Last Activity View, Ocean etc.) ausgewertet werden.

---

## Konzept

**Chirurgisch statt aggressiv**: löscht nur was auf Cheat-Keywords matched. Windows-System-Files und legitime Apps (Chrome, OneDrive, Steam etc.) werden per Path-Whitelist geschützt. Leere DBs / komplett-gelöschte Journals wären selbst Red Flags für Forensik-Tools — deswegen wo möglich Wort-Grenzen-Matching + Whitelist.

**Tarnung**: EXE heißt `DisplayHelper.exe`, Startseite ist ein fake "Display Helper" Monitor-Info-Tool. 5x Logo-Klick öffnet die eigentliche ATLAS-Cleaner-Seite.

---

## Architektur

- **`src/main.cpp`** — C++ Win32-App mit WebView2 (Microsoft Edge Chromium)
- **`atlas-gui.html`** — HTML/CSS/JS GUI (Decoy + Cleaner-Seite, Tab-System)
- **`scripts/*.ps1`** — 30+ PowerShell Cleaner + Scanner + Utilities
- **`_common.ps1`** — Shared Keyword-Listen, Test-Funktionen, Write-Status/Detail

**Message-Flow**: HTML → `window.chrome.webview.postMessage()` → C++ handler → `CreateProcessW` mit PowerShell + Pipes → stdout/stderr wird zeilenweise an WebView zurückgesendet → Live-Log-Tab.

---

## Keyword-System

**`$SUSPECT_KEYWORDS`** (~60 Keywords): cheat, hack, aimbot, wallhack, esp, trainer, injector, weapons.meta, explosive, pccheck, cheatengine, processhacker, playertargetting, triggerbot, godmode, speedhack, teleport, noclip, fly\*hack, radar\*hack, dll\*inject, process\*hack, memory\*edit, game\*hack, mod\*menu, bhop, spinbot, ragebot, legitbot, backtrack, resolver, fakelag, antiaim, doubletap, silent\*aim, auto\*shoot, rage\*config, legit\*config, efendi, workshop\*hack, steam\*cheat, overlay\*hack, overlay\*cheat, fivem\*script, redm\*script, samp\*hack, mtasa\*mod, wemod, loader, spoofer, hwid\*spoof, unban, exploit, bypass, dumper, keygen, cracked, patcher, external, internal

**`$WHITELIST_KEYWORDS`**: Anti-Cheats (EasyAntiCheat, BattlEye, Vanguard, FaceIt, etc.) + Windows System Services (AppInfo, SVCHost, etc.) + Windows-Namespace DLLs (WindowsInternal, ComposableShell, etc.)

**`$WHITELIST_PATHS`**: Windows-System-Pfade, Program Files, Microsoft/Google/Mozilla/Adobe/NVIDIA/Steam/Discord/Epic Games/Rockstar etc., ATLAS-Install-Pfade

**Match-Funktionen**:
- `Test-IsSuspicious` — loose substring match (für Dateinamen)
- `Test-IsSuspiciousText` — strict word-boundary regex (für Text-Content wie History-Zeilen)
- `Test-IsSuspiciousFile` — kombiniert Name + Path-Whitelist
- `Test-IsWhitelisted` — Name-Whitelist Check
- `Test-IsPathWhitelisted` — Path-Whitelist Check

---

## Cleaner-Scripts (30+)

### Windows-Standard-Artefakte (schnell)
| Script | Was |
|--------|-----|
| `clean-processes.ps1` | Killt Prozesse mit Cheat-Namen + Debugger (x64dbg, dnSpy, SystemInformer, autohotkey) |
| `clean-prefetch.ps1` | Verdächtige `.pf` Files in `C:\Windows\Prefetch` |
| `clean-registry.ps1` | RecentDocs / RunMRU / TypedPaths / AppCompatFlags Werte + Cheat-Registry-Keys (Cheat Engine, WeMod) |
| `clean-eventlogs.ps1` | PS + WinRM Logs immer, Program-Compatibility Logs conditional (nur wenn Cheat-Content) |
| `clean-history.ps1` | PSReadLine History (Zeilen mit Cheat-Keywords, ISE Recent Files) |
| `clean-recent.ps1` | `.lnk` Files in `%APPDATA%\Microsoft\Windows\Recent` + PowerShell Jump List |
| `clean-services.ps1` | Nur strict pattern match (`*cheat*`, `*aimbot*`, `*wemod*`) — kein Substring-Match, kein Disable |
| `clean-errors.ps1` | WER + ReportArchive + Minidumps + LiveKernelReports (verdächtige `.dmp`) |
| `clean-defender.ps1` | Defender History (24h + suspicious) |
| `clean-shimcache.ps1` | AppCompatCache in ControlSets + Layers |
| `clean-bam.ps1` | BAM/DAM Einträge — mit **SYSTEM-Fallback** via Scheduled Task für Registry-Keys die Admin nicht schreiben darf |
| `clean-timeline.ps1` | `ActivitiesCache.db` + Journal Files |
| `clean-usb.ps1` | USBSTOR + MountPoints2 (letzte 24h) + setupapi.dev.log |

### Last Activity View / detect.ac Coverage
| Script | Was |
|--------|-----|
| `clean-userassist.ps1` | ROT13-decoded UserAssist Einträge (mit Fast-Array-Lookup ROT13) |
| `clean-muicache.ps1` | MUICache Anzeigenamen (mit Path-Whitelist) |
| `clean-rdp.ps1` | Terminal Server Client MRUs + Server-Subkeys |
| `clean-comdlg.ps1` | Nur `.ct` (Cheat Engine Tables) in OpenSavePidlMRU — LastVisited bleibt (wäre Red Flag) |
| `clean-searchhistory.ps1` | WordWheelQuery (UTF-16LE decoded, surgical), TypedURLs, RecentApps |
| `clean-notifications.ps1` | Toast-Notification-Ordner mit Cheat-Namen — `wpndatabase.db` bleibt intakt |
| `clean-shellbags.ps1` | **Opt-in only** — Full-Reset aller Shell Bags (aggressive, aber nicht surgical machbar) |
| `clean-pca.ps1` | Windows 11 PCA Log-Files (`PcaAppLaunchDic.txt`, `PcaGeneralDb*.txt`) — surgical |
| `clean-cloud drive.ps1` | Google DriveFS + OneDrive + Dropbox Logs (mit Compiled Regex + Bulk-Match) |
| `clean-autoruns.ps1` | Registry Run-Keys + Startup-Ordner + Scheduled Tasks (skippt Windows-Tasks) |

### Echo.ac Deep-Cleaner
| Script | Was |
|--------|-----|
| `clean-usn.ps1` | **Soft mode**: Journal-Shrink + Noise-Generation → alte Einträge werden verdrängt, kein Reset (Reset ist Red Flag laut UC-Community) |
| `clean-amcache.ps1` | Surgical via `AppInfo` Service-Stop + Registry-Hive-Mount + selektive Deletes (trap-Handler für AppInfo-Restart) |
| `clean-srum.ps1` | SRUDB.dat löschen (DPS/DiagTrack temporär stoppen, trap-Handler) |
| `clean-freespace.ps1` | `cipher /w` (Stunden, opt-in) |

### Neu (basierend auf UnknownCheats-Community)
| Script | Was |
|--------|-----|
| `clean-scanner-artifacts.ps1` | Echo AC (`echo<random>\` mit `ntfsDump`/`temp.bin`) + Ocean (`a3.exe`, `xxstrings64-Ocean.exe`, `avast.db`, `SYSTEM.log`) + Roblox-Traces |
| `clean-memory.ps1` | Service-Restarts (`DiagTrack`, `WSearch`, `PcaSvc`) um In-Memory Cheat-Strings zu clearen. Niemals `lsass`/`AppInfo` |
| `clean-network.ps1` | DNS Flush + Firefox downloads.sqlite + Firewall-Rules mit Path-Whitelist |
| `clean-temp.ps1` / `clean-temp-fast.ps1` | Verdächtige Temp-Files (Fast: nur oberste Ebene + Cheat-Extensions) |
| `clean-files.ps1` / `clean-files-fast.ps1` | Downloads/Desktop + AppData Executables (Fast: Depth 1 in AppData, kein Deep-Scan) |
| `clean-self.ps1` | ATLAS-eigene Traces (Prefetch, Registry, BAM, Recent, UserAssist, MUICache, RecentApps, PCA, Event Logs, **WebView2 UserDataFolder**) — mit `-SelfName` Parameter für Ephemeral Runner |

### Utility
| Script | Was |
|--------|-----|
| `repair-services.ps1` | Startet 20+ kritische Services falls stopped, entfernt DisableTaskMgr Policy, unmountet Amcache-Hive-Leftovers. `-Fast` Mode für Quick Clean (kein Full-Scan über alle Services) |

---

## Composites

### Quick Clean (`clean-quick.ps1`) — ~15-20s, 27 Module
Alles außer USN, Amcache, Freespace, ShellBags, Memory-Service-Restart, Deep-Files.

### Full Clean (`clean-full.ps1`) — 30-60s, 30+ Module
Alles inklusive USN Soft, Amcache Surgical, Memory-Service-Restart, Deep-Files. Ohne Freespace + ShellBags (opt-in).

### Registry-All (`clean-registry-all.ps1`) — Composite für PCCheck "Registry" Button
Registry + ShimCache + BAM

### Logs-All (`clean-logs-all.ps1`) — Composite für PCCheck "Event Logs" Button
Eventlogs + History

---

## Scanner (`scan-pccheck.ps1`) — 30+ Kategorien

**Windows-Standard**: Prozesse, Prefetch, Files, Cheat-Ordner, Registry MRUs, Cheat-Registry-Keys, Recent Items, BAM/DAM, PS History, Forensik-Tools installiert

**LAV Coverage**: UserAssist (ROT13-decoded), MUICache, Loaded DLLs, Shell Bags, RDP History, ComDlg32 MRUs, WordWheelQuery, RecentApps, Notifications, PCA Logs, Cloud-Drive Logs

**Deep**: Amcache (via Volume Shadow Copy — kein Service-Stop!), SRUM DB (Info)

**Boot-Zeit**: Boot-Start Kernel Driver, Session Manager BootExecute, Winlogon Konfiguration, Image File Execution Options (Debugger-Hijack), BCD Boot-Konfiguration (testsigning, nointegritychecks)

**Advanced**: Vulnerable Kernel Drivers (PROCEXP152, KProcessHacker, EchoDrv, Capcom, DBUtil etc.), Scanner-Artefakte (Echo AC / Ocean Temp-Files), Windows Firewall Rules, Recycle Bin

---

## GUI Struktur (WebView2)

**Decoy-Seite** ("Display Helper"):
- Fake Monitor-Info-Panel (echte Bildschirm-Daten via JS: Auflösung, GPU, Farbtiefe, DPR, Performance-Score)
- 5x Logo-Klick (Laptop-Icon) → ATLAS-Cleaner

**Cleaner-Seite** (3 Tabs):
- **Cleaner Tab**: alle Buttons (Full, Quick, PCCheck, Echo.ac, LAV, Stealth, Notfall-Repair)
- **Log Tab**: Live-Ausgabe zeilenweise mit Farbe (info/ok/warn/err/del/raw/sys), Clear-Button, Auto-Scroll
- **Scanner Tab**: startet `scan-pccheck.ps1`, zeigt aufklappbare Kategorien mit Ampel (clean/found)

**Status-Bar**: Admin-Erkennung (gelber Punkt "Admin" oder grüner Punkt "Standard"), Version

---

## Distribution

### Ephemeral Runner (`atlas-run.ps1`) — empfohlen
One-Liner:
```powershell
iwr -useb https://raw.githubusercontent.com/Carrotix007/atlas/main/atlas-run.ps1 | iex
```
- Downloadet Release-ZIP in `%TEMP%\sys_<random>`
- Random Rename der EXE (Prefetch/UserAssist trackt unter unauffälligem Namen)
- Startet als Admin (UAC-Prompt)
- Auf Beendigung warten → `clean-self -SelfName` + Temp-Ordner komplett gelöscht + WebView2 UserDataFolder gelöscht
- Nach dem Run keine Trace-Files mehr

### Permanent Installer (`install-atlas.ps1`)
One-Liner:
```powershell
iwr -useb https://raw.githubusercontent.com/Carrotix007/atlas/main/install-atlas.ps1 | iex
```
- Installiert nach `%LOCALAPPDATA%\Microsoft\SystemHelper` (Tarnung als Windows-System-Component)
- Setzt Files auf Hidden + System
- Desktop-Shortcut

### GitHub Repository
- **Repo**: `github.com/Carrotix007/atlas`
- **Release**: `atlas-release.zip` (kompilierte EXE + HTML + Scripts)
- **Build**: `build-release.bat` erstellt automatisch ZIP

### Standalone Boot-Scanner (`boot-scanner-standalone.ps1`)
Einzelne PS-Datei mit allen 5 Boot-Zeit-Checks + inline Keywords/Whitelist. Read-Only, verschickbar an Freunde zum Prüfen ihrer Boot-Konfig ohne ATLAS installieren zu müssen.

---

## Build-System

- **`build.bat`** — Setup MSVC x64 → Downloadet WebView2 SDK falls fehlt → Generiert Icon → Kompiliert Resource + `main.cpp` → Kopiert HTML + Scripts nach `build/` (versteckt mit `+h +s`)
- **`setup.bat`** — Installiert Visual Studio Build Tools 2022 via winget (nur einmal)
- **`build-release.bat`** — Ruft `build.bat` auf + packt `atlas-release.zip`

---

## Wichtige Design-Entscheidungen

**USN Journal: Soft Mode statt Reset**
Laut UnknownCheats-Community: Scanner erkennen wenn USN Journal komplett gelöscht wird. ATLAS shrinkt Journal auf 4MB + generiert 200 Dummy-Files zum Verdrängen alter Einträge, dann zurück auf 32MB.

**Amcache: nicht in Quick Clean**
Auf Windows 10 hat `AppInfo` Service-Protection — `Stop-Service` schlägt fehl. Der Amcache-Cleaner ließ AppInfo dann tot → UAC + Task Manager kaputt. Amcache jetzt nur in Full Clean + einzeln.

**BAM: mit SYSTEM-Fallback**
BAM-Registry gehört `NT AUTHORITY\SYSTEM`. Standard-Admin bekommt Access Denied. Cleaner versucht erst als Admin, dann bei Failure via Scheduled Task als `SYSTEM` (Base64-encoded PS Command).

**Event Logs: Conditional Cleaning**
PS/WinRM Logs immer clearen (harmlos), aber Program-Compatibility Logs nur clearen wenn tatsächlich Cheat-Content drin ist — sonst wäre leerer System-Log Red Flag.

**Files-Scan: Depth-Limit + Executable-Only in AppData**
Deep-Scan durch `%LOCALAPPDATA%` dauert ewig (Chrome/Discord/VSCode Caches). Fast-Version limitiert auf Depth 1 + nur `.exe/.dll/.sys/.ps1/.bat/.cmd/.vbs/.js/.msi/.ct`.

**Path-Whitelist über 40 Pfade**
Windows-System-Ordner, Program Files, Microsoft/Google/Mozilla/Adobe/NVIDIA/Steam/Discord/Epic Games/Rockstar/Ubisoft/etc. — alles was in diesen Pfaden liegt wird geskippt.

**Whitelist-Keywords: Anti-Cheats geschützt**
EasyAntiCheat (`eac_`, `eac-`, `easyanticheat`), BattlEye, Vanguard, FaceIt, ESEA, PunkBuster, HackShield etc. — matched Whitelist zuerst, wird NIE als suspicious markiert.

**GUI-Tarnung: Display Helper**
EXE heißt `DisplayHelper.exe`, Fenstertitel "Display Helper", Startseite zeigt Monitor-Info-Panel. Nur 5x Logo-Klick zeigt ATLAS-Cleaner-Seite.

**Ephemeral Runner: Random EXE-Name**
Beim Download wird `DisplayHelper.exe` → `sys_<random>.exe` umbenannt. Prefetch/UserAssist/BAM sammeln unter unauffälligem Namen. Nach Beendigung wird alles inkl. WebView2-Cache gelöscht.

---

## Bekannte Limitations

- **MFT ($MFT)** — NTFS.sys lockt es exklusiv, kein Windows-API. Nur mit Format + Neuinstallation oder Linux-Live-CD komplett zu clearen. MFTExplorer++ findet immer Reste bis Records recycled sind (Wochen).
- **In-Memory Strings in `lsass`** — kann nicht restartet werden (System-Crash). Für echtes Memory-Editing wäre C++ Tool mit ReadProcessMemory/WriteProcessMemory nötig.
- **UEFI-Bootkits** — Boot-Zeit Kernel-Cheats bleiben in Boot-Start Driver Registry sichtbar. BCD-Flags wie `testsigning=Yes` sind sofort suspicious.
- **Kernel-Level Anti-Cheat** (Vanguard, EAC Kernel-Mode) — findet Bootkit-Loader trotzdem oft.

---

## Repo-Struktur
```
src/
  main.cpp              — C++ Win32 + WebView2
  resource.rc           — Icon
  gen-icon.ps1          — Icon-Generator
  app.ico               — Generated
scripts/
  _common.ps1           — Shared Functions + Keywords
  clean-*.ps1           — 25+ Cleaner
  scan-pccheck.ps1      — Scanner
  repair-services.ps1   — Notfall-Repair
  clean-quick.ps1       — Composite
  clean-full.ps1        — Composite
  clean-registry-all.ps1 — Composite
  clean-logs-all.ps1    — Composite
atlas-gui.html          — Decoy + Cleaner GUI
build.bat               — Compile
build-release.bat       — Compile + ZIP
setup.bat               — Install Build Tools
install-atlas.ps1       — Permanent Installer
atlas-run.ps1           — Ephemeral Runner
boot-scanner-standalone.ps1 — Standalone Boot-Scanner
.gitignore              — Excludes build/, deps/, wv2data/
README.md               — Documentation
protokoll.md            — Dieses Dokument
```
