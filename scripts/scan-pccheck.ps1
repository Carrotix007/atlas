param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

# Scanner-Modus: nur suchen, nichts loeschen
# Ausgabe-Format:
#   [CAT] Kategorie | Anzahl
#   [ITEM] Details
# Fuer die GUI parsebar.

function Scan-Category($name, [scriptblock]$finder) {
    $items = @()
    try { $items = @(& $finder) } catch { $items = @() }
    [Console]::WriteLine("[CAT] $name | $($items.Count)")
    foreach ($item in $items) {
        [Console]::WriteLine("[ITEM] $item")
    }
}

Scan-Category "Laufende Prozesse" {
    Get-Process | Where-Object { Test-IsSuspicious $_.ProcessName } | ForEach-Object {
        "$($_.ProcessName) (PID $($_.Id))"
    }
    $specific = @("x64dbg", "x32dbg", "ollydbg", "dnspy", "dnSpy", "SystemInformer", "autohotkey")
    foreach ($n in $specific) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
            "$($_.ProcessName) (PID $($_.Id))"
        }
    }
}

Scan-Category "Prefetch-Dateien" {
    if (Test-IsAdmin) {
        Get-ChildItem -Path "$env:SystemRoot\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue |
            Where-Object { Test-IsSuspicious $_.Name } | ForEach-Object { $_.Name }
    }
}

Scan-Category "Verdaechtige Dateien" {
    $paths = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        Get-ChildItem -Path $p -Force -ErrorAction SilentlyContinue |
            Where-Object { Test-IsSuspicious $_.Name } | ForEach-Object { $_.FullName }
    }
    foreach ($p in $paths) {
        Get-ChildItem -Path $p -Filter "*.ct" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    }
}

Scan-Category "Bekannte Cheat-Ordner" {
    $known = @(
        "$env:APPDATA\Cheat Engine*", "$env:LOCALAPPDATA\Cheat Engine*",
        "$env:APPDATA\WeMod*", "$env:LOCALAPPDATA\WeMod*",
        "$env:APPDATA\2Take1*", "$env:APPDATA\Stand*",
        "$env:APPDATA\Cherax*", "$env:APPDATA\Kiddions*",
        "$env:APPDATA\YimMenu*", "$env:APPDATA\Modest*Menu*"
    )
    foreach ($k in $known) {
        Get-Item -Path $k -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    }
}

Scan-Category "Registry (RecentDocs / TypedPaths / RunMRU)" {
    $regPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
    )
    foreach ($p in $regPaths) {
        if (-not (Test-Path $p)) { continue }
        $items = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
        if (-not $items) { continue }
        $items.PSObject.Properties | Where-Object {
            $n = $_.Name; $v = $_.Value
            if ($n -like "PS*") { return $false }
            $text = if ($v -is [string]) { $v }
                    elseif ($v -is [byte[]]) { try { [System.Text.Encoding]::Unicode.GetString($v) } catch { "" } }
                    else { "" }
            Test-IsSuspiciousText $text
        } | ForEach-Object { "$p :: $($_.Name)" }
    }
}

Scan-Category "Cheat-Registry-Keys" {
    $keys = @(
        "HKCU:\Software\Cheat Engine",
        "HKCU:\Software\cheatengine.org",
        "HKLM:\SOFTWARE\Cheat Engine",
        "HKCU:\Software\WeMod"
    )
    foreach ($k in $keys) {
        if (Test-Path $k) { $k }
    }
}

Scan-Category "Recent Items (.lnk)" {
    $rp = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $rp) {
        Get-ChildItem -Path $rp -ErrorAction SilentlyContinue | Where-Object {
            $n = $_.Name.ToLower()
            $n -like "*.ps1.lnk" -or (Test-IsSuspicious $_.Name)
        } | ForEach-Object { $_.Name }
    }
}

Scan-Category "BAM/DAM Eintraege" {
    if (Test-IsAdmin) {
        $bamPaths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings",
            "HKLM:\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings"
        )
        foreach ($bp in $bamPaths) {
            if (-not (Test-Path $bp)) { continue }
            Get-ChildItem $bp -ErrorAction SilentlyContinue | ForEach-Object {
                $props = $_ | Get-ItemProperty
                $props.PSObject.Properties | Where-Object {
                    $_.Name -notlike "PS*" -and $_.Name -ne "Version" -and $_.Name -ne "SequenceNumber" -and (Test-IsSuspicious $_.Name)
                } | ForEach-Object { $_.Name }
            }
        }
    }
}

