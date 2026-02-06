# Simulate instance test for selection '1,3,5~7' without running archive
$scriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
. "$scriptPath\!Sync-RawAndSo.ps1" -SkipMain

$selection = '1,3,5~7'
$dateFolders = Get-ChildItem -LiteralPath $scriptPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}($|[^0-9])' }
$idxs = Parse-IndexSelection -Selection $selection -Max $dateFolders.Count
$selected = $idxs | ForEach-Object { $dateFolders[$_ - 1] }

Write-Host "Simulated selection: $selection -> indexes: $($idxs -join ', ')" -ForegroundColor Cyan
Write-Host "Selected folders: $($selected | ForEach-Object { $_.Name } -join ', ')" -ForegroundColor Cyan

$agg = Aggregate-ArchiveCandidates -Folders $selected
Show-AggregatedSummary -Agg $agg

Write-Host "\nNOTE: Archive NOT executed per user instruction. Batch-PerformArchive not called."
