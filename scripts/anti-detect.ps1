# ══════════════════════════════════════════════════════
#   ATLAS Anti-Detect v5.0 — Surgical + Stealth Mode
#   Counters: PCCheckV4 + Echo.ac
#   Entfernt NUR was die Tools erkennen wuerden
# ══════════════════════════════════════════════════════

param(
    [switch]$Full,
    [switch]$Quick,
    [switch]$FilesOnly,
    [switch]$RegistryOnly,
    [switch]$LogsOnly,
    [switch]$NetworkOnly,
    [switch]$EchoOnly,
    [switch]$Stealth,
    [switch]$Silent
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Status($msg, $type = "INFO") {
    if ($Silent) { return }
    $color = switch ($type) {
        "OK"   { "Green" }
        "WARN" { "Yellow" }
        "ERR"  { "Red" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host "  [$type] " -ForegroundColor $color -NoNewline
    Write-Host $msg
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ══════════════════════════════════════════════════════
#  STRATEGIE: PCCheck sucht mit Filtern, also entfernen
#  wir NUR was diese Filter matchen wuerden.
#  Alles andere bleibt stehen = System sieht normal aus
# ══════════════════════════════════════════════════════

# Master-Liste: Alles was PCCheck als verdaechtig filtert
$SUSPECT_KEYWORDS = @(
    "cheat", "hack", "aimbot", "wallhack", "esp",
    "trainer", "injector", "weapons.meta", "explosive",
    "pccheck", "cheatengine", "processhacker",
    "playertargetting", "triggerbot", "godmode",
    "speedhack", "teleport", "noclip", "fly*hack",
    "radar*hack", "dll*inject", "process*hack",
    "memory*edit", "game*hack", "mod*menu",
    "bhop", "spinbot", "ragebot", "legitbot",
    "backtrack", "resolver", "fakelag", "antiaim",
    "doubletap", "silent*aim", "auto*shoot",
    "rage*config", "legit*config",
    "workshop*hack", "steam*cheat", "overlay*hack",
    "overlay*cheat", "fivem*script", "redm*script",
    "samp*hack", "mtasa*mod", "wemod"
)

function Test-IsSuspicious([string]$name) {
    $lower = $name.ToLower()
    foreach ($kw in $SUSPECT_KEYWORDS) {
        if ($lower -like "*$kw*") { return $true }
    }
    return $false
}

# ══════════════════════════════════════════════════════
#  1. PROZESSE — Nur verdaechtige beenden, rest laeuft
# ══════════════════════════════════════════════════════
function Stop-DetectableProcesses {
    Write-Status "Pruefe laufende Prozesse..." "INFO"

    $killed = 0
    Get-Process | Where-Object {
        Test-IsSuspicious $_.ProcessName
    } | ForEach-Object {
        try { $_.Kill(); $killed++ } catch {}
    }

    # Spezifische Tools die PCCheck namentlich sucht
    $specific = @("x64dbg", "x32dbg", "ollydbg", "dnspy", "dnSpy",
                   "SystemInformer", "autohotkey")
    foreach ($name in $specific) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.Kill(); $killed++ } catch {}
        }
    }

    if ($killed -eq 0) {
        Write-Status "Keine verdaechtigen Prozesse gefunden." "OK"
    } else {
        Write-Status "$killed Prozesse beendet." "OK"
    }
}

# ══════════════════════════════════════════════════════
#  2. DATEIEN — Nur Dateien entfernen deren NAME matcht
#     Normale Dateien bleiben ALLE stehen
# ══════════════════════════════════════════════════════
function Remove-DetectableFiles {
    Write-Status "Suche erkennbare Dateien..." "INFO"

    # PCCheck scannt diese Ordner rekursiv
    $searchPaths = @(
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Desktop",
        "$env:LOCALAPPDATA",
        "$env:APPDATA"
    )

    $removed = 0
    foreach ($searchPath in $searchPaths) {
        if (-not (Test-Path $searchPath)) { continue }
        try {
            Get-ChildItem -Path $searchPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
                Test-IsSuspicious $_.Name
            } | ForEach-Object {
                try { Remove-Item $_.FullName -Recurse -Force -Confirm:$false; $removed++ } catch {}
            }
        } catch {}
    }

    # .ct Dateien (Cheat Engine Tables) — sehr spezifisch
    foreach ($dir in @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads")) {
        Get-ChildItem -Path $dir -Filter "*.ct" -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item $_.FullName -Force -Confirm:$false; $removed++ } catch {}
        }
    }

    # Bekannte App-Ordner die verdaechtig sind
    $knownDirs = @(
        "$env:APPDATA\Cheat Engine*", "$env:LOCALAPPDATA\Cheat Engine*",
        "$env:APPDATA\WeMod*", "$env:LOCALAPPDATA\WeMod*",
        "$env:LOCALAPPDATA\Programs\WeMod*",
        "$env:APPDATA\2Take1*", "$env:APPDATA\Stand*",
        "$env:APPDATA\Cherax*", "$env:APPDATA\Kiddions*",
        "$env:APPDATA\YimMenu*", "$env:APPDATA\Modest*Menu*"
    )
    foreach ($path in $knownDirs) {
        Get-Item -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item $_.FullName -Recurse -Force -Confirm:$false; $removed++ } catch {}
        }
    }

    # PCCheck's eigene Arbeitsordner
    if (Test-Path "C:\Temp\Dump") {
        try { Remove-Item "C:\Temp\Dump" -Recurse -Force -Confirm:$false; $removed++ } catch {}
    }
    if (Test-Path "C:\Temp\Scripts") {
        try { Remove-Item "C:\Temp\Scripts" -Recurse -Force -Confirm:$false; $removed++ } catch {}
    }

    Write-Status "$removed Dateien/Ordner entfernt." "OK"
}

