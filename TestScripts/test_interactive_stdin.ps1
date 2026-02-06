# Interactive instance test with stdin simulation
# This will actually run the Sync-RawAndSo script with simulated user input

$arcvRoot = 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
$scriptPath = Join-Path $arcvRoot '!Sync-RawAndSo.ps1'

# Prepare input sequence:
# 1. "N" - No to rollback at startup
# 2. "1" - Select folder 1 from ArcvRoot
# 3. "1" - Select archive mode (New)
# 4. "1" - Select archive option (All files)
# 5. "Y" - Move all scrap files
# 6. "N" - Don't send to Recycle Bin

$inputSequence = @(
    "N",      # No rollback
    "1",      # Single folder selection (2025-11-07)
    "1",      # New archive mode
    "1",      # Archive all files
    "C",      # Continue to sync
    "1",      # Matching strategy option
    "Y",      # Move scrap files
    "N"       # Don't delete to Recycle
) -join "`n"

Write-Host "=== Interactive Instance Test ===" -ForegroundColor Cyan
Write-Host "Script: $scriptPath"
Write-Host "Test sequence:"
$inputSequence.Split("`n") | ForEach-Object { Write-Host "  > $_" }
Write-Host ""

# Run script with piped input
$result = $inputSequence | & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1

# Parse output for key events
Write-Host "=== Test Output ===" -ForegroundColor Green
$output = $result | Out-String

# Extract key information
if ($output -match "Archive summary") {
    Write-Host "✓ Archive completed"
    if ($output -match "Moved\s+:\s+(\d+)") {
        Write-Host "  Files moved: $($matches[1])"
    }
}

if ($output -match "No scrap files detected") {
    Write-Host "✓ Sync phase: No scrap files (expected for already-archived folder)"
}

if ($output -match "Scrap files detected") {
    Write-Host "✓ Sync phase: Scrap files found and moved"
}

# Check for SafeExitWithPause behavior
if ($output -match "press Enter|Press Enter" ) {
    Write-Host "✓ Exit pause prompt appears as expected"
}

Write-Host ""
Write-Host "=== Log Files Generated ===" -ForegroundColor Green
$logsPath = 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
Get-ChildItem -LiteralPath $logsPath -Filter "latest.log" | ForEach-Object {
    Write-Host "Latest log: $($_.Name)"
    Write-Host "  Size: $($_.Length) bytes"
    Write-Host "  Modified: $($_.LastWriteTime)"
}

Write-Host ""
Write-Host "=== Interactive Test Complete ===" -ForegroundColor Cyan
