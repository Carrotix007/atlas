param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Ueberschreibe freien Speicher (kann dauern)..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer Free Space Wipe." "WARN"
    return
}

try {
    $tempDir = "C:\atlas_wipe_temp_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Start-Process -FilePath "cipher.exe" -ArgumentList "/w:$tempDir" -WindowStyle Hidden -Wait
    Remove-Item $tempDir -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
    Write-Status "Freier Speicher ueberschrieben." "OK"
} catch {
    Write-Status "Free Space Wipe Fehler." "WARN"
}