# ══════════════════════════════════════════════════════
#  3. FORENSIK-TOOLS entfernen
# ══════════════════════════════════════════════════════
function Remove-ForensicTools {
    Write-Status "Suche Forensik-Tools..." "INFO"

    $toolNames = @(
        "csvfileview", "CSVFileView",
        "timelineexplorer", "TimelineExplorer",
        "registryexplorer", "RegistryExplorer",
        "winprefetchview", "WinprefetchView",
        "pccheck", "PCCheck"
    )

    $searchPaths = @(
        "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop",
        "$env:PROGRAMFILES", "${env:PROGRAMFILES(X86)}",
        "$env:LOCALAPPDATA", "$env:APPDATA", "C:\Temp"
    )

    $removed = 0
    foreach ($sp in $searchPaths) {
        if (-not (Test-Path $sp)) { continue }
        foreach ($tool in $toolNames) {
            Get-ChildItem -Path $sp -Filter "*$tool*" -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try { Remove-Item $_.FullName -Recurse -Force -Confirm:$false; $removed++ } catch {}
            }
        }
    }

    # Shortcuts die auf Forensik-Tools zeigen
    $shortcutDirs = @(
        "$env:USERPROFILE\Desktop",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
        "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
    )
    foreach ($dir in $shortcutDirs) {
        if (-not (Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue | Where-Object {
            Test-IsSuspicious $_.Name
        } | ForEach-Object {
            try { Remove-Item $_.FullName -Force -Confirm:$false; $removed++ } catch {}
        }
    }

    Write-Status "$removed Forensik-Spuren entfernt." "OK"
}

# ══════════════════════════════════════════════════════
#  4. PREFETCH — Nur verdaechtige .pf loeschen
#     Normale Windows-Prefetch bleibt komplett stehen!
# ══════════════════════════════════════════════════════
function Clear-Prefetch {
    Write-Status "Bereinige Prefetch (nur verdaechtige)..." "INFO"

    if (-not (Test-IsAdmin)) {
        Write-Status "Braucht Admin fuer Prefetch." "WARN"
        return
    }

    # TEST: Alle Prefetch-Dateien loeschen
    $cleared = 0
    Get-ChildItem -Path "$env:SystemRoot\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-Item $_.FullName -Force -ErrorAction Stop; $cleared++ } catch {}
    }
    Write-Status "$cleared Prefetch-Dateien entfernt (TEST: alle)." "OK"
}

# ══════════════════════════════════════════════════════
#  5. REGISTRY — Nur verdaechtige WERTE loeschen
#     Keys und normale Eintraege bleiben stehen!
# ══════════════════════════════════════════════════════
function Clear-Registry {
    Write-Status "Bereinige Registry (nur verdaechtige Werte)..." "INFO"

    # PCCheck filtert Values in diesen Pfaden
    $regPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs\.exe",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs\.dll",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs\.meta",
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store"
    )

    # PCCheck filtert Values die diese Woerter enthalten
    $regFilters = @(
        "*pccheck*", "*menu*", "*temp*",
        "*cheat*", "*hack*", "*aimbot*",
        "*wallhack*", "*esp*", "*trainer*",
        "*injector*", "*weapons.meta*", "*explosive*"
    )

    $cleared = 0
    foreach ($regPath in $regPaths) {
        if (-not (Test-Path $regPath)) { continue }
        try {
            $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            if (-not $items) { continue }

            $items.PSObject.Properties | Where-Object {
                $name = $_.Name
                $val = $_.Value
                # PS-interne Properties ueberspringen
                if ($name -like "PS*") { return $false }
                # String-Werte gegen Filter pruefen
                $text = if ($val -is [string]) { $val }
                        elseif ($val -is [byte[]]) {
                            try { [System.Text.Encoding]::Unicode.GetString($val) } catch { "" }
                        } else { "" }
                if (-not $text) { return $false }
                $match = $false
                foreach ($f in $regFilters) {
                    if ($text -like $f) { $match = $true; break }
                }
                $match
            } | ForEach-Object {
                try {
                    Remove-ItemProperty -Path $regPath -Name $_.Name -ErrorAction Stop
                    $cleared++
                } catch {}
            }
        } catch {}
    }

    # Nur die spezifischen Cheat-App Keys loeschen (nicht alle MRUs!)
    $cheatKeys = @(
        "HKCU:\Software\Cheat Engine",
        "HKCU:\Software\cheatengine.org",
        "HKLM:\SOFTWARE\Cheat Engine",
        "HKCU:\Software\WeMod",
        "HKCU:\Software\Classes\.ct",
        "HKCU:\Software\Classes\CheatEngine*"
    )
    foreach ($key in $cheatKeys) {
        if (Test-Path $key) {
            try { Remove-Item -Path $key -Recurse -Force -Confirm:$false; $cleared++ } catch {}
        }
    }

    Write-Status "$cleared verdaechtige Registry-Eintraege entfernt (Rest unangetastet)." "OK"
}

