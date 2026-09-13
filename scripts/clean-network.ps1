param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige Netzwerk (selektiv)..." "INFO"

ipconfig /flushdns 2>$null | Out-Null

if (Test-IsAdmin) {
    # Bulk-Query: alle Application-Filter auf einmal holen (schnell),
    # dann verdaechtige rausfiltern und die zugehoerige Rule loeschen
    # WICHTIG: Path-Whitelist verwenden damit Windows/Microsoft/Chrome etc. verschont bleiben
    try {
        Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue | Where-Object {
            $_.Program -and (Test-IsSuspiciousFile ([System.IO.Path]::GetFileName($_.Program)) $_.Program)
        } | ForEach-Object {
            try {
                $prog = $_.Program
                $rule = $_ | Get-NetFirewallRule -ErrorAction SilentlyContinue
                if ($rule) {
                    Remove-NetFirewallRule -Name $rule.Name -ErrorAction Stop
                    Write-Detail "FW-Rule :: $($rule.DisplayName) ($prog)"
                }
            } catch {}
        }
    } catch {}
}

Write-Status "Netzwerk bereinigt." "OK"

# Browser-Spuren
Write-Status "Bereinige Browser-Spuren (selektiv)..." "INFO"

$removed = 0
$ffProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffProfiles) {
    Get-ChildItem -Path $ffProfiles -Directory | ForEach-Object {
        $dlDb = Join-Path $_.FullName "downloads.sqlite"
        if (Test-Path $dlDb) {
            try { Remove-Item $dlDb -Force -Confirm:$false; Write-Detail $dlDb; $removed++ } catch {}
        }
    }
}

Write-Status "$removed Browser-Spuren entfernt (History bleibt intakt)." "OK"
