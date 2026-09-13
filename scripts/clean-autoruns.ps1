param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Autostart-Eintraege (selektiv)..." "INFO"

$cleared = 0

# Registry Run-Keys
$runKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
)

foreach ($rk in $runKeys) {
    if (-not (Test-Path $rk)) { continue }
    try {
        $items = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
        if (-not $items) { continue }
        $items.PSObject.Properties | Where-Object {
            $n = $_.Name; $v = $_.Value
            if ($n -like "PS*") { return $false }
            (Test-IsSuspicious $n) -or (Test-IsSuspiciousText "$v")
        } | ForEach-Object {
            try {
                $n = $_.Name
                Remove-ItemProperty -Path $rk -Name $n -ErrorAction Stop
                Write-Detail "AutoRun :: $rk :: $n"
                $cleared++
            } catch {}
        }
    } catch {}
}

# Startup-Ordner (User + Common)
$startupDirs = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Startup"
)
foreach ($sd in $startupDirs) {
    if (-not (Test-Path $sd)) { continue }
    Get-ChildItem -Path $sd -Force -ErrorAction SilentlyContinue | Where-Object {
        Test-IsSuspicious $_.Name
    } | ForEach-Object {
        try { $p = $_.FullName; Remove-Item $p -Force -Confirm:$false; Write-Detail "Startup :: $p"; $cleared++ } catch {}
    }
}

# Scheduled Tasks - verdaechtige entfernen
# WICHTIG: TaskPath muss frei von Windows-Systempfaden sein, sonst zerlegen wir Windows
try {
    Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $t = $_
        # Windows-eigene Tasks komplett skippen
        if ($t.TaskPath -like "\Microsoft\*" -or $t.TaskPath -like "\Windows*") { return $false }
        # TaskName + jeder Program-Pfad muss suspicious sein (mit Path-Whitelist!)
        $nameMatch = Test-IsSuspicious $t.TaskName
        $progMatch = $false
        foreach ($act in $t.Actions) {
            if ($act.Execute -and (Test-IsSuspiciousFile ([System.IO.Path]::GetFileName($act.Execute)) $act.Execute)) {
                $progMatch = $true
                break
            }
        }
        $nameMatch -or $progMatch
    } | ForEach-Object {
        try {
            $tn = $_.TaskName; $tp = $_.TaskPath
            Unregister-ScheduledTask -TaskName $tn -TaskPath $tp -Confirm:$false -ErrorAction Stop
            Write-Detail "Task :: $tp$tn"
            $cleared++
        } catch {}
    }
} catch {}

# Winlogon UserInit / Shell (falls jemand hier was reingemogelt hat)
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
if (Test-Path $winlogonPath) {
    try {
        $wl = Get-ItemProperty -Path $winlogonPath -ErrorAction SilentlyContinue
        foreach ($prop in @("Userinit", "Shell", "AppSetup")) {
            $val = $wl.$prop
            if ($val -and (Test-IsSuspiciousText $val)) {
                Write-Status "Winlogon $prop verdaechtig: $val (NICHT auto-entfernt, pruefe manuell!)" "WARN"
            }
        }
    } catch {}
}

Write-Status "$cleared Autostart-Eintraege entfernt." "OK"