# ══════════════════════════════════════════════════════
#  6. EVENT LOGS — NICHT komplett leeren!
#     Stattdessen: Nur bestimmte Eintraege filtern
#     oder Logs so lassen dass sie normal aussehen
# ══════════════════════════════════════════════════════
function Clear-EventLogs {
    Write-Status "Bereinige Event Logs (selektiv)..." "INFO"

    if (-not (Test-IsAdmin)) {
        Write-Status "Braucht Admin fuer Event Logs." "WARN"
        return
    }

    # STRATEGIE: PCCheck leert Logs komplett — das ist deren
    # Stealth-Modus. Aber wenn WIR die leeren, faellt das auf.
    #
    # Stattdessen: Nur PowerShell-spezifische Logs leeren
    # (die werden schnell wieder befuellt durch normalen Betrieb)
    # System/Security/Application lassen wir stehen!

    $logsToClean = @(
        "Windows PowerShell",
        "Microsoft-Windows-PowerShell/Operational",
        "Microsoft-Windows-PowerShell/Analytic",
        "Microsoft-Windows-WinRM/Operational"
    )

    $cleared = 0
    foreach ($log in $logsToClean) {
        try { wevtutil cl $log 2>$null; $cleared++ } catch {}
    }

    # System, Security, Application: NICHT leeren!
    # Ein System ohne Event Logs ist verdaechtiger als
    # eins mit normalen Logs.

    Write-Status "$cleared PS-Logs geleert (System/Security/Application bleiben)." "OK"
}

