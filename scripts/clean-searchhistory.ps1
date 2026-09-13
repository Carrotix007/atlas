param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Windows Search-History..." "INFO"

$cleared = 0

# WordWheelQuery - SURGICAL: nur verdaechtige Sucheintraege loeschen
# Values sind UTF-16LE encoded, "MRUListEx" ist binary Ordnung
$wwqPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery"
if (Test-Path $wwqPath) {
    try {
        $items = Get-ItemProperty -Path $wwqPath -ErrorAction SilentlyContinue
        if ($items) {
            $items.PSObject.Properties | Where-Object {
                if ($_.Name -notmatch '^\d+$') { return $false }
                try {
                    $bytes = [byte[]]$_.Value
                    $text = [System.Text.Encoding]::Unicode.GetString($bytes).TrimEnd([char]0)
                    Test-IsSuspiciousText $text
                } catch { $false }
            } | ForEach-Object {
                try {
                    $n = $_.Name
                    $text = [System.Text.Encoding]::Unicode.GetString([byte[]]$_.Value).TrimEnd([char]0)
                    Remove-ItemProperty -Path $wwqPath -Name $n -ErrorAction Stop
                    Write-Detail "WordWheel :: $text"
                    $cleared++
                } catch {}
            }
        }
    } catch {}
}

# RecentApps - Search kuerzlich geoeffnete Apps
$recentApps = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\RecentApps"
if (Test-Path $recentApps) {
    Get-ChildItem $recentApps -ErrorAction SilentlyContinue | Where-Object {
        try {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $appPath = $p.AppPath
            if (-not $appPath) { return $false }
            if (Test-IsPathWhitelisted $appPath) { return $false }
            (Test-IsSuspicious $appPath) -or (Test-IsSuspiciousText $appPath)
        } catch { $false }
    } | ForEach-Object {
        try {
            $n = $_.PSChildName
            $p = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).AppPath
            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction Stop
            Write-Detail "RecentApps :: $p"
            $cleared++
        } catch {}
    }
}

# TypedURLs (IE/Edge alte) - URL-Historie
$typedUrls = "HKCU:\Software\Microsoft\Internet Explorer\TypedURLs"
if (Test-Path $typedUrls) {
    try {
        $items = Get-ItemProperty -Path $typedUrls -ErrorAction SilentlyContinue
        if ($items) {
            $items.PSObject.Properties | Where-Object {
                $_.Name -like "url*" -and (Test-IsSuspiciousText "$($_.Value)")
            } | ForEach-Object {
                try {
                    Remove-ItemProperty -Path $typedUrls -Name $_.Name -ErrorAction Stop
                    Write-Detail "TypedURL :: $($_.Value)"
                    $cleared++
                } catch {}
            }
        }
    } catch {}
}

Write-Status "$cleared Search-History-Eintraege entfernt." "OK"
