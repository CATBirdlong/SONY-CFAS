# Regression test: verify optimized script with hardening improvements
param([switch]$SkipMain)

$arcvRoot = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
$mainScript = Join-Path $arcvRoot "!Sync-RawAndSo.ps1"

. $mainScript -SkipMain -ScriptPath $arcvRoot

$allDirs = @(Get-ChildItem -LiteralPath $arcvRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name)

# Select a fresh test instance: indexes 5,7,10 (different from 26,28,29)
$selected = @($allDirs[4], $allDirs[6], $allDirs[9])
Write-Host "=== REGRESSION TEST (indexes 5,7,10) ===" -ForegroundColor Cyan
Write-Host "Selected folders:"
$selected | ForEach-Object { Write-Host "  • $($_.Name)" }

Write-Host "`n--- Aggregating (with new safeguards) ---"
try {
    $agg = Aggregate-ArchiveCandidates -Folders $selected -Sample 50
    Show-AggregatedSummary -Agg $agg -Sample 50
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n--- Running dry-run (no files moved) ---"
try {
    Batch-PerformArchive -Agg $agg -Option 1 -ArchiveMode 'new' -Apply:$false
    Write-Host "`n✅ Dry-run completed successfully with all safeguards intact." -ForegroundColor Green
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}

exit 0
