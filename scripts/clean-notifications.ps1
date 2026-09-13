param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Notification-Registry (selektiv)..." "INFO"

$cleared = 0

# NUR verdaechtige ActionCenter-Notifications loeschen (nicht die ganze DB)
# wpndatabase.db lassen wir stehen - kompletter Delete waere Red Flag
$acPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Data"
if (Test-Path $acPath) {
    try {
        $items = Get-ItemProperty -Path $acPath -ErrorAction SilentlyContinue
        if ($items) {
            $items.PSObject.Properties | Where-Object {
                # ActionCenter binary values - schwer zu parsen
                # Ohne Content-Analyse skippen wir das
                $false
            } | ForEach-Object {}
        }
    } catch {}
}

# Toast Notifications SubDirectories - nur die mit Cheat im Namen
$toastDir = "$env:LOCALAPPDATA\Microsoft\Windows\Notifications"
if (Test-Path $toastDir) {
    Get-ChildItem $toastDir -Directory -ErrorAction SilentlyContinue | Where-Object {
        Test-IsSuspicious $_.Name
    } | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Recurse -Force -Confirm:$false; Write-Detail $p; $cleared++ } catch {}
    }
}

Write-Status "$cleared Notification-Eintraege entfernt (wpndatabase bleibt intakt)." "OK"