Scan-Category "PowerShell History (verdaechtige Zeilen)" {
    $hp = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    if (Test-Path $hp) {
        Get-Content $hp -ErrorAction SilentlyContinue | Where-Object {
            Test-IsSuspiciousText $_
        } | ForEach-Object { $_ }
    }
}

Scan-Category "Forensik-Tools installiert" {
    $tools = @("csvfileview", "timelineexplorer", "registryexplorer", "winprefetchview", "pccheck",
               "autoruns", "stringexplorer", "moss", "usbdeview", "savedfilesviewer",
               "srumexplorer", "powershellparser", "pathsparser", "mftexplorer",
               "kernellivedump", "journaltrace", "crashedfileviewer",
               "browsinghistoryview", "browserdownloadsview", "bamparser", "amcacheparser")
    $paths = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:LOCALAPPDATA", "C:\Temp")
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        foreach ($t in $tools) {
            Get-ChildItem -Path $p -Filter "*$t*" -Recurse -Force -ErrorAction SilentlyContinue |
                Select-Object -First 5 | ForEach-Object { $_.FullName }
        }
    }
}

# ══════════════════════════════════════════════════════
#  detect.ac Checks
# ══════════════════════════════════════════════════════

Scan-Category "Autostart-Eintraege (Registry Run-Keys)" {
    $runKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($rk in $runKeys) {
        if (-not (Test-Path $rk)) { continue }
        $items = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
        if (-not $items) { continue }
        $items.PSObject.Properties | Where-Object {
            $n = $_.Name; $v = $_.Value
            if ($n -like "PS*") { return $false }
            (Test-IsSuspicious $n) -or (Test-IsSuspiciousText "$v")
        } | ForEach-Object { "$rk :: $($_.Name) = $($_.Value)" }
    }
}

Scan-Category "Autostart-Ordner (.lnk / .exe)" {
    $startupDirs = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Startup"
    )
    foreach ($sd in $startupDirs) {
        if (-not (Test-Path $sd)) { continue }
        Get-ChildItem -Path $sd -Force -ErrorAction SilentlyContinue | Where-Object {
            Test-IsSuspicious $_.Name
        } | ForEach-Object { $_.FullName }
    }
}

Scan-Category "Scheduled Tasks (verdaechtig)" {
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
            (Test-IsSuspicious $_.TaskName) -or
            ($_.Actions | ForEach-Object { $_.Execute } | Where-Object { $_ -and (Test-IsSuspicious $_) })
        } | ForEach-Object { "$($_.TaskPath)$($_.TaskName)" }
    } catch {}
}

Scan-Category "USB-Devices (letzte 24h)" {
    if (-not (Test-IsAdmin)) { return }
    $cutoff = (Get-Date).AddHours(-24).ToFileTime()
    $usbStorPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
    if (Test-Path $usbStorPath) {
        Get-ChildItem $usbStorPath -ErrorAction SilentlyContinue | ForEach-Object {
            $devClass = $_.PSChildName
            Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $propPath = Join-Path $_.PSPath "Properties\{83da6326-97a6-4088-9453-a1923f573b29}\0064"
                    if (Test-Path $propPath) {
                        $ts = (Get-ItemProperty $propPath -ErrorAction SilentlyContinue).'(default)'
                        if ($ts -and $ts -gt $cutoff) {
                            "$devClass\$($_.PSChildName)"
                        }
                    }
                } catch {}
            }
        }
    }
}

Scan-Category "Crash Dumps (verdaechtig)" {
    $dumpDirs = @(
        "$env:LOCALAPPDATA\CrashDumps",
        "$env:SystemRoot\Minidump",
        "$env:SystemRoot\LiveKernelReports",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue",
        "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportArchive"
    )
    foreach ($dd in $dumpDirs) {
        if (-not (Test-Path $dd)) { continue }
        Get-ChildItem -Path $dd -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
            Test-IsSuspicious $_.Name
        } | Select-Object -First 20 | ForEach-Object { $_.FullName }
    }
}

