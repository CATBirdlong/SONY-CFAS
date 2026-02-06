# Comprehensive test runner with summary
$scriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
$tests = @(
    @{ Name = 'Test 1: Single (13, Opt 1)', Input = "N`n13`n1`n`n"; ExpectFolders = 1 },
    @{ Name = 'Test 2: Range (1~5, Opt 3)', Input = "N`n1~5`n3`n`n"; ExpectFolders = 5 },
    @{ Name = 'Test 3: Mixed (1,3,5~7, Opt 5)', Input = "N`n1,3,5~7`n5`n`n"; ExpectFolders = 5 }
)

$results = @()

foreach ($test in $tests) {
    Write-Host ""
    Write-Host "========================================================================"
    Write-Host $test.Name
    Write-Host "========================================================================"
    
    $output = $test.Input | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1
    
    # Extract key info
    $selectedLine = $output | Select-String "^Selected indexes"
    $optionsLine = $output | Select-String "^Options:"
    $summaryLine = $output | Select-String "^Archive candidates summary"
    $totalLine = $output | Select-String "^Total counts:"
    $runningLine = $output | Select-String "^Running dry-run"
    
    Write-Host "✓ Selected: $($selectedLine -match '\d+' | Out-Null; $selectedLine)"
    Write-Host "✓ Options visible: $([bool]$optionsLine)"
    Write-Host "✓ Summary shown: $([bool]$summaryLine)"
    Write-Host "✓ Total counts: $($totalLine)"
    Write-Host "✓ Batch executed: $([bool]$runningLine)"
    
    $results += @{
        Name = $test.Name
        Selected = $([bool]$selectedLine)
        OptionsShown = $([bool]$optionsLine)
        SummaryShown = $([bool]$summaryLine)
        BatchExecuted = $([bool]$runningLine)
    }
}

Write-Host ""
Write-Host "========================================================================"
Write-Host "SUMMARY"
Write-Host "========================================================================"
$results | ForEach-Object {
    $status = if ($_.Selected -and $_.OptionsShown -and $_.SummaryShown -and $_.BatchExecuted) { "✓ PASS" } else { "✗ FAIL" }
    Write-Host "$status | $($_.Name)"
}
