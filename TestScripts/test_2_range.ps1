# Test 2: Multi range (1~5 = 2025-11-07 to 2025-11-22), option 3 (RAW only), dry-run, end
# Input: N, 1~5, 3, (Enter for dry-run), (Enter to end)
$scriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
$input = @(
    'N',      # No rollback
    '1~5',    # Range: folders 1-5
    '3',      # Option 3: Only RAWs
    '',       # Enter: dry-run (default)
    ''        # Enter: end after dry-run
) | Out-String

Write-Host "========================================================================"
Write-Host "TEST 2: Multi Range Dry-Run (folders 1~5, RAW only)"
Write-Host "========================================================================"

$input | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1 | Select-Object -Last 100