Scan-Category "UserAssist (ausgefuehrte Programme, ROT13-decoded)" {
    function ConvertFrom-Rot13Scan([string]$text) {
        if (-not $text) { return "" }
        $sb = New-Object System.Text.StringBuilder
        foreach ($c in $text.ToCharArray()) {
            $code = [int]$c
            if ($c -cmatch '[A-M]') { [void]$sb.Append([char]($code + 13)) }
            elseif ($c -cmatch '[N-Z]') { [void]$sb.Append([char]($code - 13)) }
            elseif ($c -cmatch '[a-m]') { [void]$sb.Append([char]($code + 13)) }
            elseif ($c -cmatch '[n-z]') { [void]$sb.Append([char]($code - 13)) }
            else { [void]$sb.Append($c) }
        }
        return $sb.ToString()
    }
    $uaBase = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
    if (-not (Test-Path $uaBase)) { return }
    Get-ChildItem $uaBase -ErrorAction SilentlyContinue | ForEach-Object {
        $countPath = Join-Path $_.PSPath "Count"
        if (Test-Path $countPath) {
            $items = Get-ItemProperty -Path $countPath -ErrorAction SilentlyContinue
            if (-not $items) { return }
            $items.PSObject.Properties | Where-Object {
                if ($_.Name -like "PS*") { return $false }
                $decoded = ConvertFrom-Rot13Scan $_.Name
                if (Test-IsPathWhitelisted $decoded) { return $false }
                (Test-IsSuspicious $decoded) -or (Test-IsSuspiciousText $decoded)
            } | ForEach-Object { ConvertFrom-Rot13Scan $_.Name }
        }
    }
}

Scan-Category "MUICache (Programm-Anzeigenamen)" {
    $muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
    if (-not (Test-Path $muiPath)) { return }
    $items = Get-ItemProperty -Path $muiPath -ErrorAction SilentlyContinue
    if (-not $items) { return }
    $items.PSObject.Properties | Where-Object {
        $n = $_.Name; $v = $_.Value
        if ($n -like "PS*") { return $false }
        # Name-Key ist oft ein Pfad (C:\...\foo.exe.FriendlyAppName) - Path-Whitelist checken
        if (Test-IsPathWhitelisted $n) { return $false }
        (Test-IsSuspicious $n) -or (Test-IsSuspiciousText "$v")
    } | ForEach-Object { "$($_.Name) = $($_.Value)" }
}

Scan-Category "Loaded DLLs in laufenden Prozessen" {
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        $procName = $_.ProcessName
        try {
            $_.Modules | Where-Object {
                $_.ModuleName -and (Test-IsSuspiciousFile $_.ModuleName $_.FileName)
            } | ForEach-Object {
                "$procName laedt $($_.ModuleName)"
            }
        } catch {}
    }
}

Scan-Category "Windows Firewall Rules (verdaechtige Programme)" {
    if (-not (Test-IsAdmin)) { return }
    try {
        Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue | Where-Object {
            $_.Program -and (Test-IsSuspicious $_.Program)
        } | ForEach-Object { $_.Program }
    } catch {}
}

Scan-Category "Shell Bags (Explorer-Ordner-Historie)" {
    # Wir koennen binary shell bags nicht 100% parsen, aber wir zaehlen einfach
    # wie viele Bag-Eintraege existieren. Viele Eintraege = viel Historie.
    $bagsPath = "HKCU:\Software\Microsoft\Windows\Shell\BagMRU"
    if (Test-Path $bagsPath) {
        $count = 0
        try {
            Get-ChildItem $bagsPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $count++ }
        } catch {}
        if ($count -gt 0) {
            "$count BagMRU-Eintraege vorhanden (Explorer merkt sich geoeffnete Ordner)"
        }
    }
}

Scan-Category "RDP-Client History" {
    $defPath = "HKCU:\Software\Microsoft\Terminal Server Client\Default"
    if (Test-Path $defPath) {
        $items = Get-ItemProperty -Path $defPath -ErrorAction SilentlyContinue
        if ($items) {
            $items.PSObject.Properties | Where-Object {
                $_.Name -like "MRU*" -and $_.Value
            } | ForEach-Object { "MRU :: $($_.Value)" }
        }
    }
    $srvPath = "HKCU:\Software\Microsoft\Terminal Server Client\Servers"
    if (Test-Path $srvPath) {
        Get-ChildItem $srvPath -ErrorAction SilentlyContinue | ForEach-Object { "Server :: $($_.PSChildName)" }
    }
}

Scan-Category "Jump Lists (Taskbar Recent Files)" {
    $paths = @(
        "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations",
        "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
    )
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        Get-ChildItem $p -File -ErrorAction SilentlyContinue | Where-Object {
            Test-IsSuspicious $_.Name
        } | ForEach-Object { $_.Name }
    }
}

