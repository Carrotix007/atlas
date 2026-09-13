param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige PCA-Logs (Program Compatibility Assistant)..." "INFO"

$cleared = 0

# PCA Log-Files: enthalten Zeilen mit Programm-Pfaden + Timestamps
# Format: Path|Timestamp|Flags (jede Zeile ein Programm-Launch)
$pcaFiles = @(
    "$env:LOCALAPPDATA\Microsoft\Windows\PCA\PcaAppLaunchDic.txt",
    "$env:LOCALAPPDATA\Microsoft\Windows\PCA\PcaGeneralDb0.txt",
    "$env:LOCALAPPDATA\Microsoft\Windows\PCA\PcaGeneralDb1.txt"
)

foreach ($file in $pcaFiles) {
    if (-not (Test-Path $file)) { continue }
    try {
        $lines = Get-Content $file -ErrorAction Stop -Encoding UTF8
        if (-not $lines) { continue }
        $keep = @()
        $removed = 0
        foreach ($line in $lines) {
            # Zeilen enthalten Programm-Pfade - Path-Whitelist checken
            $skip = $false
            if (Test-IsPathWhitelisted $line) {
                # legitime App, behalten
                $keep += $line
                continue
            }
            if (Test-IsSuspiciousText $line) {
                Write-Detail "PCA :: $line"
                $removed++
                $skip = $true
            }
            if (-not $skip) {
                $keep += $line
            }
        }
        if ($removed -gt 0) {
            $keep | Set-Content $file -Force -Encoding UTF8
            $cleared += $removed
        }
    } catch {}
}

# System-weite PCA-Diagnosis-Files (braucht Admin)
if (Test-IsAdmin) {
    $sysPcaDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\PCA"
    if (Test-Path $sysPcaDir) {
        Get-ChildItem -Path $sysPcaDir -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension -in @(".txt", ".log", ".etl")
        } | ForEach-Object {
            $file = $_.FullName
            try {
                # ETL/Binary files: nur wenn Datei ganz aus verdaechtigen Content besteht
                if ($_.Extension -eq ".etl") {
                    # ETL Binary - schwer surgical, skippen
                    return
                }
                $lines = Get-Content $file -ErrorAction Stop -Encoding UTF8
                if (-not $lines) { return }
                $keep = @()
                $removed = 0
                foreach ($line in $lines) {
                    if (Test-IsPathWhitelisted $line) { $keep += $line; continue }
                    if (Test-IsSuspiciousText $line) {
                        Write-Detail "PCA-Sys :: $line"
                        $removed++
                    } else {
                        $keep += $line
                    }
                }
                if ($removed -gt 0) {
                    $keep | Set-Content $file -Force -Encoding UTF8
                    $cleared += $removed
                }
            } catch {}
        }
    }
}

Write-Status "$cleared PCA-Eintraege selektiv entfernt (Rest unangetastet)." "OK"
