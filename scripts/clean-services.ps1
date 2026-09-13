param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

if (-not (Test-IsAdmin)) { return }
Write-Status "Pruefe Dienste..." "INFO"

# WICHTIG: Substring-Match auf Service-Namen faelschlich zu breit
# (z.B. "esp" matched "FDResPub"). Deswegen nur SEHR spezifische Patterns.
# Und NIE StartupType aendern - nur stoppen. Windows regelt beim naechsten Boot selbst.
$stopped = 0
$strictPatterns = @(
    "*cheat*", "*aimbot*", "*wallhack*", "*trainer*",
    "*wemod*", "*cheatengine*", "*processhacker*",
    "*modmenu*", "*mod*menu*", "*ragebot*", "*legitbot*",
    "*speedhack*", "*godmode*", "*hackshield_*"
)

Get-Service -ErrorAction SilentlyContinue | Where-Object {
    $n = $_.Name.ToLower()
    $dn = $_.DisplayName.ToLower()
    # Whitelist zuerst - Anti-Cheats etc. bleiben
    if (Test-IsWhitelisted $n) { return $false }
    if (Test-IsWhitelisted $dn) { return $false }
    # Wildcard-Match auf Name UND DisplayName
    foreach ($pat in $strictPatterns) {
        if ($n -like $pat -or $dn -like $pat) { return $true }
    }
    return $false
} | ForEach-Object {
    try {
        $n = $_.Name
        Stop-Service -Name $n -Force -ErrorAction Stop
        # KEIN Set-Service Disabled! Der bleibt sonst tot ueber Reboots.
        Write-Detail $n
        $stopped++
    } catch {}
}

Write-Status "$stopped verdaechtige Dienste gestoppt (nicht deaktiviert)." "OK"
