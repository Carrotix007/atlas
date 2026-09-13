param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Suche erkennbare Dateien..." "INFO"

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

# AppData + LocalAppData: nur Executables + nur direkte Files + Programs-Unterordner
# Deep-Scan durch Chrome/Discord/etc. wuerde ewig dauern und nur False Positives finden
$extensions = @("*.exe", "*.dll", "*.sys", "*.ps1", "*.bat", "*.cmd", "*.vbs", "*.js", "*.msi", "*.ct")
$scanRoots = @(
    "$env:LOCALAPPDATA",
    "$env:LOCALAPPDATA\Programs",
    "$env:APPDATA"
)
foreach ($searchPath in $scanRoots) {
    if (-not (Test-Path $searchPath)) { continue }
    foreach ($ext in $extensions) {
        # -Depth 1: nur oberste Ebene + eine Unterebene
        Get-ChildItem -Path $searchPath -Filter $ext -Force -Depth 1 -ErrorAction SilentlyContinue |
            Where-Object { Test-IsSuspiciousFile $_.Name $_.FullName } |
            ForEach-Object {
                try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
            }
    }
}

foreach ($dir in @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads")) {
    Get-ChildItem -Path $dir -Filter "*.ct" -ErrorAction SilentlyContinue | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
    }
}

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

# Forensik-Tools
Write-Status "Suche Forensik-Tools..." "INFO"

$toolNames = @(
    "csvfileview", "timelineexplorer", "registryexplorer",
    "winprefetchview", "pccheck", "autoruns",
    "stringexplorer", "usbdeview", "srumexplorer",
    "powershellparser", "pathsparser", "mftexplorer",
    "journaltrace", "amcacheparser", "bamparser"
)

# Downloads/Desktop rekursiv (klein), Programme + AppData nur Depth 2
$deepPaths    = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "C:\Temp")
$shallowPaths = @("$env:PROGRAMFILES", "${env:PROGRAMFILES(X86)}", "$env:LOCALAPPDATA", "$env:APPDATA")

foreach ($sp in $deepPaths) {
    if (-not (Test-Path $sp)) { continue }
    foreach ($tool in $toolNames) {
        Get-ChildItem -Path $sp -Filter "*$tool*" -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
            -not (Test-IsPathWhitelisted $_.FullName)
        } | ForEach-Object {
            try { $p = $_.FullName; Remove-Item $p -Recurse -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
        }
    }
}

foreach ($sp in $shallowPaths) {
    if (-not (Test-Path $sp)) { continue }
    foreach ($tool in $toolNames) {
        Get-ChildItem -Path $sp -Filter "*$tool*" -Force -Depth 2 -ErrorAction SilentlyContinue | Where-Object {
            -not (Test-IsPathWhitelisted $_.FullName)
        } | ForEach-Object {
            try { $p = $_.FullName; Remove-Item $p -Recurse -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
        }
    }
}

$shortcutDirs = @(
    "$env:USERPROFILE\Desktop",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs"
)
foreach ($dir in $shortcutDirs) {
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue | Where-Object {
        Test-IsSuspicious $_.Name
    } | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail $p; $removed++ } catch {}
    }
}

Write-Status "$removed Dateien/Ordner entfernt." "OK"