Scan-Category "File-Dialog MRUs (Oeffnen/Speichern)" {
    $comDlgBase = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32"
    $lastVisited = "$comDlgBase\LastVisitedPidlMRU"
    if (Test-Path $lastVisited) {
        try {
            $items = Get-ItemProperty -Path $lastVisited -ErrorAction SilentlyContinue
            $count = ($items.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" }).Count
            if ($count -gt 0) { "LastVisited: $count Ordner" }
        } catch {}
    }
    $openSave = "$comDlgBase\OpenSavePidlMRU"
    if (Test-Path $openSave) {
        Get-ChildItem $openSave -ErrorAction SilentlyContinue | ForEach-Object {
            "OpenSave: .$($_.PSChildName)"
        }
    }
}

Scan-Category "Windows Search History (WordWheelQuery)" {
    $wwq = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery"
    if (Test-Path $wwq) {
        try {
            $items = Get-ItemProperty -Path $wwq -ErrorAction SilentlyContinue
            if ($items) {
                $items.PSObject.Properties | Where-Object {
                    $_.Name -match '^\d+$'
                } | ForEach-Object {
                    # Value ist UTF-16LE byte array
                    try {
                        $bytes = [byte[]]$_.Value
                        $text = [System.Text.Encoding]::Unicode.GetString($bytes).TrimEnd([char]0)
                        if (Test-IsSuspiciousText $text) { "Search: $text" }
                    } catch {}
                }
            }
        } catch {}
    }
}

Scan-Category "RecentApps (Search)" {
    $ra = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\RecentApps"
    if (Test-Path $ra) {
        Get-ChildItem $ra -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $p = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).AppPath
                if ($p -and -not (Test-IsPathWhitelisted $p) -and (Test-IsSuspicious $p)) {
                    $p
                }
            } catch {}
        }
    }
}

Scan-Category "Notification History" {
    $wpnDb = "$env:LOCALAPPDATA\Microsoft\Windows\Notifications\wpndatabase.db"
    if (Test-Path $wpnDb) {
        $size = (Get-Item $wpnDb -ErrorAction SilentlyContinue).Length
        if ($size -gt 0) { "wpndatabase.db vorhanden ($([math]::Round($size/1KB)) KB)" }
    }
}

Scan-Category "Boot-Start Kernel Driver (verdaechtig)" {
    # Driver mit StartType=Boot oder System laden vor Anti-Cheat
    # Kernel-Cheats verstecken sich hier
    try {
        Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | Where-Object {
            ($_.StartMode -eq 'Boot' -or $_.StartMode -eq 'System') -and
            $_.PathName -and
            -not (Test-IsPathWhitelisted $_.PathName) -and
            ((Test-IsSuspicious $_.Name) -or (Test-IsSuspicious ([System.IO.Path]::GetFileName($_.PathName))))
        } | ForEach-Object { "$($_.StartMode) :: $($_.Name) ($($_.PathName))" }
    } catch {}
}

Scan-Category "Session Manager BootExecute" {
    # Programme die vor Login/Shell ausgefuehrt werden
    $smPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    if (Test-Path $smPath) {
        try {
            $sm = Get-ItemProperty -Path $smPath -ErrorAction SilentlyContinue
            $normal = @("autocheck autochk *", "autocheck autochk /r *")
            foreach ($cmd in $sm.BootExecute) {
                if ($cmd -and $cmd -notin $normal) {
                    "BootExecute :: $cmd"
                }
            }
        } catch {}
    }
}

Scan-Category "Winlogon Konfiguration (Userinit/Shell)" {
    $wl = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    if (Test-Path $wl) {
        try {
            $p = Get-ItemProperty -Path $wl -ErrorAction SilentlyContinue
            $defaults = @{
                "Userinit" = "C:\Windows\system32\userinit.exe,"
                "Shell"    = "explorer.exe"
                "Taskman"  = ""
                "AppSetup" = ""
            }
            foreach ($key in $defaults.Keys) {
                $val = "$($p.$key)".Trim()
                if ($val -and $val -ne $defaults[$key]) {
                    "Winlogon\$key = $val (Default waere: '$($defaults[$key])')"
                }
            }
        } catch {}
    }
}

