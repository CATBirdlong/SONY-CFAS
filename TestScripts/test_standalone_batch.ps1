# Standalone test: directly invoke aggregation and batch without main loop
# This script loads only the helper functions from the main script

$ScriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'

# Dot-source the script to load all functions
. "$ScriptPath\!Sync-RawAndSo.ps1" -SkipMain

# Manually execute aggregation test logic
Write-Host ""
Write-Host "=" * 80
Write-Host "Test: Options 1-7 Display + Aggregation + Batch Execution"
Write-Host "=" * 80

# Get date folders
$dateFolders = @(
    Get-Item "$ScriptPath\2026-01-24",
    Get-Item "$ScriptPath\2026-01-29",
    Get-Item "$ScriptPath\2026-01-30"
)

Write-Host "Selected 3 folders: $($dateFolders | ForEach-Object { $_.Name })" -ForegroundColor Cyan

# Test aggregation
$agg = Aggregate-ArchiveCandidates -Folders $dateFolders
Write-Host "Aggregation completed with $($agg.Count) entries" -ForegroundColor Green

# Display summary
Write-Host ""
Show-AggregatedSummary -Agg $agg

# Display options (this was missing before the fix)
Write-Host ""
Write-Host "Options:" -ForegroundColor Yellow
Write-Host "1) (try)Archive All"
Write-Host "2) Only Medias"
Write-Host "3) Only RAWs"
Write-Host "4) Only SOs"
Write-Host "5) Medias+RAWs"
Write-Host "6) RAWs+SOs"
Write-Host "7) Do not run"

Write-Host ""
Write-Host "Test scenario 1: Option 7 (Do not run) with dry-run" -ForegroundColor Cyan
Batch-PerformArchive -Agg $agg -Option 7 -ArchiveMode 'new'

Write-Host ""
Write-Host "Test scenario 2: Option 1 (Archive All) with dry-run" -ForegroundColor Cyan
Batch-PerformArchive -Agg $agg -Option 1 -ArchiveMode 'new'

Write-Host ""
Write-Host "=" * 80
Write-Host "All tests completed successfully!" -ForegroundColor Green
Write-Host "=" * 80
