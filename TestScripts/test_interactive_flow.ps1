# Test harness for interactive flow testing (automated input simulation)
# This script tests the range-selection feature without manual intervention

param([string]$ArcvRoot = 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2')

# Load main script functions (skip main entry point)
. "$ArcvRoot\!Sync-RawAndSo.ps1" -SkipMain

# Get available date folders
$dateFolders = Get-ChildItem -LiteralPath $ArcvRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name

Write-Host "=== Test 1: Single folder selection by index ===" -ForegroundColor Green
Write-Host "Available folders: $($dateFolders.Count) total"
for ($i = 0; $i -lt [Math]::Min(5, $dateFolders.Count); $i++) {
    Write-Host "$($i + 1). $($dateFolders[$i].Name)"
}

Write-Host "`n=== Test 2: Range parser unit test ===" -ForegroundColor Green
$testCases = @(
    @{ Input = "1~3"; Expected = "1,2,3" },
    @{ Input = "1~3,5"; Expected = "1,2,3,5" },
    @{ Input = "1,3,5"; Expected = "1,3,5" },
    @{ Input = "5~2"; Expected = "2,3,4,5" },
    @{ Input = "1~3,5~7"; Expected = "1,2,3,5,6,7" }
)

foreach ($test in $testCases) {
    $result = Parse-IndexSelection -Selection $test.Input -Max $dateFolders.Count
    $resultStr = if ($result) { ($result | Sort-Object | ForEach-Object { $_.ToString() }) -join "," } else { "" }
    $pass = $resultStr -eq $test.Expected
    $status = if ($pass) { "✓ PASS" } else { "✗ FAIL" }
    Write-Host "$status | Input: '$($test.Input)' → Expected: '$($test.Expected)', Got: '$resultStr'"
}

Write-Host "`n=== Test 3: Multi-folder selection logic ===" -ForegroundColor Green
# Test the folder selection with range input
$selection = "1~3"
$idxs = Parse-IndexSelection -Selection $selection -Max $dateFolders.Count
$selectedFolders = $idxs | ForEach-Object { $dateFolders[$_ - 1] }
Write-Host "Selected by range '$selection': $($selectedFolders.Count) folders"
$selectedFolders | ForEach-Object { Write-Host "  - $_" }

Write-Host "`n=== Test 4: Archive preparation (dry-run only) ===" -ForegroundColor Green
# Test the first selected folder for archive readiness
if ($selectedFolders.Count -gt 0) {
    $testFolder = $selectedFolders[0].FullName
    Write-Host "Testing archive on folder: $($selectedFolders[0].Name)"
    
    # Check for RAW/SO folders
    $allFiles = Get-ChildItem -LiteralPath $testFolder -File -Recurse -ErrorAction SilentlyContinue
    Write-Host "  Files in folder: $($allFiles.Count)"
    
    # Categorize by extension
    $mediaExt = @('mp4','mov','mkv')
    $rawExt   = @('arw')
    $soHifExt = @('hif','heic')
    $soJpgExt = @('jpg','jpeg')
    
    $medias = @($allFiles | Where-Object { $mediaExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    $raws   = @($allFiles | Where-Object { $rawExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    $soHif  = @($allFiles | Where-Object { $soHifExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    $soJpg  = @($allFiles | Where-Object { $soJpgExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    
    Write-Host "  Medias: $($medias.Count), RAW: $($raws.Count), SO_hif: $($soHif.Count), SO_jpg: $($soJpg.Count)"
}

Write-Host "`n=== Test 5: SafeExitWithPause (non-blocking check) ===" -ForegroundColor Green
Write-Host "Testing SafeExitWithPause function..."
# Test that the function exists and is callable
try {
    $pauseFunc = Get-Command SafeExitWithPause -ErrorAction Stop
    Write-Host "✓ SafeExitWithPause function loaded successfully"
    Write-Host "  Signature: $($pauseFunc.Definition.Split('{')[0].Trim())"
} catch {
    Write-Host "✗ SafeExitWithPause not found: $_"
}

Write-Host "`n=== Test 6: Unified JSON generation ===" -ForegroundColor Green
# Check for existing unified_archive.json files
$unified = Get-ChildItem -LiteralPath $ArcvRoot -Filter "unified_archive.json" -Recurse -ErrorAction SilentlyContinue
Write-Host "Found $($unified.Count) existing unified_archive.json files"
if ($unified.Count -gt 0) {
    Write-Host "  Sample (most recent):"
    $latest = $unified | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host "  Path: $($latest.Directory.Name)/$($latest.Name)"
    Write-Host "  Size: $($latest.Length) bytes"
}

Write-Host "`n=== All Tests Complete ===" -ForegroundColor Green
