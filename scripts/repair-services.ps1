param([switch]$Silent, [switch]$Fast)
. "$PSScriptRoot\_common.ps1"

Write-Status "Pruefe & repariere kritische Windows-Services..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer Service-Repair." "WARN"
    return
}

$criticalServices = @(
    "AppInfo",         # UAC / Application Information
    "DPS",             # Diagnostic Policy Service
    "DiagTrack",       # Connected User Experiences
    "Wcmsvc",          # Windows Connection Manager
    "EventLog",        # Windows Event Log
    "RpcSs",           # Remote Procedure Call
    "CryptSvc",        # Cryptographic Services
    "Dnscache",        # DNS Client
    "Themes",          # Themes
    "wuauserv",        # Windows Update
    "TrustedInstaller",
    "Winmgmt",         # WMI
    "FDResPub",        # Function Discovery (haeufig faelschlich gestoppt wg. "esp")
    "fdPHost",         # Function Discovery Provider Host
    "SSDPSRV",         # SSDP Discovery
    "upnphost",        # UPnP
    "Schedule",        # Task Scheduler
    "SysMain",         # SysMain (Superfetch)
    "WSearch",         # Windows Search
    "BFE",             # Base Filtering Engine
    "MpsSvc"           # Windows Firewall
)

$repaired = 0
foreach ($svc in $criticalServices) {
    try {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if (-not $s) { continue }

        # StartType auf sinnvollen Default zuruecksetzen falls Disabled
        if ($s.StartType -eq 'Disabled') {
            Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue
            Write-Detail "StartType ${svc}: Disabled -> Manual"
        }

        # Starten wenn nicht laeuft
        if ($s.Status -ne 'Running') {
            Start-Service -Name $svc -ErrorAction Stop
            Start-Sleep -Milliseconds 300
            $s2 = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s2.Status -eq 'Running') {
                Write-Detail "Service gestartet: $svc"
                $repaired++
            } else {
                Write-Status "Service $svc konnte nicht gestartet werden!" "WARN"
            }
        }
    } catch {
        Write-Status "Fehler bei ${svc}: $($_.Exception.Message)" "WARN"
    }
}

# Full Service-Scan: ALLE disabled Services die keine Cheats sind wieder auf Manual setzen
# LANGSAM (iteriert 200+ Services) - skippen im -Fast Modus
if (-not $Fast) {
    try {
        Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {
            $_.StartMode -eq 'Disabled'
        } | ForEach-Object {
            $svcName = $_.Name
            $displayName = $_.DisplayName
            if ((Test-IsSuspicious $svcName) -and -not (Test-IsWhitelisted $svcName)) { return }
            try {
                Set-Service -Name $svcName -StartupType Manual -ErrorAction Stop
                Write-Detail "Re-enabled: $svcName ($displayName)"
                $repaired++
            } catch {}
        }
    } catch {}
}

# DisableTaskMgr Policy checken und ggf. entfernen
$policyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
if (Test-Path $policyPath) {
    try {
        $val = (Get-ItemProperty -Path $policyPath -Name "DisableTaskMgr" -ErrorAction SilentlyContinue).DisableTaskMgr
        if ($val -eq 1) {
            Remove-ItemProperty -Path $policyPath -Name "DisableTaskMgr" -ErrorAction Stop
            Write-Detail "DisableTaskMgr Policy entfernt"
            $repaired++
        }
    } catch {}
}

# Amcache Hive-Leftover unmounten falls vorhanden
if (Test-Path "HKLM:\AMCACHE_TEMP") {
    try {
        & reg unload "HKLM\AMCACHE_TEMP" 2>&1 | Out-Null
        Write-Detail "Amcache-Hive Leftover unmounted"
        $repaired++
    } catch {}
}

Write-Status "$repaired Reparaturen durchgefuehrt." "OK"
