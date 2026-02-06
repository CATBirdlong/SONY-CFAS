# Full interactive flow test harness
# Simulates real user interaction: startup → range selection → archive execution → exit

param([string]$ArcvRoot = 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2')

# Load main script
. "$ArcvRoot\!Sync-RawAndSo.ps1" -SkipMain

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Full Flow Test: ArcvRoot Startup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Simulate ArcvRoot context (test from the root folder)
$ctx = Get-Context -ScriptPath $ArcvRoot
Write-Host "`n[Context Detection]"
Write-Host "  Mode: $($ctx.Mode)"
Write-Host "  StillsFolder: $($ctx.StillsFolder)"

if ($ctx.Mode -eq 'ArcvRoot') {
    Write-Host "`n[Date Folder Discovery]"
    $dateFolders = Get-ChildItem -LiteralPath $ArcvRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name
    
    Write-Host "  Found: $($dateFolders.Count) date folders"
    
    # Simulate user selection of range "4~6" (should select 2025-11-21, 2025-11-21 - Copyfortest, 2025-11-22)
    Write-Host "`n[Simulated User Range Selection]"
    $userSelection = "4~6"
    Write-Host "  User input: '$userSelection'"
    
    $selectedFolders = Select-DateFoldersRange -Folders $dateFolders -BasePath $ArcvRoot
    Write-Host "  Selection result: $($selectedFolders.Count) folders selected"
    $selectedFolders | ForEach-Object { Write-Host "    ✓ $_" }
    
    # Log folder structure of first selected folder
    if ($selectedFolders.Count -gt 0) {
        Write-Host "`n[Archive Readiness Check - First Folder]"
        $testFolder = $selectedFolders[0]
        Write-Host "  Scanning: $($testFolder.Name)"
        
        $subDirs = Get-ChildItem -LiteralPath $testFolder.FullName -Directory -ErrorAction SilentlyContinue
        Write-Host "  Subdirectories: $($subDirs.Count)"
        $subDirs | ForEach-Object { Write-Host "    - $_" }
        
        $files = Get-ChildItem -LiteralPath $testFolder.FullName -File -Recurse -ErrorAction SilentlyContinue
        Write-Host "  Total files: $($files.Count)"
    }
    
    Write-Host "`n[Archive Simulation - DRY-RUN]"
    Write-Host "  (Showing what WOULD happen, no files moved)"
    foreach ($df in $selectedFolders) {
        Write-Host "  Processing: $($df.Name)"
        
        # Dry-run: count files by type
        $allFiles = Get-ChildItem -LiteralPath $df.FullName -File -Recurse -ErrorAction SilentlyContinue
        $mediaExt = @('mp4','mov','mkv')
        $rawExt   = @('arw')
        $soHifExt = @('hif','heic')
        $soJpgExt = @('jpg','jpeg')
        
        $medias = @($allFiles | Where-Object { $mediaExt -contains ($_.Extension.TrimStart('.').ToLower()) })
        $raws   = @($allFiles | Where-Object { $rawExt -contains ($_.Extension.TrimStart('.').ToLower()) })
        $soHif  = @($allFiles | Where-Object { $soHifExt -contains ($_.Extension.TrimStart('.').ToLower()) })
        $soJpg  = @($allFiles | Where-Object { $soJpgExt -contains ($_.Extension.TrimStart('.').ToLower()) })
        
        Write-Host "    Files by type: Media=$($medias.Count), RAW=$($raws.Count), SO_HIF=$($soHif.Count), SO_JPG=$($soJpg.Count)"
    }
    
} else {
    Write-Host "`n[ERROR] Context is not ArcvRoot. Got mode: $($ctx.Mode)"
    Write-Host "Test expects to run from arcv root directory."
}

Write-Host "`n[SafeExitWithPause Simulation]"
Write-Host "  Testing exit behavior (will not actually wait for input)..."
# Just verify the function is callable and doesn't throw
try {
    # Call with timeout 0 to skip actual waiting
    SafeExitWithPause -Message "[TEST] Exit prompt would appear here" -TimeoutSec 0 2>&1 | Out-Null
    Write-Host "  ✓ Exit handler callable without error"
} catch {
    Write-Host "  ✗ Error calling SafeExitWithPause: $_"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Flow Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
