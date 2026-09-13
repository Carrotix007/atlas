param([switch]$Silent)

# Quick Clean: max ~20 Sekunden, alle wichtigen Forensik-Traces
# Enthaelt jetzt auch Amcache + SRUM (surgical mit trap-Handlern)
# NICHT enthalten: USN Journal (5-10s), Free Space (Stunden), Shell Bags (aggressiv)

# Fast (sofort)
& "$PSScriptRoot\clean-processes.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-prefetch.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-registry.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-eventlogs.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-history.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-recent.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-services.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-errors.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-defender.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-shimcache.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-bam.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-timeline.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-usb.ps1" -Silent:$Silent

# LAV Coverage (schnell)
& "$PSScriptRoot\clean-userassist.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-muicache.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-rdp.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-comdlg.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-searchhistory.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-notifications.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-pca.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-clouddrive.ps1" -Silent:$Silent

# Medium (1-3 sec) - Service-safe
& "$PSScriptRoot\clean-network.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-autoruns.ps1" -Silent:$Silent

# Service-Manipulation (2-5 sec) - hat trap-Handler
# Amcache RAUS - AppInfo Service-Protection auf Win10 macht Stop unmoeglich,
# fuehrt zu UAC-Kaputt-Situationen. Verfuegbar via Full Clean + einzeln.
& "$PSScriptRoot\clean-srum.ps1" -Silent:$Silent

# Fast-Versionen von Files und Temp
& "$PSScriptRoot\clean-temp-fast.ps1" -Silent:$Silent
& "$PSScriptRoot\clean-files-fast.ps1" -Silent:$Silent

# Self
& "$PSScriptRoot\clean-self.ps1" -Silent:$Silent

# Safety-Check: kritische Services wieder starten falls kaputt (Fast mode - kein Full-Scan)
& "$PSScriptRoot\repair-services.ps1" -Silent:$Silent -Fast
