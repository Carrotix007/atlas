param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Entferne eigene Spuren..." "INFO"

$selfExe = $null
try {
    $parentProc = Get-Process -Id $PID -ErrorAction SilentlyContinue
    if ($parentProc) {
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

$selfNames = @("atlas", "ATLAS")
if ($selfExe) {
    $selfNames += [System.IO.Path]::GetFileNameWithoutExtension($selfExe)
}

$cleared = 0

# Prefetch: eigene .pf Dateien
if (Test-IsAdmin) {
    $prefetchDir = "$env:SystemRoot\Prefetch"
    foreach ($name in $selfNames) {
        $upper = $name.ToUpper()
        Get-ChildItem -Path $prefetchDir -Filter "*.pf" -ErrorAction SilentlyContinue | Where-Object {
            $_.Name.ToUpper() -like "*$upper*"
        } | ForEach-Object {
            try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $cleared++ } catch {}
        }
    }
    Get-ChildItem -Path $prefetchDir -Filter "*ANTI*DETECT*.pf" -ErrorAction SilentlyContinue | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $cleared++ } catch {}
    }
}

# Registry: eigene Eintraege
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
                    elseif ($v -is [byte[]]) {
                        try { [System.Text.Encoding]::Unicode.GetString($v) } catch { "" }
                    } else { "" }
            $match = $false
            foreach ($name in $selfNames) {
                if ($text -like "*$name*" -or $n -like "*$name*") { $match = $true; break }
            }
            $match
        } | ForEach-Object {
            try { $n = $_.Name; Remove-ItemProperty -Path $regPath -Name $n -ErrorAction Stop; Write-Detail "$regPath :: $n"; $cleared++ } catch {}
        }
    } catch {}
}

# BAM: eigene Eintraege
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
                    try { $n = $_.Name; Remove-ItemProperty -Path $props.PSPath -Name $n -ErrorAction Stop; Write-Detail "BAM :: $n"; $cleared++ } catch {}
                }
            }
        } catch {}
    }
}

# Recent Items: eigene .lnk Dateien
$recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
if (Test-Path $recentPath) {
    foreach ($name in $selfNames) {
        Get-ChildItem -Path $recentPath -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like "*$name*" -or $_.Name -like "*anti-detect*"
        } | ForEach-Object {
            try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $cleared++ } catch {}
        }
    }
}

# UserAssist - eigene Programm-Ausfuehrung tracking (ROT13-decoded)
function ConvertFrom-Rot13Self([string]$text) {
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
if (Test-Path $uaBase) {
    Get-ChildItem $uaBase -ErrorAction SilentlyContinue | ForEach-Object {
        $countPath = Join-Path $_.PSPath "Count"
        if (-not (Test-Path $countPath)) { return }
        try {
            $items = Get-ItemProperty -Path $countPath -ErrorAction SilentlyContinue
            if (-not $items) { return }
            $items.PSObject.Properties | Where-Object {
                if ($_.Name -like "PS*") { return $false }
                $decoded = ConvertFrom-Rot13Self $_.Name
                $match = $false
                foreach ($name in $selfNames) {
                    if ($decoded -like "*$name*") { $match = $true; break }
                }
                $match
            } | ForEach-Object {
                try {
                    $n = $_.Name
                    $dec = ConvertFrom-Rot13Self $n
                    Remove-ItemProperty -Path $countPath -Name $n -ErrorAction Stop
                    Write-Detail "UserAssist :: $dec"
                    $cleared++
                } catch {}
            }
        } catch {}
    }
}

# MUICache - Anzeigenamen der eigenen EXE
$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
if (Test-Path $muiPath) {
    try {
        $items = Get-ItemProperty -Path $muiPath -ErrorAction SilentlyContinue
        if ($items) {
            $items.PSObject.Properties | Where-Object {
                if ($_.Name -like "PS*") { return $false }
                $match = $false
                foreach ($name in $selfNames) {
                    if ($_.Name -like "*$name*") { $match = $true; break }
                }
                $match
            } | ForEach-Object {
                try {
                    $n = $_.Name
                    Remove-ItemProperty -Path $muiPath -Name $n -ErrorAction Stop
                    Write-Detail "MUICache :: $n"
                    $cleared++
                } catch {}
            }
        }
    } catch {}
}

# RecentApps - Search "kuerzlich geoeffnete Apps"
$recentApps = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\RecentApps"
if (Test-Path $recentApps) {
    Get-ChildItem $recentApps -ErrorAction SilentlyContinue | Where-Object {
        try {
            $p = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).AppPath
            if (-not $p) { return $false }
            $match = $false
            foreach ($name in $selfNames) {
                if ($p -like "*$name*") { $match = $true; break }
            }
            $match
        } catch { $false }
    } | ForEach-Object {
        try {
            $p = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).AppPath
            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction Stop
            Write-Detail "RecentApps :: $p"
            $cleared++
        } catch {}
    }
}

# PCA Log-Files (Win11) - Zeilen mit self-Name entfernen
$pcaFiles = @(
    "$env:LOCALAPPDATA\Microsoft\Windows\PCA\PcaAppLaunchDic.txt",
    "$env:LOCALAPPDATA\Microsoft\Windows\PCA\PcaGeneralDb0.txt",
    "$env:LOCALAPPDATA\Microsoft\Windows\PCA\PcaGeneralDb1.txt"
)
foreach ($f in $pcaFiles) {
    if (-not (Test-Path $f)) { continue }
    try {
        $lines = Get-Content $f -ErrorAction Stop -Encoding UTF8
        if (-not $lines) { continue }
        $keep = @()
        $rm = 0
        foreach ($line in $lines) {
            $skip = $false
            foreach ($name in $selfNames) {
                if ($line -like "*$name*") { $skip = $true; break }
            }
            if ($skip) { $rm++ } else { $keep += $line }
        }
        if ($rm -gt 0) {
            $keep | Set-Content $f -Force -Encoding UTF8
            Write-Detail "PCA :: $(Split-Path $f -Leaf) ($rm Zeilen)"
            $cleared += $rm
        }
    } catch {}
}

# Event Logs (PCA/Program-Compatibility) - Fast pre-check
# Skippt Logs die leer sind oder sich nicht mit ATLAS-Name im Message-Feld befassen
if (Test-IsAdmin) {
    $eventLogs = @(
        "Microsoft-Windows-Application-Experience/Program-Compatibility-Assistant",
        "Microsoft-Windows-Application-Experience/Program-Inventory"
    )
    foreach ($log in $eventLogs) {
        try {
            $info = Get-WinEvent -ListLog $log -ErrorAction SilentlyContinue
            if (-not $info -or $info.RecordCount -eq 0) { continue }

            # Nur letzte 50 events checken (aktuelle Session)
            $events = Get-WinEvent -LogName $log -MaxEvents 50 -ErrorAction SilentlyContinue
            if (-not $events) { continue }
            $foundSelf = $false
            foreach ($e in $events) {
                if (-not $e.Message) { continue }
                foreach ($name in $selfNames) {
                    if ($e.Message -like "*$name*") { $foundSelf = $true; break }
                }
                if ($foundSelf) { break }
            }
            if ($foundSelf) {
                wevtutil cl $log 2>$null
                Write-Detail "EventLog :: $log"
                $cleared++
            }
        } catch {}
    }
}

# Scheduled Task
try {
    Unregister-ScheduledTask -TaskName "AtlasTempClean" -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

Write-Status "$cleared eigene Spuren entfernt." "OK"
