# Apply test: actually move files (with explicit user approval)
# WARNING: This WILL move files for the selected folders (26,28,29)
param([switch]$SkipMain)

$arcvRoot = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
$mainScript = Join-Path $arcvRoot "!Sync-RawAndSo.ps1"

. $mainScript -SkipMain -ScriptPath $arcvRoot

$allDirs = @(Get-ChildItem -LiteralPath $arcvRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name)

# Select indexes 26, 28, 29
$selected = @($allDirs[25], $allDirs[27], $allDirs[28])
Write-Host "Selected (indexes 26,28,29): $($selected | ForEach-Object { $_.Name } | Join-String -Separator ', ')"

# Aggregate
try {
    Write-Host "`n--- Aggregating candidates ---`n"
    $agg = Aggregate-ArchiveCandidates -Folders $selected -Sample 50
    Show-AggregatedSummary -Agg $agg -Sample 50
} catch {
    Write-Host "ERROR: $_"
    Write-Host "Stack: $($_.ScriptStackTrace)"
    exit 1
}

# Apply with confirmation
$confirm = Read-Host "`n*** FINAL CONFIRMATION: Apply archive changes? (type 'YES' to proceed, or press Enter to cancel)"
if ($confirm -ne 'YES') {
    Write-Host "Cancelled. No files moved."
    exit 0
}

# Run with Apply flag
try {
    Write-Host "`n--- Running batch with APPLY flag (option 1) ---`n"
    Batch-PerformArchive -Agg $agg -Option 1 -ArchiveMode 'new' -Apply:$true
} catch {
    Write-Host "CRITICAL ERROR: $_"
    Write-Host "Stack: $($_.ScriptStackTrace)"
    exit 1
}

Write-Host "`nApply completed successfully."
exit 0
