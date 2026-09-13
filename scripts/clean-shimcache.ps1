param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige ShimCache..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer ShimCache." "WARN"
    return
}

$controlSets = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache",
    "HKLM:\SYSTEM\ControlSet001\Control\Session Manager\AppCompatCache",
    "HKLM:\SYSTEM\ControlSet002\Control\Session Manager\AppCompatCache"
)

$cleared = 0
foreach ($path in $controlSets) {
    if (Test-Path $path) {
        try {
            Remove-ItemProperty -Path $path -Name "AppCompatCache" -ErrorAction Stop
            Write-Detail "AppCompatCache :: $path"
            $cleared++
        } catch {}
    }
}

$layersPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
if (Test-Path $layersPath) {
    try {
        $items = Get-ItemProperty -Path $layersPath -ErrorAction SilentlyContinue
        $items.PSObject.Properties | Where-Object {
            $_.Name -notlike "PS*" -and (Test-IsSuspicious $_.Name)
        } | ForEach-Object {
            try { $n = $_.Name; Remove-ItemProperty -Path $layersPath -Name $n -ErrorAction Stop; Write-Detail "Layer :: $n"; $cleared++ } catch {}
        }
    } catch {}
}

Write-Status "$cleared ShimCache-Eintraege bereinigt." "OK"
