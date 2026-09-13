param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Recent Items (selektiv)..." "INFO"

$recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
if (-not (Test-Path $recentPath)) { return }

$removed = 0

Get-ChildItem -Path $recentPath -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "*.ps1.lnk" -or (Test-IsSuspicious $_.Name)
} | ForEach-Object {
    try { $n = $_.Name; Remove-Item $_.FullName -Force -Confirm:$false; Write-Detail $n; $removed++ } catch {}
}

$jumpPath = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
if (Test-Path $jumpPath) {
    Get-ChildItem $jumpPath -Filter "*f01b4d95*" -ErrorAction SilentlyContinue | ForEach-Object {
        try { $n = $_.Name; Remove-Item $_.FullName -Force -Confirm:$false; Write-Detail $n; $removed++ } catch {}
    }
}

Write-Status "$removed verdaechtige Recent Items entfernt." "OK"
