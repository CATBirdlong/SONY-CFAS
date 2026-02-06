# Direct dry-run test: index 26, 28, 29 from actual date folders
param([switch]$SkipMain)

$arcvRoot = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
$mainScript = Join-Path $arcvRoot "!Sync-RawAndSo.ps1"

# Load main script
. $mainScript -SkipMain -ScriptPath $arcvRoot

# Get date folders
$allDirs = @(Get-ChildItem -LiteralPath $arcvRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name)
Write-Host "Total date folders: $($allDirs.Count)"

# Show first 30
$allDirs | Select-Object -First 30 | ForEach-Object { $i=0 } { $i++; Write-Host "$i. $($_.Name)" }

if ($allDirs.Count -lt 26) {
    Write-Host "ERROR: Not enough folders (need at least 26)"
    exit 1
}

# Select indexes 26, 28, 29 (1-based)
$selected = @($allDirs[25], $allDirs[27], $allDirs[28])
Write-Host "`nSelected (indexes 26,28,29):"
$selected | ForEach-Object { Write-Host "  - $($_.Name)" }

# ===== Run aggregation =====
Write-Host "`n--- Aggregating candidates (dry-run) ---`n"
try {
    $agg = Aggregate-ArchiveCandidates -Folders $selected -Sample 50
    Show-AggregatedSummary -Agg $agg -Sample 50
} catch {
    Write-Host "ERROR during aggregation: $_"
    Write-Host "Stack: $($_.ScriptStackTrace)"
    exit 1
}

# ===== Batch dry-run (option 1 = archive all) =====
Write-Host "`n--- Running batch dry-run (option 1 = archive all) ---`n"
try {
    Batch-PerformArchive -Agg $agg -Option 1 -ArchiveMode 'new' -Apply:$false
} catch {
    Write-Host "CRITICAL ERROR: $_"
    Write-Host "Stack: $($_.ScriptStackTrace)"
    exit 1
}

Write-Host "`nDry-run completed. No files moved."
exit 0
