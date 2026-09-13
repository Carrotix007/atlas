param([switch]$Silent)

& "$PSScriptRoot\clean-processes.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-files.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-prefetch.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-registry.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-eventlogs.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-history.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-recent.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-network.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-defender.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-services.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-errors.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-temp.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-usn.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-amcache.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-shimcache.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-srum.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-bam.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-timeline.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-autoruns.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-usb.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-userassist.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-muicache.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-rdp.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-comdlg.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-searchhistory.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-notifications.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-pca.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-clouddrive.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-self.ps1" -Silent:$Silent

# Safety-Check: kritische Services wieder starten falls kaputt
& "$PSScriptRoot\repair-services.ps1" -Silent:$Silent
# Free Space Wipe ist NICHT enthalten (dauert Minuten-Stunden)
# Separat ueber den "Free Space" Button ausfuehren
