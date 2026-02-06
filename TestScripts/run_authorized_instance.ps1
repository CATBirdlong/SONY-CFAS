# Apply test: actually move files for indexes 26,28,29 (user-authorized)
param([switch]$SkipMain)

$arcvRoot = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
$mainScript = Join-Path $arcvRoot "!Sync-RawAndSo.ps1"

. $mainScript -SkipMain -ScriptPath $arcvRoot

$allDirs = @(Get-ChildItem -LiteralPath $arcvRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name)

# Select indexes 26, 28, 29
$selected = @($allDirs[25], $allDirs[27], $allDirs[28])
Write-Host "=== AUTHORIZED INSTANCE MOVE (26,28,29) ===" -ForegroundColor Cyan
Write-Host "Selected folders:"
$selected | ForEach-Object { Write-Host "  • $($_.Name)" }

# Aggregate
Write-Host "`n--- Aggregating archive candidates ---"
try {
    $agg = Aggregate-ArchiveCandidates -Folders $selected -Sample 50
    Show-AggregatedSummary -Agg $agg -Sample 50
} catch {
    Write-Host "AGGREGATION ERROR: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)"
    exit 1
}

# Execute with APPLY
Write-Host "`n--- EXECUTING ARCHIVE (APPLY=TRUE, option 1=Archive All) ---" -ForegroundColor Yellow
try {
    Batch-PerformArchive -Agg $agg -Option 1 -ArchiveMode 'new' -Apply:$true
    Write-Host "`n✅ ARCHIVE EXECUTED SUCCESSFULLY" -ForegroundColor Green
} catch {
    Write-Host "`n❌ ARCHIVE FAILED: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)"
    exit 1
}

exit 0
