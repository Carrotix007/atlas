param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige USB-Device-Historie..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer USB-Cleanup." "WARN"
    return
}

# Achtung: kompletter Reset ist verdaechtig fuer forensische Tools
# Wir loeschen nur Eintraege der letzten 24h (typischer Zeitraum fuer Cheat-Transfer)
$cutoff = (Get-Date).AddHours(-24)
$cleared = 0

# USBSTOR - jedes je angeschlossene USB-Storage-Device
$usbStorPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
if (Test-Path $usbStorPath) {
    try {
        Get-ChildItem $usbStorPath -ErrorAction SilentlyContinue | ForEach-Object {
            $devClass = $_
            Get-ChildItem $devClass.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                $dev = $_
                # Property "0064" ist letzter Connect-Timestamp (nur Win10+)
                try {
                    $propPath = Join-Path $dev.PSPath "Properties\{83da6326-97a6-4088-9453-a1923f573b29}\0064"
                    if (Test-Path $propPath) {
                        $ts = (Get-ItemProperty $propPath -ErrorAction SilentlyContinue).'(default)'
                        if ($ts -and $ts -gt $cutoff.ToFileTime()) {
                            $devId = $dev.PSChildName
                            Remove-Item $dev.PSPath -Recurse -Force -ErrorAction Stop
                            Write-Detail "USBSTOR :: $($devClass.PSChildName)\$devId"
                            $cleared++
                        }
                    }
                } catch {}
            }
        }
    } catch {}
}

# MountPoints2 - User-spezifische Mount Points
$mp2Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2"
if (Test-Path $mp2Path) {
    try {
        Get-ChildItem $mp2Path -ErrorAction SilentlyContinue | Where-Object {
            $_.PSChildName -like "{*}" -and $_.LastWriteTime -gt $cutoff
        } | ForEach-Object {
            try {
                $n = $_.PSChildName
                Remove-Item $_.PSPath -Recurse -Force -ErrorAction Stop
                Write-Detail "MountPoints2 :: $n"
                $cleared++
            } catch {}
        }
    } catch {}
}

# setupapi.dev.log - Device-Installation-Log
$setupLog = "$env:SystemRoot\INF\setupapi.dev.log"
if (Test-Path $setupLog) {
    try {
        $lines = Get-Content $setupLog -ErrorAction Stop
        $keep = @()
        $skip = $false
        $removed = 0
        foreach ($line in $lines) {
            # Sections beginnen mit ">>>"
            if ($line -like ">>>*") {
                $skip = $false
                # Wenn Section-Header ein USB-Device betrifft und aktuell ist
                if ($line -match "USB" -or $line -match "USBSTOR") {
                    # Simpler Ansatz: skippe naechste ~20 Zeilen wenn USB
                    $skip = $true
                    $removed++
                    continue
                }
            }
            if (-not $skip) { $keep += $line }
        }
        if ($removed -gt 0) {
            $keep | Set-Content $setupLog -Force -Encoding UTF8
            Write-Detail "setupapi.dev.log :: $removed USB-Sektionen entfernt"
            $cleared += $removed
        }
    } catch {}
}

Write-Status "$cleared USB-Historie-Eintraege bereinigt (nur letzte 24h)." "OK"
Write-Status "Kompletter USB-Reset waere fuer forensische Tools verdaechtig." "INFO"
