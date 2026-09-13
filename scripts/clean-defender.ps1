param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

if (-not (Test-IsAdmin)) { return }
Write-Status "Bereinige Defender History..." "INFO"

$defPath = "$env:ProgramData\Microsoft\Windows Defender\Scans\History"
if (Test-Path $defPath) {
    Get-ChildItem -Path $defPath -Recurse -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -like "*temp*") -or
        ($_.LastWriteTime -gt (Get-Date).AddHours(-24) -and (Test-IsSuspicious $_.Name))
    } | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Force -Recurse -Confirm:$false; Write-Detail $p } catch {}
    }
}

Write-Status "Defender History bereinigt." "OK"
