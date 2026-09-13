param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige RDP-Client-History (selektiv)..." "INFO"

$cleared = 0

# Default - Liste der zuletzt verbundenen RDP-Server (MRU0..MRU9)
$defPath = "HKCU:\Software\Microsoft\Terminal Server Client\Default"
if (Test-Path $defPath) {
    try {
        $items = Get-ItemProperty -Path $defPath -ErrorAction SilentlyContinue
        if ($items) {
            $items.PSObject.Properties | Where-Object {
                $n = $_.Name; $v = "$($_.Value)"
                if ($n -like "PS*") { return $false }
                if ($n -like "MRU*") { return (Test-IsSuspiciousText $v) }
                $false
            } | ForEach-Object {
                try {
                    $n = $_.Name; $v = "$($_.Value)"
                    Remove-ItemProperty -Path $defPath -Name $n -ErrorAction Stop
                    Write-Detail "RDP :: $n = $v"
                    $cleared++
                } catch {}
            }
        }
    } catch {}
}

# Servers - Sub-Keys mit Server-Hostnamen (mit cached username usw.)
$srvPath = "HKCU:\Software\Microsoft\Terminal Server Client\Servers"
if (Test-Path $srvPath) {
    Get-ChildItem $srvPath -ErrorAction SilentlyContinue | Where-Object {
        Test-IsSuspiciousText $_.PSChildName
    } | ForEach-Object {
        try {
            $n = $_.PSChildName
            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction Stop
            Write-Detail "RDP-Server :: $n"
            $cleared++
        } catch {}
    }
}

Write-Status "$cleared RDP-Eintraege entfernt." "OK"
