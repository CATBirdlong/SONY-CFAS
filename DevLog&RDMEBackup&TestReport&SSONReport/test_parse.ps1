param([int]$IndexCount = 33)

function Parse-IndexSelection {
    param([string]$Selection, [int]$Max)
    Write-Host "[DEBUG] Parse-IndexSelection called with Selection='$Selection', Max=$Max"
    $s = $Selection.Trim()
    $parts = $s -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    Write-Host "[DEBUG] Parts after split: $($parts -join '|')"
    $idxs = @()
    foreach ($p in $parts) {
        Write-Host "[DEBUG] Processing part: '$p'"
        if ($p -match '^\s*(\d+)\s*~\s*(\d+)\s*$') {
            Write-Host "[DEBUG]   Matched range pattern"
            $a = [int]$matches[1]; $b = [int]$matches[2]
            if ($a -gt $b) { $tmp=$a; $a=$b; $b=$tmp }
            for ($i = $a; $i -le $b; $i++) { if ($i -ge 1 -and $i -le $Max) { $idxs += $i } }
        } elseif ($p -match '^\d+$') {
            Write-Host "[DEBUG]   Matched single number pattern"
            $n = [int]$p
            if ($n -ge 1 -and $n -le $Max) { $idxs += $n }
        }
    }
    Write-Host "[DEBUG] Final idxs: $($idxs -join ',')"
    return ($idxs | Sort-Object -Unique)
}

# Test
$result = Parse-IndexSelection -Selection "30~33" -Max $IndexCount
Write-Host "Result: $($result -join ',')"
Write-Host "Count: $($result.Count)"

if ($result.Count -eq 4 -and ($result -join ',') -eq "30,31,32,33") {
    Write-Host "✓ TEST PASSED"
    exit 0
} else {
    Write-Host "✗ TEST FAILED"
    exit 1
}
