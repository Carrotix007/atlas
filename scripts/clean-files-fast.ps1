param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Suche erkennbare Dateien (fast)..." "INFO"

$removed = 0

# Downloads + Desktop: rekursiv, alle Dateien (User-Ordner, klein)
foreach ($searchPath in @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")) {
    if (-not (Test-Path $searchPath)) { continue }
    try {
        Get-ChildItem -Path $searchPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
            Test-IsSuspiciousFile $_.Name $_.FullName
        } | ForEach-Object {
            try { $p = $_.FullName; Remove-Item $p -Recurse -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
        }
    } catch {}
}

# LocalAppData\Programs (nur Depth 1) - typischer Ort fuer portable Cheat-Installs
$programs = "$env:LOCALAPPDATA\Programs"
if (Test-Path $programs) {
    foreach ($ext in @("*.exe", "*.dll", "*.ct")) {
        Get-ChildItem -Path $programs -Filter $ext -Force -Depth 1 -ErrorAction SilentlyContinue |
            Where-Object { Test-IsSuspiciousFile $_.Name $_.FullName } |
            ForEach-Object {
                try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
            }
    }
}

# Bekannte Cheat-Ordner (direkte Path-Check, kein Scan)
$knownDirs = @(
    "$env:APPDATA\Cheat Engine*", "$env:LOCALAPPDATA\Cheat Engine*",
    "$env:APPDATA\WeMod*", "$env:LOCALAPPDATA\WeMod*",
    "$env:LOCALAPPDATA\Programs\WeMod*",
    "$env:APPDATA\2Take1*", "$env:APPDATA\Stand*",
    "$env:APPDATA\Cherax*", "$env:APPDATA\Kiddions*",
    "$env:APPDATA\YimMenu*", "$env:APPDATA\Modest*Menu*"
)
foreach ($path in $knownDirs) {
    Get-Item -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Recurse -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
    }
}

if (Test-Path "C:\Temp\Dump") {
    try { Remove-Item "C:\Temp\Dump" -Recurse -Force -Confirm:$false; Write-Detail "C:\Temp\Dump"; $removed++ } catch {}
}
if (Test-Path "C:\Temp\Scripts") {
    try { Remove-Item "C:\Temp\Scripts" -Recurse -Force -Confirm:$false; Write-Detail "C:\Temp\Scripts"; $removed++ } catch {}
}

Write-Status "$removed Dateien/Ordner entfernt (fast mode)." "OK"
