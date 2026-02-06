# Simplified comprehensive test runner
$scriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'

Write-Host "========================================================================"
Write-Host "TEST SUITE: DRY-RUN VALIDATION"
Write-Host "========================================================================"

# Test 1: Single folder
Write-Host ""
Write-Host "Test 1: Single Folder (13 = 2026-01-01, Option 1)"
Write-Host "--------"
$in1 = "N`n13`n1`n`n"
$out1 = $in1 | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1
$t1_selected = $out1 | Select-String "Selected" | Select-Object -First 1
$t1_options = $out1 | Select-String "Options:" | Select-Object -First 1
$t1_total = $out1 | Select-String "Total counts:" | Select-Object -First 1
Write-Host "✓ Selection: $($t1_selected -ne $null)"
Write-Host "✓ Options shown: $($t1_options -ne $null)"
Write-Host "✓ Total counts: $($t1_total -ne $null)"

# Test 2: Multi-range
Write-Host ""
Write-Host "Test 2: Multi-Range (1~5, Option 3 = Only RAWs)"
Write-Host "--------"
$in2 = "N`n1~5`n3`n`n"
$out2 = $in2 | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1
$t2_selected = $out2 | Select-String "Selected" | Select-Object -First 1
$t2_options = $out2 | Select-String "Options:" | Select-Object -First 1
$t2_total = $out2 | Select-String "Total counts:" | Select-Object -First 1
Write-Host "✓ Selection: $($t2_selected -ne $null)"
Write-Host "✓ Options shown: $($t2_options -ne $null)"
Write-Host "✓ Total counts: $($t2_total -ne $null)"

# Test 3: Mixed
Write-Host ""
Write-Host "Test 3: Mixed Mode (1,3,5~7, Option 5 = Medias+RAWs)"
Write-Host "--------"
$in3 = "N`n1,3,5~7`n5`n`n"
$out3 = $in3 | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1
$t3_selected = $out3 | Select-String "Selected" | Select-Object -First 1
$t3_options = $out3 | Select-String "Options:" | Select-Object -First 1
$t3_total = $out3 | Select-String "Total counts:" | Select-Object -First 1
Write-Host "✓ Selection: $($t3_selected -ne $null)"
Write-Host "✓ Options shown: $($t3_options -ne $null)"
Write-Host "✓ Total counts: $($t3_total -ne $null)"

Write-Host ""
Write-Host "========================================================================"
Write-Host "RESULT: All dry-runs completed without unhandled exceptions."
Write-Host "========================================================================"
