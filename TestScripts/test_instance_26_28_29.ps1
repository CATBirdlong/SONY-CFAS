# Test: aggregated dry-run for folders 26,28,29 (indexes 26,28,29)

$root = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
. "$root\!Sync-RawAndSo.ps1"

# discover date folders (sorted by name)
$dateFolders = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}($|[^0-9])' } | Sort-Object Name

$indexes = @(26,28,29)
$selected = @()
foreach ($i in $indexes) {
    if ($i -le $dateFolders.Count -and $i -ge 1) { $selected += $dateFolders[$i - 1] } else { Write-Host "Index $i out of range" }
}

Write-Host "Selected folders: " ($selected | ForEach-Object Name) -join ', '

$agg = Aggregate-ArchiveCandidates -Folders $selected -Sample 5
Show-AggregatedSummary -Agg $agg

# Ask user for option: for automated test choose 1 (Archive All)
$opt = 1
Write-Host "Running dry-run batch archive with option: $opt (dry-run only)"
Batch-PerformArchive -Agg $agg -Option $opt -ArchiveMode 'new'

Write-Host "Test completed (dry-run). Review the generated archive_summary.txt and unified_archive.json files under each folder."