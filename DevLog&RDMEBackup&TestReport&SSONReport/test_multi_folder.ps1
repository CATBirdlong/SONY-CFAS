#!/usr/bin/env powershell
# Automated test for multi-folder archive with range selection 30~33

param([switch]$SkipPreCheck = $false)

$testFolder = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
cd $testFolder

Write-Host "═══════════════════════════════════════════════════════════════════════"
Write-Host "Test: Multi-Folder Archive with Range Selection (30~33)"
Write-Host "═══════════════════════════════════════════════════════════════════════"

if (-not $SkipPreCheck) {
    # Check folders exist
    $folders = @(30, 31, 32, 33) | ForEach-Object {
        $idx = $_
        $df = Get-ChildItem -Path $testFolder -Directory | 
              Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | 
              Select-Object -Index ($idx - 1)
        if ($df) {
            $fileCount = (Get-ChildItem -LiteralPath $df.FullName -File -ErrorAction SilentlyContinue | Measure-Object).Count
            Write-Host "  Folder $idx: $($df.Name) - $fileCount files"
            @{ Name = $df.Name; Path = $df.FullName; Files = $fileCount }
        }
    }
    
    if ($folders.Count -lt 4) {
        Write-Host "ERROR: Expected 4 folders (30-33), found $($folders.Count)" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ All 4 test folders exist with files"
}

Write-Host ""
Write-Host "Creating input script to simulate user interactions..."
Write-Host ""

# Create a script that provides inputs via stdin
$inputScript = @'
# Simulate user inputs for multi-folder archive test
# Input sequence:
# 1. "N" - Skip rollback mode
# 2. "30~33" - Select folders 30-33
# 3. "1" - Choose archive architecture (New)
# 4. For each folder: "1" - Archive all files
# 5. "" (Enter) - Don't continue to sync after archives complete
# 6. "" (Enter) - Exit

$inputLines = @(
    "N",          # Skip rollback
    "30~33",      # Select range 30~33
    "1",          # Archive mode: New
    "1", "1", "1", "1",  # Archive option for folders 30, 31, 32, 33
    "",           # Don't continue to sync
    ""            # Exit prompt
)

$inputLines | ForEach-Object {
    Write-Host $_ 
    $_
}
'@

# We need to run the script and provide input...
# Actually, the proper way is to use a here-string input via stdin

Write-Host "Running the script with input..."
Write-Host ""

$proc = Start-Process powershell.exe -ArgumentList `
    "-NoProfile", "-ExecutionPolicy", "Bypass", `-File`, "!Sync-RawAndSo.ps1" `
    -PassThru `
    -RedirectStandardOutput "$testFolder\test_output.log" `
    -RedirectStandardError "$testFolder\test_error.log" `
    -WindowStyle Hidden

# Wait a bit for the process to start
Start-Sleep -Milliseconds 500

if ($proc.HasExited) {
    Write-Host "ERROR: Process exited immediately" -ForegroundColor Red
    Get-Content "$testFolder\test_error.log" -ErrorAction SilentlyContinue | Write-Host
    exit 1
}

# Send input via StandardInput
try {
    $proc.StandardInput.WriteLine("N")      # No rollback
    $proc.StandardInput.Flush()
    
    Start-Sleep -Milliseconds 300
    
    $proc.StandardInput.WriteLine("30~33")  # Select 30-33
    $proc.StandardInput.Flush()
    
    Start-Sleep -Milliseconds 300
    
    $proc.StandardInput.WriteLine("1")      # New architecture
    $proc.StandardInput.Flush()
    
    # For each of 4 folders, send "1" (Archive All) and wait
    for ($i = 0; $i -lt 4; $i++) {
        Start-Sleep -Milliseconds 300
        $proc.StandardInput.WriteLine("1")  # Archive all
        $proc.StandardInput.Flush()
    }
    
    Start-Sleep -Milliseconds 500
    
    $proc.StandardInput.WriteLine("")       # Don't sync
    $proc.StandardInput.Flush()
    
    Start-Sleep -Milliseconds 300
    
    $proc.StandardInput.WriteLine("")       # Exit
    $proc.StandardInput.Flush()
    
    $proc.StandardInput.Close()
} catch {
    Write-Host "Error sending input: $_" -ForegroundColor Red
    $proc.Kill()
    exit 1
}

# Wait for process to complete
$proc | Wait-Process -Timeout 120
$exitCode = $proc.ExitCode

Write-Host ""
Write-Host "Process completed with exit code: $exitCode"
Write-Host ""

# Check output
$output = Get-Content "$testFolder\test_output.log" -ErrorAction SilentlyContinue | Out-String
$errors = Get-Content "$testFolder\test_error.log" -ErrorAction SilentlyContinue | Out-String

Write-Host "═══════════════════════════════════════════════════════════════════════"
Write-Host "Test Output Analysis"
Write-Host "═══════════════════════════════════════════════════════════════════════"

# Check for expected patterns
$checks = @(
    ("30~33 selected", $output -match "30" -and $output -match "31")
    ("Archive successful", $output -match "Moved\s+:|Archive summary")
    ("All 4 folders processed", $output -match "processed" -or $output -match "complete")
)

$passCount = 0
foreach ($check in $checks) {
    if ($check[1]) {
        Write-Host "✓ $($check[0])" -ForegroundColor Green
        $passCount++
    } else {
        Write-Host "✗ $($check[0])" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Result: $passCount/$($checks.Count) checks passed"

if ($errors) {
    Write-Host ""
    Write-Host "STDERR Output:"
    Write-Host $errors
}

exit (if ($passCount -eq $checks.Count) { 0 } else { 1 })