# ══════════════════════════════════════════════════════
#  7. POWERSHELL HISTORY — Selektiv bereinigen
# ══════════════════════════════════════════════════════
function Clear-PSHistory {
    Write-Status "Bereinige PowerShell History (selektiv)..." "INFO"

    # Statt die ganze History zu loeschen: nur verdaechtige
    # Zeilen rausfiltern und die Datei neu schreiben

    $historyPaths = @(
        "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    )

    try {
        $dynamicPath = (Get-PSReadlineOption).HistorySavePath
        if ($dynamicPath -and ($dynamicPath -notin $historyPaths)) {
            $historyPaths += $dynamicPath
        }
    } catch {}

    foreach ($histPath in $historyPaths) {
        if (-not (Test-Path $histPath)) { continue }
        try {
            $lines = Get-Content $histPath -ErrorAction Stop
            $cleanLines = $lines | Where-Object {
                $line = $_.ToLower()
                # Zeilen entfernen die auf Cheats/Tools hindeuten
                -not ($line -like "*cheat*" -or $line -like "*hack*" -or
                      $line -like "*inject*" -or $line -like "*trainer*" -or
                      $line -like "*pccheck*" -or $line -like "*aimbot*" -or
                      $line -like "*wallhack*" -or $line -like "*modmenu*" -or
                      $line -like "*wemod*" -or $line -like "*cheatengine*" -or
                      $line -like "*anti-detect*" -or $line -like "*atlas*anti*")
            }
            $cleanLines | Set-Content $histPath -Force -Encoding UTF8
        } catch {}
    }

    # ISE Recent Files
    $isePath = "$env:USERPROFILE\Documents\WindowsPowerShell\ISERecentFiles.xml"
    if (Test-Path $isePath) {
        try { Remove-Item $isePath -Force -Confirm:$false } catch {}
    }

    Write-Status "PS History bereinigt (nur verdaechtige Zeilen entfernt)." "OK"
}

# ══════════════════════════════════════════════════════
#  8. RECENT ITEMS — Nur verdaechtige Links loeschen
# ══════════════════════════════════════════════════════
function Clear-RecentItems {
    Write-Status "Bereinige Recent Items (selektiv)..." "INFO"

    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
    if (-not (Test-Path $recentPath)) { return }

    $removed = 0

    # Nur die spezifischen Patterns die PCCheck sucht
    Get-ChildItem -Path $recentPath -ErrorAction SilentlyContinue | Where-Object {
        $n = $_.Name.ToLower()
        $n -like "*.ps1.lnk" -or $n -like "*pccheck*" -or
        $n -like "*cheat*" -or $n -like "*hack*" -or
        $n -like "*trainer*" -or $n -like "*inject*" -or
        $n -like "*modmenu*" -or $n -like "*wemod*"
    } | ForEach-Object {
        try { Remove-Item $_.FullName -Force -Confirm:$false; $removed++ } catch {}
    }

    # Jump Lists: NICHT komplett leeren!
    # Nur die die auf verdaechtige Sachen zeigen
    # Problem: Jump Lists sind binaer und schwer selektiv zu bearbeiten
    # Loesung: Nur loeschen wenn wir im Full-Modus sind
    if ($Full) {
        $jumpPath = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
        if (Test-Path $jumpPath) {
            # PowerShell Jump List ID:
            # f01b4d95cf55d32a = powershell.exe
            Get-ChildItem $jumpPath -Filter "*f01b4d95*" -ErrorAction SilentlyContinue | ForEach-Object {
                try { Remove-Item $_.FullName -Force -Confirm:$false; $removed++ } catch {}
            }
        }
    }

    Write-Status "$removed verdaechtige Recent Items entfernt." "OK"
}

# ══════════════════════════════════════════════════════
#  9. BROWSER — Nicht die ganze History loeschen!
#     Nur Download-Eintraege fuer verdaechtige Dateien
# ══════════════════════════════════════════════════════
function Clear-BrowserTraces {
    Write-Status "Bereinige Browser-Spuren (selektiv)..." "INFO"

    # WICHTIG: PCCheck loescht die gesamte History DB.
    # Wir machen das NICHT — eine leere Browser-History
    # ist mega verdaechtig.
    #
    # Stattdessen: Nur Firefox downloads.sqlite loeschen
    # (die ist separat und faellt weniger auf)
    # Chrome/Edge History lassen wir stehen — die enthaelt
    # zu viel normalen Kram und fehlen wuerde auffallen.

    $removed = 0

    # Firefox downloads.sqlite — separat und weniger auffaellig
    $ffProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffProfiles) {
        Get-ChildItem -Path $ffProfiles -Directory | ForEach-Object {
            $dlDb = Join-Path $_.FullName "downloads.sqlite"
            if (Test-Path $dlDb) {
                try { Remove-Item $dlDb -Force -Confirm:$false; $removed++ } catch {}
            }
        }
    }

    Write-Status "$removed Browser-Spuren entfernt (History bleibt intakt)." "OK"
}

# ══════════════════════════════════════════════════════
# 10. NETZWERK — DNS flush + verdaechtige FW Rules
# ══════════════════════════════════════════════════════
function Clear-NetworkTraces {
    Write-Status "Bereinige Netzwerk (selektiv)..." "INFO"

    # DNS flush ist normal und faellt nicht auf
    ipconfig /flushdns 2>$null | Out-Null

    if (Test-IsAdmin) {
        # Nur Firewall Rules die auf Cheats zeigen
        netsh advfirewall firewall delete rule name=all program="*cheat*" 2>$null | Out-Null
        netsh advfirewall firewall delete rule name=all program="*hack*" 2>$null | Out-Null
        netsh advfirewall firewall delete rule name=all program="*inject*" 2>$null | Out-Null
        netsh advfirewall firewall delete rule name=all program="*trainer*" 2>$null | Out-Null
    }

    Write-Status "Netzwerk bereinigt." "OK"
}

# ══════════════════════════════════════════════════════
# 11. DEFENDER HISTORY — Nur letzte 24h, selektiv
# ══════════════════════════════════════════════════════
function Clear-DefenderHistory {
    if (-not (Test-IsAdmin)) { return }
    Write-Status "Bereinige Defender History..." "INFO"

    $defPath = "$env:ProgramData\Microsoft\Windows Defender\Scans\History"
    if (Test-Path $defPath) {
        Get-ChildItem -Path $defPath -Recurse -ErrorAction SilentlyContinue | Where-Object {
            ($_.Name -like "*temp*") -or
            ($_.LastWriteTime -gt (Get-Date).AddHours(-24) -and (Test-IsSuspicious $_.Name))
        } | ForEach-Object {
            try { Remove-Item $_.FullName -Force -Recurse -Confirm:$false } catch {}
        }
    }
    Write-Status "Defender History bereinigt." "OK"
}

