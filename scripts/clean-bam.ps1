param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige BAM/DAM..." "INFO"

if (-not (Test-IsAdmin)) {
    Write-Status "Braucht Admin fuer BAM." "WARN"
    return
}

$bamPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings",
    "HKLM:\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings"
)

# Sammle alle zu loeschenden Eintraege (name + path)
$toDelete = @()
foreach ($bamPath in $bamPaths) {
    if (-not (Test-Path $bamPath)) { continue }
    try {
        Get-ChildItem $bamPath | ForEach-Object {
            $subKey = $_.PSPath
            $props = $_ | Get-ItemProperty
            $props.PSObject.Properties | Where-Object {
                $n = $_.Name
                $n -notlike "PS*" -and $n -ne "Version" -and $n -ne "SequenceNumber" -and
                (Test-IsSuspicious $n)
            } | ForEach-Object {
                $toDelete += [PSCustomObject]@{ Path = $subKey; Name = $_.Name }
            }
        }
    } catch {
        Write-Status "BAM Read-Fehler: $($_.Exception.Message)" "WARN"
    }
}

if ($toDelete.Count -eq 0) {
    Write-Status "0 BAM/DAM-Eintraege entfernt." "OK"
    return
}

# Versuch 1: direkt loeschen (funktioniert wenn Admin genug Rechte hat)
$cleared = 0
$failed = @()
foreach ($item in $toDelete) {
    try {
        Remove-ItemProperty -Path $item.Path -Name $item.Name -ErrorAction Stop
        Write-Detail "BAM :: $($item.Name)"
        $cleared++
    } catch {
        $failed += $item
    }
}

# Versuch 2: falls Failed - via SYSTEM-Context (Scheduled Task)
# BAM ist SYSTEM-owned, Admin kann nicht direkt schreiben
if ($failed.Count -gt 0) {
    Write-Status "$($failed.Count) BAM-Eintraege brauchen SYSTEM-Rechte, versuche via Scheduled Task..." "INFO"

    # Baue PowerShell-Command der die failed entries loescht
    $deleteCmds = @()
    foreach ($f in $failed) {
        # Registry-Pfad korrekt escapen fuer PS-Command-String
        $regPath = $f.Path -replace "^Microsoft.PowerShell.Core\\Registry::", ""
        $regPath = "Registry::" + $regPath
        $escN = $f.Name -replace "'", "''"
        $deleteCmds += "try { Remove-ItemProperty -Path '$regPath' -Name '$escN' -ErrorAction Stop; 'DEL::$escN' | Out-File -Append 'C:\Windows\Temp\bam_result.txt' } catch { 'ERR::' + `$_.Exception.Message | Out-File -Append 'C:\Windows\Temp\bam_result.txt' }"
    }
    $fullCmd = $deleteCmds -join '; '

    # Result-File loeschen falls existiert
    $resultFile = "C:\Windows\Temp\bam_result.txt"
    if (Test-Path $resultFile) { Remove-Item $resultFile -Force -ErrorAction SilentlyContinue }

    # Scheduled Task erstellen der als SYSTEM laeuft
    $taskName = "AtlasBamClean_" + (Get-Random -Maximum 999999)
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($fullCmd))
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand $encoded"
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $task = New-ScheduledTask -Action $action -Principal $principal
        Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName

        # Warten bis Task fertig ist
        $timeout = 15
        while ($timeout -gt 0) {
            $t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($t.State -ne 'Running') { break }
            Start-Sleep -Milliseconds 500
            $timeout -= 0.5
        }

        # Task entfernen
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

        # Ergebnis lesen
        if (Test-Path $resultFile) {
            $lines = Get-Content $resultFile
            foreach ($line in $lines) {
                if ($line -like "DEL::*") {
                    Write-Detail "BAM (SYSTEM) :: $($line -replace 'DEL::', '')"
                    $cleared++
                } elseif ($line -like "ERR::*") {
                    Write-Status "BAM (SYSTEM) Fehler: $($line -replace 'ERR::', '')" "WARN"
                }
            }
            Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Status "SYSTEM-Task Fehler: $($_.Exception.Message)" "WARN"
    }
}

Write-Status "$cleared BAM/DAM-Eintraege entfernt." "OK"
