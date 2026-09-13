param([switch]$Silent)

& "$PSScriptRoot\clean-registry.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-shimcache.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-bam.ps1" -Silent:$Silent