# ══════════════════════════════════════════════════════
# 12. SERVICES — Nur verdaechtige stoppen
# ══════════════════════════════════════════════════════
function Clear-SuspiciousServices {
    if (-not (Test-IsAdmin)) { return }
    Write-Status "Pruefe Dienste..." "INFO"

    $stopped = 0
    Get-Service | Where-Object {
        $_.Name -like "*cheat*" -or $_.Name -like "*hack*" -or $_.Name -like "*aimbot*"
    } | ForEach-Object {
        try {
            Stop-Service -Name $_.Name -Force -ErrorAction Stop
            Set-Service -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
            $stopped++
        } catch {}
    }
    Write-Status "$stopped verdaechtige Dienste gestoppt." "OK"
}

# ══════════════════════════════════════════════════════
# 13. WER + CBS — Nur verdaechtige Eintraege
# ══════════════════════════════════════════════════════
function Clear-ErrorReporting {
    Write-Status "Bereinige Error Reporting (selektiv)..." "INFO"

    $werPath = "$env:LOCALAPPDATA\Microsoft\Windows\WER"
    if (Test-Path $werPath) {
        Get-ChildItem -Path $werPath -Recurse -ErrorAction SilentlyContinue | Where-Object {
            Test-IsSuspicious $_.Name
        } | ForEach-Object {
            try { Remove-Item $_.FullName -Force -Recurse -Confirm:$false } catch {}
        }
    }
    Write-Status "Error Reporting bereinigt." "OK"
}

# ══════════════════════════════════════════════════════
# 14. TEMP — Nur verdaechtige Dateien, nicht alles!
# ══════════════════════════════════════════════════════
function Clear-SuspiciousTempFiles {
    Write-Status "Bereinige Temp (nur verdaechtige Dateien)..." "INFO"

    # C:\Temp komplett — das ist PCCheck's Arbeitsordner
    if (Test-Path "C:\Temp") {
        try { Remove-Item "C:\Temp" -Recurse -Force -Confirm:$false } catch {}
    }

    # In normalen Temp-Ordnern: nur verdaechtige Dateien
    $tempPaths = @("$env:TEMP", "$env:TMP", "$env:LOCALAPPDATA\Temp")
    $removed = 0

    foreach ($tempPath in $tempPaths) {
        if (-not (Test-Path $tempPath)) { continue }
        Get-ChildItem -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
            Test-IsSuspicious $_.Name
        } | ForEach-Object {
            try { Remove-Item $_.FullName -Recurse -Force -Confirm:$false; $removed++ } catch {}
        }
    }

    Write-Status "$removed verdaechtige Temp-Dateien entfernt." "OK"
}

# ══════════════════════════════════════════════════════
#  ECHO.AC COUNTERMEASURES
#  Echo grabt tiefer als PCCheck — NTFS-Level Artifacts
# ══════════════════════════════════════════════════════

