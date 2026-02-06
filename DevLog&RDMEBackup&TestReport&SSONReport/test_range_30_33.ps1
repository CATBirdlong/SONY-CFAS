# Test script to verify range selection with folders 30~33

# Set working directory
Set-Location "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"

# Directly call the main script with input simulated
# We'll use a process to test stdin more reliably
$process = Start-Process powershell.exe -ArgumentList `
    "-NoProfile","-ExecutionPolicy","Bypass","-File","!Sync-RawAndSo.ps1" `
    -PassThru `
    -NoNewWindow

# Give it a moment to start
Start-Sleep -Milliseconds 500

# Try sending inputs via the process
if (-not $process.HasExited) {
    # First prompt: "Run rollback mode before sync? (Y/N)" - send N
    $process.StandardInput.WriteLine("N")
    $process.StandardInput.Flush()
    
    Start-Sleep -Milliseconds 500
    
    # Second prompt: range selection - send 30~33
    $process.StandardInput.WriteLine("30~33")
    $process.StandardInput.Flush()
    
    Start-Sleep -Seconds 2
    
    # Third prompt: archive mode choice - send 1 (new)
    $process.StandardInput.WriteLine("1")
    $process.StandardInput.Flush()
    
    Start-Sleep -Milliseconds 500
    
    # Fourth prompt: archive option - send 1 (Archive All)
    $process.StandardInput.WriteLine("1")
    $process.StandardInput.Flush()
    
    Start-Sleep -Milliseconds 500
    
    # Fifth prompt: continue to sync? - send Enter (no sync)
    $process.StandardInput.WriteLine("")
    $process.StandardInput.Flush()
    
    Start-Sleep -Milliseconds 500
    
    # Exit prompt - send Enter
    $process.StandardInput.WriteLine("")
    $process.StandardInput.Flush()
    
    # Wait for process to complete or timeout
    $process | Wait-Process -Timeout 60 -ErrorAction SilentlyContinue
}

if (-not $process.HasExited) {
    Write-Host "Process still running, killing it..."
    $process.Kill()
} else {
    Write-Host "Process completed with exit code: $($process.ExitCode)"
}
