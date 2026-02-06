# Test comprehensive dry-run with 26,28~29 and option 7 (no move)
# Non-interactive test mode
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
& { . "$ScriptPath\!Sync-RawAndSo.ps1" } -SkipMain

# Non-interactive test mode: directly aggregate and show summary
$dateFolders = Get-ChildItem -LiteralPath $ScriptPath -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}($|[^0-9])' }

# Select folders 26 (2026-01-24), 28 (2026-01-29), 29 (2026-01-30)
$selected = @($dateFolders[25], $dateFolders[27], $dateFolders[28])  # 0-indexed: 25=26, 27=28, 28=29

Write-Host "Selected folders: $($selected | ForEach-Object { $_.Name })" -ForegroundColor Cyan
$agg = Aggregate-ArchiveCandidates -Folders $selected

# Display aggregated summary and options
Show-AggregatedSummary -Agg $agg

# Simulate user choice: option 7 (do not run)
Write-Host ""
Write-Host "Simulating user input: option 7 (Do not run)"
Write-Host "================================"

# Call batch with option 7 (should generate no-op message)
Batch-PerformArchive -Agg $agg -Option 7 -ArchiveMode 'new'

Write-Host ""
Write-Host "Test completed. Check if option 7 handled gracefully (no files, no error)."