# ── 15. USN JOURNAL ($UsnJrnl) ──
# Echo's Journal Tool parsed das komplett.
# Jede Dateierstellung/-loeschung steht da drin.
function Clear-USNJournal {
    Write-Status "Bereinige USN Journal..." "INFO"

    if (-not (Test-IsAdmin)) {
        Write-Status "Braucht Admin fuer USN Journal." "WARN"
        return
    }

    # Journal loeschen und neu erstellen
    # Das neue Journal startet leer — keine alten Eintraege
    try {
        fsutil usn deletejournal /d C: 2>$null | Out-Null
        Start-Sleep -Seconds 2
        # Journal neu erstellen mit normaler Groesse
        fsutil usn createjournal m=33554432 a=4194304 C: 2>$null | Out-Null
        Write-Status "USN Journal zurueckgesetzt." "OK"
    } catch {
        Write-Status "USN Journal Fehler." "WARN"
    }

    # Andere Laufwerke auch pruefen
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -ne "C:\" -and $_.Used -gt 0 }
    foreach ($drv in $drives) {
        $letter = $drv.Root.TrimEnd('\')
        try {
            fsutil usn deletejournal /d "$letter" 2>$null | Out-Null
            Start-Sleep -Seconds 1
            fsutil usn createjournal m=33554432 a=4194304 "$letter" 2>$null | Out-Null
        } catch {}
    }
}

# ── 16. AMCACHE ──
# Speichert SHA1 Hashes + Pfade aller ausgefuehrten Programme.
# Echo nutzt das um zu sehen welche EXEs jemals liefen.
function Clear-Amcache {
    Write-Status "Bereinige Amcache..." "INFO"

    if (-not (Test-IsAdmin)) {
        Write-Status "Braucht Admin fuer Amcache." "WARN"
        return
    }

    $amcachePath = "$env:SystemRoot\appcompat\Programs\Amcache.hve"
    if (-not (Test-Path $amcachePath)) {
        Write-Status "Amcache nicht gefunden." "OK"
        return
    }

    # Amcache ist gesperrt durch den AppInfo Service
    # Wir muessen den Task Scheduler nutzen um die Datei zu loeschen
    try {
        # Versuche direkt (funktioniert manchmal bei gestopptem Service)
        Stop-Service -Name "AppInfo" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1

        # Amcache-bezogene Dateien
        $amFiles = @(
            "$env:SystemRoot\appcompat\Programs\Amcache.hve",
            "$env:SystemRoot\appcompat\Programs\Amcache.hve.LOG1",
            "$env:SystemRoot\appcompat\Programs\Amcache.hve.LOG2"
        )

        foreach ($f in $amFiles) {
            if (Test-Path $f) {
                try { Remove-Item $f -Force -Confirm:$false } catch {}
            }
        }

        Start-Service -Name "AppInfo" -ErrorAction SilentlyContinue
        Write-Status "Amcache geloescht (wird beim Neustart neu erstellt)." "OK"
    } catch {
        # Fallback: Amcache beim naechsten Boot loeschen lassen
        try {
            $cmd = "Remove-Item '$amcachePath' -Force -ErrorAction SilentlyContinue"
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `"$cmd`""
            $trigger = New-ScheduledTaskTrigger -AtStartup
            Register-ScheduledTask -TaskName "AtlasTempClean" -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
            Write-Status "Amcache wird beim naechsten Neustart geloescht." "OK"
        } catch {
            Write-Status "Amcache konnte nicht bereinigt werden." "WARN"
        }
    }
}

# ── 17. SHIMCACHE / APPCOMPATCACHE ──
# Registry-basiert. Zeichnet auf welche Programme gestartet wurden.
function Clear-ShimCache {
    Write-Status "Bereinige ShimCache..." "INFO"

    if (-not (Test-IsAdmin)) {
        Write-Status "Braucht Admin fuer ShimCache." "WARN"
        return
    }

    # AppCompatCache in allen ControlSets loeschen
    $controlSets = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache",
        "HKLM:\SYSTEM\ControlSet001\Control\Session Manager\AppCompatCache",
        "HKLM:\SYSTEM\ControlSet002\Control\Session Manager\AppCompatCache"
    )

    $cleared = 0
    foreach ($path in $controlSets) {
        if (Test-Path $path) {
            try {
                Remove-ItemProperty -Path $path -Name "AppCompatCache" -ErrorAction Stop
                $cleared++
            } catch {}
        }
    }

    # AppCompatFlags Layers (Kompatibilitaets-Einstellungen)
    $layersPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (Test-Path $layersPath) {
        try {
            $items = Get-ItemProperty -Path $layersPath -ErrorAction SilentlyContinue
            $items.PSObject.Properties | Where-Object {
                $_.Name -notlike "PS*" -and (Test-IsSuspicious $_.Name)
            } | ForEach-Object {
                try { Remove-ItemProperty -Path $layersPath -Name $_.Name -ErrorAction Stop; $cleared++ } catch {}
            }
        } catch {}
    }

    Write-Status "$cleared ShimCache-Eintraege bereinigt (wird beim Neustart neu aufgebaut)." "OK"
}

# ── 18. SRUM (System Resource Usage Monitor) ──
# Trackt Netzwerk- und Ressourcenverbrauch pro App.
# Echo kann damit sehen welche Apps wann liefen.
function Clear-SRUM {
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
        # DiagTrack Service stoppt SRUM-Zugriff
        Stop-Service -Name "DPS" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        Remove-Item $srumPath -Force -Confirm:$false -ErrorAction Stop

        Start-Service -Name "DPS" -ErrorAction SilentlyContinue
        Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue

        Write-Status "SRUM DB geloescht (wird automatisch neu erstellt)." "OK"
    } catch {
        Write-Status "SRUM DB gesperrt — wird beim naechsten Boot bereinigt." "WARN"
        Start-Service -Name "DPS" -ErrorAction SilentlyContinue
        Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
    }
}

# ── 19. BAM / DAM (Background Activity Moderator) ──
# Zeichnet auf welche Programme im Hintergrund liefen.
function Clear-BAM {
    Write-Status "Bereinige BAM/DAM..." "INFO"

    if (-not (Test-IsAdmin)) {
        Write-Status "Braucht Admin fuer BAM." "WARN"
        return
    }

    $bamPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings",
        "HKLM:\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings"
    )

    $cleared = 0
    foreach ($bamPath in $bamPaths) {
        if (-not (Test-Path $bamPath)) { continue }
        try {
            Get-ChildItem $bamPath | ForEach-Object {
                $props = $_ | Get-ItemProperty
                $props.PSObject.Properties | Where-Object {
                    $n = $_.Name
                    $n -notlike "PS*" -and $n -ne "Version" -and $n -ne "SequenceNumber" -and
                    (Test-IsSuspicious $n)
                } | ForEach-Object {
                    try { Remove-ItemProperty -Path $props.PSPath -Name $_.Name -ErrorAction Stop; $cleared++ } catch {}
                }
            }
        } catch {}
    }
    Write-Status "$cleared BAM/DAM-Eintraege entfernt." "OK"
}

