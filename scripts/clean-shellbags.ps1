param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Reset Shell Bags (Explorer-Ordner-Historie)..." "INFO"
Write-Status "ACHTUNG: Aggressiv - reset ALLE Ordner-View-Settings des Explorers!" "WARN"

# Shell Bags speichern welche Ordner du wann geoeffnet hast + View-Settings
# Binary format, nicht surgical loeschbar - nur komplett reset
# Wird von Windows automatisch beim naechsten Explorer-Nutzen neu aufgebaut
$paths = @(
    "HKCU:\Software\Microsoft\Windows\Shell\Bags",
    "HKCU:\Software\Microsoft\Windows\Shell\BagMRU",
    "HKCU:\Software\Microsoft\Windows\ShellNoRoam\Bags",
    "HKCU:\Software\Microsoft\Windows\ShellNoRoam\BagMRU",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags",
    "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU"
)

$cleared = 0
foreach ($p in $paths) {
    if (Test-Path $p) {
        try {
            Remove-Item $p -Recurse -Force -ErrorAction Stop
            Write-Detail "$p"
            $cleared++
        } catch {}
    }
}

Write-Status "$cleared Shell Bag Paths zurueckgesetzt." "OK"
