# Test 3: Mixed (1,3,5~7), option 5 (Medias+RAWs), dry-run, end
# Input: N, 1,3,5~7, 5, (Enter for dry-run), (Enter to end)
$scriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
$input = @(
    'N',         # No rollback
    '1,3,5~7',   # Mixed: folder 1, 3, and range 5-7
    '5',         # Option 5: Medias+RAWs
    '',          # Enter: dry-run (default)
    ''           # Enter: end after dry-run
) | Out-String

Write-Host "========================================================================"
Write-Host "TEST 3: Mixed Mode Dry-Run (folders 1,3,5~7, Medias+RAWs)"
Write-Host "========================================================================"

$input | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1 | Select-Object -Last 100
