param([switch]$Silent)
. "$PSScriptRoot\_common.ps1"

Write-Status "Bereinige UserAssist (selektiv, ROT13-decoded)..." "INFO"

# Fast ROT13 via array-lookup - deutlich schneller als per-char if-else
$rotMap = New-Object 'byte[]' 256
for ($i = 0; $i -lt 256; $i++) { $rotMap[$i] = $i }
foreach ($c in [char[]]"ABCDEFGHIJKLM") { $rotMap[[byte]$c] = [byte][char](([int]$c) + 13) }
foreach ($c in [char[]]"NOPQRSTUVWXYZ") { $rotMap[[byte]$c] = [byte][char](([int]$c) - 13) }
foreach ($c in [char[]]"abcdefghijklm") { $rotMap[[byte]$c] = [byte][char](([int]$c) + 13) }
foreach ($c in [char[]]"nopqrstuvwxyz") { $rotMap[[byte]$c] = [byte][char](([int]$c) - 13) }

function ConvertFrom-Rot13Fast([string]$text) {
    if (-not $text) { return "" }
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($text)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = $rotMap[$bytes[$i]]
    }
    return [System.Text.Encoding]::ASCII.GetString($bytes)
}

# Compiled Regex fuer schnelles Pre-Filtering (kombinierter Match)
$escapedKeywords = $SUSPECT_KEYWORDS | ForEach-Object { [regex]::Escape($_) -replace '\\\*', '\S*' }
$combinedPattern = "(?i)(" + ($escapedKeywords -join '|') + ")"
$fastRegex = [regex]::new($combinedPattern, [System.Text.RegularExpressions.RegexOptions]::Compiled)

$cleared = 0
$uaBase = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"

if (Test-Path $uaBase) {
    Get-ChildItem $uaBase -ErrorAction SilentlyContinue | ForEach-Object {
        $countPath = Join-Path $_.PSPath "Count"
        if (-not (Test-Path $countPath)) { return }
        try {
            $items = Get-ItemProperty -Path $countPath -ErrorAction SilentlyContinue
            if (-not $items) { return }

            # Collect suspicious names first, dann in Batch loeschen
            $toRemove = @{}
            foreach ($prop in $items.PSObject.Properties) {
                $rot = $prop.Name
                if ($rot -like "PS*") { continue }
                $decoded = ConvertFrom-Rot13Fast $rot
                if (-not $fastRegex.IsMatch($decoded)) { continue }
                if (Test-IsPathWhitelisted $decoded) { continue }
                # Wort-Grenzen final check
                if (Test-IsSuspiciousText $decoded) {
                    $toRemove[$rot] = $decoded
                }
            }
            foreach ($n in $toRemove.Keys) {
                try {
                    Remove-ItemProperty -Path $countPath -Name $n -ErrorAction Stop
                    Write-Detail "UserAssist :: $($toRemove[$n])"
                    $cleared++
                } catch {}
            }
        } catch {}
    }
}

Write-Status "$cleared UserAssist-Eintraege entfernt." "OK"
