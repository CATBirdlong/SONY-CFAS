# Test post-archive error fix: ensure no crash after APPLY
# Using folders 22,23,24 for dry-run, then 25,26 for real APPLY
param()

$arcvRoot = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
$mainScript = Join-Path $arcvRoot "!Sync-RawAndSo.ps1"

. $mainScript

Write-Host "=== DRY-RUN TEST: archive then continue (should NOT crash) ===" -ForegroundColor Cyan

$allDirs = @(Get-ChildItem -LiteralPath $arcvRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name)

# Use fresh folders for dry-run
$dryRunFolders = @($allDirs[21], $allDirs[22], $allDirs[23]) | Where-Object { $_ }
if ($dryRunFolders.Count -eq 0) {
    Write-Host "Not enough folders for test"
    exit 1
}

Write-Host "DRY-RUN folders: $($dryRunFolders | ForEach-Object Name)"

try {
    Write-Host "`n--- Aggregating ---"
    $agg = Aggregate-ArchiveCandidates -Folders $dryRunFolders -Sample 50
    Show-AggregatedSummary -Agg $agg -Sample 50
    
    Write-Host "`n--- DRY-RUN: Archive All (no files moved) ---"
    Batch-PerformArchive -Agg $agg -Option 1 -ArchiveMode 'new' -Apply:$false
    
    Write-Host "`n✅ DRY-RUN PASSED (no crash after archive!)" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR during dry-run: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== REAL APPLY TEST: small batch (2-3 files) ===" -ForegroundColor Cyan

# Use a fresh small folder for REAL apply
$applyFolders = @($allDirs[24]) | Where-Object { $_ }
if ($applyFolders.Count -eq 0) {
    Write-Host "Not enough folders for APPLY test"
    exit 1
}

Write-Host "APPLY folder: $($applyFolders | ForEach-Object Name)"

try {
    $agg2 = Aggregate-ArchiveCandidates -Folders $applyFolders -Sample 50
    Show-AggregatedSummary -Agg $agg2 -Sample 50
    
    Write-Host "`n--- Attempting real APPLY ---"
    Batch-PerformArchive -Agg $agg2 -Option 1 -ArchiveMode 'new' -Apply:$true
    
    Write-Host "`n✅ REAL APPLY PASSED (no crash after APPLY!)" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR during APPLY: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ ALL TESTS PASSED - POST-ARCHIVE FIX SUCCESSFUL!" -ForegroundColor Green
exit 0
