param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Registry (nur verdaechtige Werte)..." "INFO"

$regPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs\.exe",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs\.dll",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs\.meta",
    "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store"
)

$cleared = 0
foreach ($regPath in $regPaths) {
    if (-not (Test-Path $regPath)) { continue }
    try {
        $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if (-not $items) { continue }
        $items.PSObject.Properties | Where-Object {
            $name = $_.Name
            $val = $_.Value
            if ($name -like "PS*") { return $false }
            $text = if ($val -is [string]) { $val }
                    elseif ($val -is [byte[]]) {
                        try { [System.Text.Encoding]::Unicode.GetString($val) } catch { "" }
                    } else { "" }
            Test-IsSuspiciousText $text
        } | ForEach-Object {
            try {
                $n = $_.Name
                Remove-ItemProperty -Path $regPath -Name $n -ErrorAction Stop
                Write-Detail "$regPath :: $n"
                $cleared++
            } catch {}
        }
    } catch {}
}

$cheatKeys = @(
    "HKCU:\Software\Cheat Engine",
    "HKCU:\Software\cheatengine.org",
    "HKLM:\SOFTWARE\Cheat Engine",
    "HKCU:\Software\WeMod",
    "HKCU:\Software\Classes\.ct",
    "HKCU:\Software\Classes\CheatEngine*"
)
foreach ($key in $cheatKeys) {
    if (Test-Path $key) {
        try { Remove-Item -Path $key -Recurse -Force -Confirm:$false; Write-Detail $key; $cleared++ } catch {}
    }
}

Write-Status "$cleared verdaechtige Registry-Eintraege entfernt." "OK"
