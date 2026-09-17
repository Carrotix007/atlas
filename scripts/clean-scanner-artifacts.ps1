param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Scanner-Artefakte (Echo AC / Ocean / etc.)..." "INFO"

$cleared = 0
$tempRoots = @($env:TEMP, $env:TMP, "$env:LOCALAPPDATA\Temp")

# Echo AC hinterlaesst: echo<random>\ntfsDump, temp.bin, Amcache.hve, .LOG1, .LOG2
foreach ($tempRoot in $tempRoots) {
    if (-not (Test-Path $tempRoot)) { continue }

    # Echo folders: "echo" + Digits
    Get-ChildItem -Path $tempRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^echo\d+$'
    } | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Recurse -Force -Confirm:$false; Write-Detail "Echo AC :: $p"; $cleared++ } catch {}
    }

    # Ocean: numeric-only folders mit a3.exe / xxstrings64-Ocean.exe
    Get-ChildItem -Path $tempRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^\d{7,10}$'
    } | ForEach-Object {
        $dir = $_
        $oceanMarkers = @("a3.exe", "xxstrings64-Ocean.exe", "avast.db", "SYSTEM.log")
        foreach ($m in $oceanMarkers) {
            if (Test-Path (Join-Path $dir.FullName $m)) {
                try { $p = $dir.FullName; Remove-Item $p -Recurse -Force -Confirm:$false; Write-Detail "Ocean :: $p"; $cleared++ } catch {}
                break
            }
        }
    }

    # Loose Files (direkt in Temp)
    $looseNames = @(
        "a3.exe", "xxstrings64-Ocean.exe", "ntfsDump", "temp.bin",
        "PROCEXP152.sys", "EchoDrv.sys", "kprocesshacker*.sys"
    )
    foreach ($ln in $looseNames) {
        Get-ChildItem -Path $tempRoot -Filter $ln -ErrorAction SilentlyContinue -File | ForEach-Object {
            try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail "Scanner-File :: $p"; $cleared++ } catch {}
        }
    }
}

# Roblox-Account-Reste (Ocean checkt darauf)
$robloxPaths = @(
    "$env:LOCALAPPDATA\Roblox\logs",
    "$env:LOCALAPPDATA\Roblox\LocalStorage"
)
foreach ($rp in $robloxPaths) {
    if (Test-Path $rp) {
        Get-ChildItem -Path $rp -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
            Test-IsSuspicious $_.Name
        } | ForEach-Object {
            try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail "Roblox :: $p"; $cleared++ } catch {}
        }
    }
}

Write-Status "$cleared Scanner-Artefakte entfernt." "OK"