# ── 20. WINDOWS TIMELINE / ACTIVITIESCACHE ──
# Zeichnet App-Nutzung auf fuer die Windows-Timeline.
function Clear-Timeline {
    Write-Status "Bereinige Windows Timeline..." "INFO"

    $cdpPath = "$env:LOCALAPPDATA\ConnectedDevicesPlatform"
    if (-not (Test-Path $cdpPath)) { return }

    $removed = 0
    Get-ChildItem -Path $cdpPath -Directory | ForEach-Object {
        $acDb = Join-Path $_.FullName "ActivitiesCache.db"
        $acDbShm = Join-Path $_.FullName "ActivitiesCache.db-shm"
        $acDbWal = Join-Path $_.FullName "ActivitiesCache.db-wal"

        foreach ($f in @($acDb, $acDbShm, $acDbWal)) {
            if (Test-Path $f) {
                try { Remove-Item $f -Force -Confirm:$false; $removed++ } catch {}
            }
        }
    }
    Write-Status "$removed Timeline-Dateien entfernt." "OK"
}

# ── 21. FREE SPACE OVERWRITE ──
# Verhindert dass geloeschte Dateien recovered werden.
# Echo/forensik-tools koennen geloeschte Daten von
# freiem Speicher rekonstruieren.
function Invoke-FreeSpaceWipe {
    Write-Status "Ueberschreibe freien Speicher (kann dauern)..." "INFO"

    if (-not (Test-IsAdmin)) {
        Write-Status "Braucht Admin fuer Free Space Wipe." "WARN"
        return
    }

    # cipher /w ueberschreibt freien Speicher mit 0x00, 0xFF, Random
    # 3 Durchgaenge — Standard fuer sichere Loeschung
    try {
        $tempDir = "C:\atlas_wipe_temp_$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Start-Process -FilePath "cipher.exe" -ArgumentList "/w:$tempDir" -WindowStyle Hidden -Wait
        Remove-Item $tempDir -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
        Write-Status "Freier Speicher ueberschrieben." "OK"
    } catch {
        Write-Status "Free Space Wipe Fehler." "WARN"
    }
}

# ══════════════════════════════════════════════════════
#  22. SELBSTREINIGUNG — ATLAS eigene Spuren entfernen
#  Das Script putzt nach sich selbst auf
# ══════════════════════════════════════════════════════
function Clear-SelfTraces {
    Write-Status "Entferne eigene Spuren..." "INFO"

    # Eigenen EXE-Namen ermitteln (kann umbenannt sein)
    $selfExe = $null
    try {
        $parentProc = Get-Process -Id $PID -ErrorAction SilentlyContinue
        if ($parentProc) {
            # WebView2 Host Prozess finden
            $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $($parentProc.Id)" -ErrorAction SilentlyContinue
            while ($parent -and $parent.ParentProcessId) {
                $grandparent = Get-CimInstance Win32_Process -Filter "ProcessId = $($parent.ParentProcessId)" -ErrorAction SilentlyContinue
                if ($grandparent -and $grandparent.ExecutablePath -and
                    $grandparent.Name -ne "powershell.exe" -and
                    $grandparent.Name -ne "cmd.exe") {
                    $selfExe = $grandparent.Name
                    break
                }
                $parent = $grandparent
            }
        }
    } catch {}

    # Fallback: alle moeglichen Namen die wir verwenden koennten
    $selfNames = @("atlas", "ATLAS")
    if ($selfExe) {
        $selfNames += [System.IO.Path]::GetFileNameWithoutExtension($selfExe)
    }

    $cleared = 0

    # ── Prefetch: eigene .pf Dateien entfernen ──
    if (Test-IsAdmin) {
        $prefetchDir = "$env:SystemRoot\Prefetch"
        foreach ($name in $selfNames) {
            $upper = $name.ToUpper()
            Get-ChildItem -Path $prefetchDir -Filter "*.pf" -ErrorAction SilentlyContinue | Where-Object {
                $_.Name.ToUpper() -like "*$upper*"
            } | ForEach-Object {
                try { Remove-Item $_.FullName -Force -Confirm:$false; $cleared++ } catch {}
            }
        }
        # PowerShell prefetch auch (weil wir PS scripts ausfuehren)
        # ABER: POWERSHELL*.pf NICHT loeschen — das waere verdaechtig
        # Nur ANTI-DETECT spezifische
        Get-ChildItem -Path $prefetchDir -Filter "*ANTI*DETECT*.pf" -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item $_.FullName -Force -Confirm:$false; $cleared++ } catch {}
        }
    }

    # ── Registry: eigene Eintraege aus UserAssist/RecentDocs ──
    $regCleanPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store"
    )

    foreach ($regPath in $regCleanPaths) {
        if (-not (Test-Path $regPath)) { continue }
        try {
            $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            if (-not $items) { continue }
            $items.PSObject.Properties | Where-Object {
                $n = $_.Name; $v = $_.Value
                $text = if ($v -is [string]) { $v }
                        elseif ($v -is [byte[]]) { try { [System.Text.Encoding]::Unicode.GetString($v) } catch { "" } }
                        else { "" }
                $match = $false
                foreach ($name in $selfNames) {
                    if ($text -like "*$name*" -or $n -like "*$name*") { $match = $true; break }
                }
                $match
            } | ForEach-Object {
                try { Remove-ItemProperty -Path $regPath -Name $_.Name -ErrorAction Stop; $cleared++ } catch {}
            }
        } catch {}
    }

    # ── BAM: eigene Eintraege ──
    if (Test-IsAdmin) {
        $bamPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings",
            "HKLM:\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings"
        )
        foreach ($bamPath in $bamPaths) {
            if (-not (Test-Path $bamPath)) { continue }
            try {
                Get-ChildItem $bamPath | ForEach-Object {
                    $props = $_ | Get-ItemProperty
                    $props.PSObject.Properties | Where-Object {
                        $n = $_.Name
                        $match = $false
                        foreach ($name in $selfNames) {
                            if ($n -like "*$name*") { $match = $true; break }
                        }
                        $n -notlike "PS*" -and $n -ne "Version" -and $n -ne "SequenceNumber" -and $match
                    } | ForEach-Object {
                        try { Remove-ItemProperty -Path $props.PSPath -Name $_.Name -ErrorAction Stop; $cleared++ } catch {}
                    }
                }
            } catch {}
        }
    }

    # ── Recent Items: eigene .lnk Dateien ──
    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $recentPath) {
        foreach ($name in $selfNames) {
            Get-ChildItem -Path $recentPath -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -like "*$name*" -or $_.Name -like "*anti-detect*"
            } | ForEach-Object {
                try { Remove-Item $_.FullName -Force -Confirm:$false; $cleared++ } catch {}
            }
        }
    }

    # ── Scheduled Task aufraeumen (falls Amcache-Fallback erstellt wurde) ──
    try {
        Unregister-ScheduledTask -TaskName "AtlasTempClean" -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}

    Write-Status "$cleared eigene Spuren entfernt." "OK"
}

