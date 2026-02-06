# Test 4: Instance test (1,3,5~7), cancel before archive
# Input: N, 1,3,5~7, X (invalid), X (invalid), ... until timeout or manual exit
# This simulates user taking selection to completion UI but NOT executing archive
$scriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
$input = @(
    'N',         # No rollback
    '1,3,5~7'    # Mixed: folder 1, 3, and range 5-7
    # Do NOT provide option selection; script will wait for input and user can Ctrl+C
) | Out-String

Write-Host "========================================================================"
Write-Host "TEST 4: Instance Test (folders 1,3,5~7, cancel at archive selection)"
Write-Host "========================================================================"
Write-Host "Note: This test will display folder selection, then wait for option input."
Write-Host "Script will time out or require manual Ctrl+C to exit (user takes control)."
Write-Host "========================================================================"

$input | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1