Scan-Category "Image File Execution Options (Debugger-Hijack)" {
    # Wenn ein Programm hier einen "Debugger" Value hat, wird das Debugger-Prog
    # anstatt des Originals gestartet. Klassischer Cheat/Malware-Trick.
    $ifeo = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
    if (Test-Path $ifeo) {
        Get-ChildItem $ifeo -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $dbg = (Get-ItemProperty $_.PSPath -Name "Debugger" -ErrorAction SilentlyContinue).Debugger
                if ($dbg) { "$($_.PSChildName) -> Debugger: $dbg" }
            } catch {}
        }
    }
}

Scan-Category "BCD Boot-Konfiguration (bcdedit)" {
    try {
        $out = & bcdedit /enum osloader 2>&1
        if ($LASTEXITCODE -eq 0) {
            # Ausgabe parsen: nur non-standard Eintraege interessant
            $foundKernel = $false
            $foundHal = $false
            foreach ($line in $out) {
                if ($line -match '^kernel\s+(.+)$') {
                    $foundKernel = $true
                    $k = $matches[1].Trim()
                    if ($k -ne "ntoskrnl.exe") { "kernel = $k (Default: ntoskrnl.exe)" }
                }
                if ($line -match '^hal\s+(.+)$') {
                    $foundHal = $true
                    $h = $matches[1].Trim()
                    if ($h -ne "hal.dll") { "hal = $h (Default: hal.dll)" }
                }
                if ($line -match '^testsigning\s+Yes') {
                    "testsigning ist AN (unsignierte Driver erlaubt - Cheat-Risk!)"
                }
                if ($line -match '^nointegritychecks\s+Yes') {
                    "nointegritychecks ist AN (Integritaets-Check aus - Cheat-Risk!)"
                }
                if ($line -match '^debug\s+Yes') {
                    "kernel debug ist AN"
                }
            }
        }
    } catch {}
}

Scan-Category "PCA Logs (Program Compatibility Assistant)" {
    # PCA loggt besonders unsigned/non-certified EXEs - Cheat-Goldmine!
    $pcaFiles = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\PCA\PcaAppLaunchDic.txt",
        "$env:LOCALAPPDATA\Microsoft\Windows\PCA\PcaGeneralDb0.txt",
        "$env:LOCALAPPDATA\Microsoft\Windows\PCA\PcaGeneralDb1.txt"
    )
    foreach ($file in $pcaFiles) {
        if (-not (Test-Path $file)) { continue }
        try {
            Get-Content $file -ErrorAction SilentlyContinue -Encoding UTF8 | Where-Object {
                -not (Test-IsPathWhitelisted $_) -and (Test-IsSuspiciousText $_)
            } | ForEach-Object { "$(Split-Path $file -Leaf) :: $_" }
        } catch {}
    }
}

Scan-Category "Amcache (SHA1-Hash + Pfade aller je ausgefuehrten EXEs)" {
    if (-not (Test-IsAdmin)) { return }
    # Amcache via Volume Shadow Copy lesen (kein Service-Stop noetig, safer als reg load)
    $tmpHive = Join-Path $env:TEMP "amcache_scan_$(Get-Random).hve"
    $mounted = $false
    try {
        # Kopiere Hive per VSS - AppInfo lock wird umgangen
        $vssOut = & esentutl /y /vss "C:\Windows\appcompat\Programs\Amcache.hve" /d "$tmpHive" 2>&1
        if (-not (Test-Path $tmpHive)) { return }

        # Mount als temporaere Registry-Hive
        $mountKey = "AMCACHE_SCAN"
        & reg load "HKLM\$mountKey" "$tmpHive" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { return }
        $mounted = $true

        $mountPs = "HKLM:\$mountKey"
        $checkPaths = @(
            "$mountPs\Root\InventoryApplicationFile",
            "$mountPs\Root\InventoryApplication",
            "$mountPs\Root\File"
        )

        foreach ($cp in $checkPaths) {
            if (-not (Test-Path $cp)) { continue }
            Get-ChildItem $cp -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    $matchedField = $null
                    foreach ($prop in @("LowerCaseLongPath", "Name", "OriginalFileName")) {
                        $val = $p.$prop
                        if ($val -and -not (Test-IsPathWhitelisted $val) -and (Test-IsSuspicious $val)) {
                            $matchedField = "$prop=$val"
                            break
                        }
                    }
                    if ($matchedField) { $matchedField }
                } catch {}
            }
        }
    } catch {} finally {
        if ($mounted) {
            [GC]::Collect()
            & reg unload "HKLM\$mountKey" 2>&1 | Out-Null
        }
        if (Test-Path $tmpHive) { Remove-Item $tmpHive -Force -ErrorAction SilentlyContinue }
    }
}

