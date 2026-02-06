# Quick verification test: Mixed (1,3,5~7) with option 7 after fix
$scriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
Write-Host "Quick Test: Mixed (1,3,5~7) + Option 7 (Do not run)"
Write-Host "======================================================"

$input_seq = "N`n1,3,5~7`n7`n`n`n"
$output = $input_seq | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1

$has_selected = $output | Select-String "^Selected" | Select-Object -First 1
$has_options = $output | Select-String "^Options:" | Select-Object -First 1
$has_total = $output | Select-String "^Total counts:" | Select-Object -First 1
$has_error = $output | Select-String "ERROR.*Cannot bind" | Select-Object -First 1
$has_dryrun = $output | Select-String "Dry-run complete|Running dry-run" | Select-Object -First 1

Write-Host "✓ Selection shown: $($has_selected -ne $null)"
Write-Host "✓ Options shown: $($has_options -ne $null)"
Write-Host "✓ Total counts shown: $($has_total -ne $null)"
Write-Host "✓ No Path null error: $($has_error -eq $null)" 
Write-Host "✓ Dry-run completion message: $($has_dryrun -ne $null)"

if ($has_selected -and $has_options -and $has_total -and $has_error -eq $null) {
    Write-Host ""
    Write-Host "✅ TEST PASSED: Mixed mode with option 7 works correctly!"
} else {
    Write-Host ""
    Write-Host "❌ TEST FAILED: Some checks did not pass"
    Write-Host "Output tail:"
    $output | Select-Object -Last 20 | Write-Host
}