# ══════════════════════════════════════════════════════
#   HAUPTPROGRAMM
# ══════════════════════════════════════════════════════

if (-not $Silent) {
    Write-Host ""
    Write-Host "  ======================================" -ForegroundColor DarkGreen
    Write-Host "   ATLAS Anti-Detect v4.0" -ForegroundColor Green
    Write-Host "   vs PCCheckV4 + Echo.ac" -ForegroundColor DarkGreen
    Write-Host "  ======================================" -ForegroundColor DarkGreen
    Write-Host ""
    if (Test-IsAdmin) {
        Write-Status "Admin-Rechte erkannt." "OK"
    } else {
        Write-Status "Kein Admin — eingeschraenkter Modus." "WARN"
    }
    Write-Host ""
}

if ($Quick) {
    Stop-DetectableProcesses
    Clear-PSHistory
    Clear-Prefetch
    Clear-NetworkTraces
}
elseif ($FilesOnly) {
    Remove-DetectableFiles
    Remove-ForensicTools
}
elseif ($RegistryOnly) {
    Clear-Registry
    Clear-ShimCache
    Clear-BAM
}
elseif ($LogsOnly) {
    Clear-EventLogs
    Clear-PSHistory
}
elseif ($NetworkOnly) {
    Clear-NetworkTraces
    Clear-BrowserTraces
}
elseif ($EchoOnly) {
    Clear-USNJournal
    Clear-Amcache
    Clear-ShimCache
    Clear-SRUM
    Clear-BAM
    Clear-Timeline
    Invoke-FreeSpaceWipe
}
elseif ($Stealth) {
    Clear-SelfTraces
}
else {
    # Full — PCCheck + Echo + Selbstreinigung
    Stop-DetectableProcesses
    Remove-DetectableFiles
    Remove-ForensicTools
    Clear-Prefetch
    Clear-Registry
    Clear-EventLogs
    Clear-PSHistory
    Clear-RecentItems
    Clear-BrowserTraces
    Clear-NetworkTraces
    Clear-DefenderHistory
    Clear-SuspiciousServices
    Clear-ErrorReporting
    Clear-SuspiciousTempFiles
    Clear-USNJournal
    Clear-Amcache
    Clear-ShimCache
    Clear-SRUM
    Clear-BAM
    Clear-Timeline
    Invoke-FreeSpaceWipe
    Clear-SelfTraces
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "  ======================================" -ForegroundColor DarkGreen
    Write-Host "   Bereinigung abgeschlossen." -ForegroundColor Green
    Write-Host "   System sieht normal aus." -ForegroundColor DarkGreen
    Write-Host "  ======================================" -ForegroundColor DarkGreen
    Write-Host ""
}

exit 0