Scan-Category "SRUM DB (Resource-Usage pro EXE)" {
    if (-not (Test-IsAdmin)) { return }
    $srumPath = "$env:SystemRoot\System32\sru\SRUDB.dat"
    if (Test-Path $srumPath) {
        $info = Get-Item $srumPath -ErrorAction SilentlyContinue
        $sizeMB = [math]::Round($info.Length / 1MB, 2)
        $age = ((Get-Date) - $info.CreationTime).Days
        "SRUDB.dat vorhanden - $sizeMB MB, $age Tage alt (trackt Network/CPU/Disk pro Prozess)"
    }
}

Scan-Category "Cloud-Drive Logs (Google Drive / OneDrive / Dropbox)" {
    $sources = @{
        "Google DriveFS" = "$env:LOCALAPPDATA\Google\DriveFS\logs"
        "OneDrive"       = "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"
        "Dropbox"        = "$env:LOCALAPPDATA\Dropbox\instance1\logs"
    }
    foreach ($src in $sources.GetEnumerator()) {
        if (-not (Test-Path $src.Value)) { continue }
        try {
            Get-ChildItem $src.Value -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
                $_.Extension -in @(".log", ".txt", ".json")
            } | Select-Object -First 50 | ForEach-Object {
                $file = $_
                # Pre-Check: hat Datei ueberhaupt Cheat-Keywords? (Bulk-Match, sehr schnell)
                $hasContent = Select-String -Path $file.FullName -Pattern $SUSPECT_KEYWORDS -SimpleMatch -Quiet -ErrorAction SilentlyContinue
                if (-not $hasContent) { return }
                # Nur wenn Pre-Check hit: strikt zeilenweise pruefen
                $count = 0
                try {
                    Get-Content $file.FullName -ErrorAction Stop | ForEach-Object {
                        if ((Test-IsSuspiciousText $_) -and -not (Test-IsPathWhitelisted $_)) {
                            $count++
                        }
                    }
                } catch {}
                if ($count -gt 0) {
                    "$($src.Key) - $($file.Name): $count verdaechtige Zeilen"
                }
            }
        } catch {}
    }
}

Scan-Category "Vulnerable Kernel Drivers (Ocean/Echo prueft darauf)" {
    if (-not (Test-IsAdmin)) { return }
    # Bekannte "vulnerable" oder cheat-related drivers
    # PROCEXP152 = Process Explorer, KProcessHacker = ProcessHacker
    # EchoDrv = Echo AC's eigener USB detector - kann als attack vector genutzt werden
    $badDrivers = @(
        "procexp152", "procexp", "processhacker", "kprocesshacker",
        "kprocesshacker2", "echodrv", "capcom", "gdrv", "atillk",
        "rtkio", "rtkiow10x64", "asupgrade", "dbutil"
    )
    try {
        Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue | Where-Object {
            $n = $_.Name.ToLower()
            $bad = $false
            foreach ($b in $badDrivers) { if ($n -like "*$b*") { $bad = $true; break } }
            $bad
        } | ForEach-Object {
            "$($_.Name) ($($_.State)) :: $($_.PathName)"
        }
    } catch {}
}

Scan-Category "Scanner-Artefakte (Echo AC / Ocean Temp-Files)" {
    $tempRoots = @($env:TEMP, "$env:LOCALAPPDATA\Temp")
    foreach ($tr in $tempRoots) {
        if (-not (Test-Path $tr)) { continue }
        # Echo folders
        Get-ChildItem -Path $tr -Directory -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match '^echo\d+$'
        } | ForEach-Object { "Echo AC :: $($_.FullName)" }

        # Ocean spezifische Files
        $oceanFiles = @("a3.exe", "xxstrings64-Ocean.exe", "ntfsDump", "temp.bin", "avast.db")
        foreach ($of in $oceanFiles) {
            Get-ChildItem -Path $tr -Filter $of -Recurse -ErrorAction SilentlyContinue -File |
                Select-Object -First 3 | ForEach-Object { "Ocean-File :: $($_.FullName)" }
        }
    }
}

Scan-Category "Recycle Bin (verdaechtige Dateien)" {
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycle = $shell.NameSpace(0xA)
        if ($recycle) {
            $recycle.Items() | Where-Object {
                Test-IsSuspicious $_.Name
            } | ForEach-Object { $_.Name }
        }
    } catch {}
}

[Console]::WriteLine("[OK] Scan abgeschlossen.")
