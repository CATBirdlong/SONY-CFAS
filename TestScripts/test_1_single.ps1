# Test 1: Single folder (13 = 2026-01-01), option 1 (Archive All), dry-run, end
# Input: N (no rollback), 13, 1, (Enter for dry-run), (Enter to end)
$scriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
$input = @(
    'N',      # No rollback
    '13',     # Single folder: 2026-01-01 (index 13)
    '1',      # Option 1: Archive All
    '',       # Enter: dry-run (default)
    ''        # Enter: end after dry-run
) | Out-String

Write-Host "========================================================================"
Write-Host "TEST 1: Single Folder Dry-Run (folder 13 = 2026-01-01)"
Write-Host "========================================================================"

$input | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1 | Select-Object -Last 100
