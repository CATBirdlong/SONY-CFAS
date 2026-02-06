# Edge case testing

. 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\!Sync-RawAndSo.ps1' -SkipMain

Write-Host "=== Edge Case Tests ===" -ForegroundColor Cyan

$testFolder = 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\2025-11-21 - Copyfortest'

# Test 1: Out-of-range indices
Write-Host "`n[Test 1: Out-of-range indices]"
$result = Parse-IndexSelection -Selection "1~100" -Max 33
Write-Host "Input: '1~100', Max: 33 → Result: $($result.Count) indices"
if ($result.Count -eq 33) { Write-Host "✓ PASS: Correctly clamped to max" } else { Write-Host "✗ FAIL: Expected 33, got $($result.Count)" }

# Test 2: Single index that exceeds max
Write-Host "`n[Test 2: Index exceeds max]"
$result = Parse-IndexSelection -Selection "50" -Max 33
Write-Host "Input: '50', Max: 33 → Result count: $(if ($result) { $result.Count } else { 0 })"
if ($result.Count -eq 0) { Write-Host "✓ PASS: Out-of-range index filtered" } else { Write-Host "✗ FAIL: Should be empty" }

# Test 3: Mixed with duplicates
Write-Host "`n[Test 3: Duplicate indices]"
$result = Parse-IndexSelection -Selection "1,1,1,2,2,3" -Max 33
Write-Host "Input: '1,1,1,2,2,3' → Result: $($result -join ',')"
if ($result.Count -eq 3 -and ($result -eq @(1,2,3) -or ($result | Sort-Object | ForEach-Object { $_.ToString() }) -join "," -eq "1,2,3")) { Write-Host "✓ PASS: Duplicates removed" } else { Write-Host "✗ FAIL: Should be 1,2,3" }

# Test 4: Reverse range
Write-Host "`n[Test 4: Reverse range (high~low)]"
$result = Parse-IndexSelection -Selection "10~5" -Max 33
$sorted = $result | Sort-Object
$expectedStr = "5,6,7,8,9,10"
$resultStr = ($sorted | ForEach-Object { $_.ToString() }) -join ","
Write-Host "Input: '10~5' → Result: $resultStr"
if ($resultStr -eq $expectedStr) { Write-Host "✓ PASS: Range reversed and handled correctly" } else { Write-Host "✗ FAIL: Expected $expectedStr" }

# Test 5: SafeExitWithPause with timeout 0
Write-Host "`n[Test 5: SafeExitWithPause behavior]"
try {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    SafeExitWithPause -Message "[TEST] This should not block" -TimeoutSec 0 2>&1 | Out-Null
    $sw.Stop()
    Write-Host "Execution time: $($sw.ElapsedMilliseconds) ms"
    if ($sw.ElapsedMilliseconds -lt 1000) {
        Write-Host "✓ PASS: Function exits without blocking when TimeoutSec=0"
    } else {
        Write-Host "✗ FAIL: Function took too long (likely blocked on Read-Host)"
    }
} catch {
    Write-Host "✗ ERROR: $_"
}

# Test 6: Archive on folder with no RAW/SO
Write-Host "`n[Test 6: Archive readiness check]"
$allFiles = Get-ChildItem -LiteralPath $testFolder -File -Recurse -ErrorAction SilentlyContinue
$archiveExt = @('mp4','mov','mkv','arw','hif','heic','jpg','jpeg')
$archivable = @($allFiles | Where-Object { $archiveExt -contains ($_.Extension.TrimStart('.').ToLower()) })
Write-Host "Total files: $($allFiles.Count)"
Write-Host "Archivable files: $($archivable.Count)"
if ($archivable.Count -gt 0) {
    Write-Host "✓ PASS: Folder has archivable content"
} else {
    Write-Host "⚠ INFO: No archivable files in test folder"
}

# Test 7: Verify latest.log exists and is writable
Write-Host "`n[Test 7: Logging system]"
$logPath = Join-Path (Split-Path $testFolder -Parent) "latest.log"
if (Test-Path -LiteralPath $logPath) {
    Write-Host "✓ PASS: latest.log exists"
    $content = Get-Content -LiteralPath $logPath -ErrorAction SilentlyContinue
    Write-Host "  Size: $((Get-Item -LiteralPath $logPath).Length) bytes"
    Write-Host "  Latest entry sample: $(($content[-1] -replace '^.*]\s+', ''))"
} else {
    Write-Host "⚠ INFO: latest.log not found at $logPath"
}

Write-Host "`n=== All Edge Case Tests Complete ===" -ForegroundColor Green
