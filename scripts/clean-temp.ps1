param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Temp (nur verdaechtige Executables)..." "INFO"

# C:\Temp komplett - das ist PCCheck's Arbeitsordner
if (Test-Path "C:\Temp") {
    try { Remove-Item "C:\Temp" -Recurse -Force -Confirm:$false; Write-Detail "C:\Temp" } catch {}
}

# Andere Temp-Ordner: nur Executable-Extensions scannen
# Rekursiv aber ohne jede TXT/LOG/PNG anzufassen -> viel schneller
$tempPaths = @("$env:TEMP", "$env:TMP", "$env:LOCALAPPDATA\Temp")
$extensions = @("*.exe", "*.dll", "*.sys", "*.ps1", "*.bat", "*.cmd", "*.vbs", "*.js", "*.msi", "*.ct")
$removed = 0

foreach ($tempPath in $tempPaths) {
    if (-not (Test-Path $tempPath)) { continue }
    foreach ($ext in $extensions) {
        Get-ChildItem -Path $tempPath -Filter $ext -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { Test-IsSuspiciousFile $_.Name $_.FullName } |
            ForEach-Object {
                try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
            }
    }
}

Write-Status "$removed verdaechtige Temp-Dateien entfernt." "OK"
