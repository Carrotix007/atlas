param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige File-Dialog MRUs (nur Cheat-spezifische)..." "INFO"

$cleared = 0

# Nur Extensions die STARK auf Cheats hindeuten - .ct (Cheat Engine Tables)
# .exe/.dll etc. wuerden auch legitime File-Dialogs treffen und sind verdaechtig komplett zu leeren
$cheatOnlyExts = @("ct")

$openSavePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU"
if (Test-Path $openSavePath) {
    foreach ($ext in $cheatOnlyExts) {
        $extKey = "$openSavePath\$ext"
        if (Test-Path $extKey) {
            try {
                Remove-Item -Path $extKey -Recurse -Force -ErrorAction Stop
                Write-Detail "OpenSaveMRU :: .$ext (Cheat Engine Tables)"
                $cleared++
            } catch {}
        }
    }
}

# LastVisitedPidlMRU - lassen wir stehen (komplett-Reset waere verdaechtig)
# Die Binary-PIDLs sind ohne komplexen Parser nicht selektiv loeschbar
# ComDlg32 lassen wir sonst in Ruhe - jeder Windows-User hat File-Dialogs benutzt

Write-Status "$cleared File-Dialog-Eintraege entfernt (nur .ct/Cheat-Engine)." "OK"
