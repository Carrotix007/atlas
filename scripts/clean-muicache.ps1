param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige MUICache (selektiv)..." "INFO"

$cleared = 0
$muiPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"

if (Test-Path $muiPath) {
    try {
        $items = Get-ItemProperty -Path $muiPath -ErrorAction SilentlyContinue
        if ($items) {
            $items.PSObject.Properties | Where-Object {
                $n = $_.Name
                if ($n -like "PS*") { return $false }
                if (Test-IsPathWhitelisted $n) { return $false }
                (Test-IsSuspicious $n) -or (Test-IsSuspiciousText "$($_.Value)")
            } | ForEach-Object {
                try {
                    $n = $_.Name
                    Remove-ItemProperty -Path $muiPath -Name $n -ErrorAction Stop
                    Write-Detail "MUICache :: $n"
                    $cleared++
                } catch {}
            }
        }
    } catch {}
}

Write-Status "$cleared MUICache-Eintraege entfernt." "OK"
