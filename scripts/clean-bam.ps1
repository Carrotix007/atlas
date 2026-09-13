param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige BAM/DAM..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer BAM." "WARN"
    return
}

$bamPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings",
    "HKLM:\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings"
)

$cleared = 0
foreach ($bamPath in $bamPaths) {
    if (-not (Test-Path $bamPath)) { continue }
    try {
        Get-ChildItem $bamPath | ForEach-Object {
            $props = $_ | Get-ItemProperty
            $props.PSObject.Properties | Where-Object {
                $n = $_.Name
                $n -notlike "PS*" -and $n -ne "Version" -and $n -ne "SequenceNumber" -and
                (Test-IsSuspicious $n)
            } | ForEach-Object {
                try { $n = $_.Name; Remove-ItemProperty -Path $props.PSPath -Name $n -ErrorAction Stop; Write-Detail "BAM :: $n"; $cleared++ } catch {}
            }
        }
    } catch {}
}

Write-Status "$cleared BAM/DAM-Eintraege entfernt." "OK"
