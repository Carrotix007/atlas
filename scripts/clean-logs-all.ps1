param([switch]$Silent)

& "$PSScriptRoot\clean-eventlogs.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-history.ps1" -Silent:$Silent
