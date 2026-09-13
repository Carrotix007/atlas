param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Temp (fast, nur direkte Ebene)..." "INFO"

# C:\Temp komplett - PCCheck's Arbeitsordner
if (Test-Path "C:\Temp") {
    try { Remove-Item "C:\Temp" -Recurse -Force -Confirm:$false; Write-Detail "C:\Temp" } catch {}
}

# Andere Temp-Ordner: NUR oberste Ebene (kein Recurse), executable extensions
$tempPaths = @("$env:TEMP", "$env:TMP", "$env:LOCALAPPDATA\Temp")
$extensions = @("*.exe", "*.dll", "*.ps1", "*.bat", "*.cmd", "*.ct")
$removed = 0

foreach ($tempPath in $tempPaths) {
    if (-not (Test-Path $tempPath)) { continue }
    foreach ($ext in $extensions) {
        Get-ChildItem -Path $tempPath -Filter $ext -Force -ErrorAction SilentlyContinue |
            Where-Object { Test-IsSuspiciousFile $_.Name $_.FullName } |
            ForEach-Object {
                try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
            }
    }
}

Write-Status "$removed verdaechtige Temp-Dateien entfernt (fast mode)." "OK"
