param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige PowerShell History (selektiv)..." "INFO"

$historyPaths = @(
    "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
)

try {
    $dynamicPath = (Get-PSReadlineOption).HistorySavePath
    if ($dynamicPath -and ($dynamicPath -notin $historyPaths)) {
        $historyPaths += $dynamicPath
    }
} catch {}

foreach ($histPath in $historyPaths) {
    if (-not (Test-Path $histPath)) { continue }
    try {
        $lines = Get-Content $histPath -ErrorAction Stop
        $keep = @()
        foreach ($line in $lines) {
            if (Test-IsSuspiciousText $line) {
                Write-Detail "HISTORY :: $line"
            } else {
                $keep += $line
            }
        }
        $keep | Set-Content $histPath -Force -Encoding UTF8
    } catch {}
}

$isePath = "$env:USERPROFILE\Documents\WindowsPowerShell\ISERecentFiles.xml"
if (Test-Path $isePath) {
    try { Remove-Item $isePath -Force -Confirm:$false } catch {}
}

Write-Status "PS History bereinigt." "OK"
