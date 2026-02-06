# Simple automated test of the range selection and multi-folder archive

$testFolder = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
cd $testFolder

# Create input file with all responses
$inputs = @(
    "N"       # Skip rollback
    "30~33"   # Select range
    "1"       # Archive mode: New
    "1"       # Archive folder 30
    "1"       # Archive folder 31  
    "1"       # Archive folder 32
    "1"       # Archive folder 33
    ""        # Don't sync
    ""        # Exit
) -join "`r`n"

Write-Host "Test: Multi-folder archive with range 30~33"
Write-Host "=============================================="
Write-Host ""

# Write inputs to a temp file and pipe to script
$inputs | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!Sync-RawAndSo.ps1" 2>&1 | Tee-Object -FilePath test_result.log | `
    Select-String -Pattern "Selected|Archive|complete|Moved|All archives" | Write-Host

Write-Host ""
Write-Host "✓ Test completed. Check test_result.log for full output."
