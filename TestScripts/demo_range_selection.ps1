# Real-world interactive demo script
# This simulates how users will interact with the enhanced range-selection feature

. 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\!Sync-RawAndSo.ps1' -SkipMain

Write-Host ""
Write-Host "===== Sync-RawAndSo v2.1 - Interactive Demo (Range Selection) =====" -ForegroundColor Cyan
Write-Host ""

$arcvRoot = 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
$dateFolders = Get-ChildItem -LiteralPath $arcvRoot -Directory |
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name

Write-Host "[Folder List] Available Date Folders ($($dateFolders.Count) total):" -ForegroundColor Yellow
Write-Host ""
for ($i = 0; $i -lt [Math]::Min(15, $dateFolders.Count); $i++) {
    Write-Host "   $($i+1). $($dateFolders[$i].Name)" -ForegroundColor White
}
if ($dateFolders.Count -gt 15) {
    Write-Host "   ... and $($dateFolders.Count - 15) more folders" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[DEMO 1] Single folder selection" -ForegroundColor Green
Write-Host "User input: 4"
$result = Parse-IndexSelection -Selection "4" -Max $dateFolders.Count
Write-Host "Selected: $($dateFolders[$result[0]-1].Name)" -ForegroundColor Green
Write-Host "Result: 1 folder selected" -ForegroundColor Green
Write-Host ""

Write-Host "[DEMO 2] Range selection" -ForegroundColor Green
Write-Host "User input: 1~5"
$result = Parse-IndexSelection -Selection "1~5" -Max $dateFolders.Count
Write-Host "Selected indexes: $($result -join ', ')" -ForegroundColor Green
Write-Host "Folders:" -ForegroundColor Green
$result | ForEach-Object { Write-Host "  * $($dateFolders[$_-1].Name)" -ForegroundColor Green }
Write-Host "Result: $($result.Count) folders selected" -ForegroundColor Green
Write-Host ""

Write-Host "[DEMO 3] Non-contiguous list" -ForegroundColor Green
Write-Host "User input: 1,3,5,10"
$result = Parse-IndexSelection -Selection "1,3,5,10" -Max $dateFolders.Count
Write-Host "Selected indexes: $($result -join ', ')" -ForegroundColor Green
Write-Host "Folders:" -ForegroundColor Green
$result | ForEach-Object { Write-Host "  * $($dateFolders[$_-1].Name)" -ForegroundColor Green }
Write-Host "Result: $($result.Count) folders selected" -ForegroundColor Green
Write-Host ""

Write-Host "[DEMO 4] Mixed range and list" -ForegroundColor Green
Write-Host "User input: 1~3,10~12"
$result = Parse-IndexSelection -Selection "1~3,10~12" -Max $dateFolders.Count
Write-Host "Selected indexes: $($result -join ', ')" -ForegroundColor Green
Write-Host "Folders:" -ForegroundColor Green
$result | ForEach-Object { Write-Host "  * $($dateFolders[$_-1].Name)" -ForegroundColor Green }
Write-Host "Result: $($result.Count) folders selected" -ForegroundColor Green
Write-Host ""

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[Benefits] Range Selection Feature:" -ForegroundColor Magenta
Write-Host "  + Quick archive multiple dates at once (e.g., 1~5 instead of 1,1,1,1,1)" -ForegroundColor White
Write-Host "  + Select non-contiguous folders easily (e.g., 1,3,5)" -ForegroundColor White
Write-Host "  + Flexible syntax supports ranges, lists, and mixed notation" -ForegroundColor White
Write-Host "  + Clear confirmation shows exactly what was selected" -ForegroundColor White
Write-Host ""

Write-Host "[SUCCESS] DEMO COMPLETE" -ForegroundColor Green
Write-Host ""
