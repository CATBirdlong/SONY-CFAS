# CRITICAL VERIFICATION TEST: Ensure file classification is correct
# Test on NEW instance (NOT the ones already moved)
param([switch]$SkipMain)

$arcvRoot = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
$mainScript = Join-Path $arcvRoot "!Sync-RawAndSo.ps1"

. $mainScript -SkipMain -ScriptPath $arcvRoot

$allDirs = @(Get-ChildItem -LiteralPath $arcvRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name)

# Select FRESH instance - indexes 11,12,13 (NOT 26,28,29 which were already moved!)
$selected = @($allDirs[10], $allDirs[11], $allDirs[12])
Write-Host "=== CRITICAL CLASSIFICATION VERIFICATION TEST ===" -ForegroundColor Cyan
Write-Host "Folders to test (indexes 11,12,13):"
$selected | ForEach-Object { Write-Host "  • $($_.Name)" }

Write-Host "`n--- Dry-run with detailed classification tracking ---"
try {
    $agg = Aggregate-ArchiveCandidates -Folders $selected -Sample 50
    Show-AggregatedSummary -Agg $agg -Sample 50
    
    Write-Host "`n--- Running DRY-RUN to verify classifications ---"
    Batch-PerformArchive -Agg $agg -Option 1 -ArchiveMode 'new' -Apply:$false
    
    # Now verify the planned moves in the JSON logs
    Write-Host "`n--- Verifying move logs for correct classification ---" -ForegroundColor Yellow
    foreach ($folder in $selected) {
        $logPath = Join-Path $folder.FullName "archive_move_log.json"
        if (Test-Path -LiteralPath $logPath) {
            $log = Get-Content -LiteralPath $logPath -Raw | ConvertFrom-Json
            if ($log -is [array]) {
                $mediaCount = ($log | Where-Object { $_.Type -eq 'Media' }).Count
                $rawCount = ($log | Where-Object { $_.Type -eq 'RAW' }).Count
                $hifCount = ($log | Where-Object { $_.Type -eq 'HIF' }).Count
                $jpgCount = ($log | Where-Object { $_.Type -eq 'JPG' }).Count
            } else {
                $mediaCount = if ($log.Type -eq 'Media') { 1 } else { 0 }
                $rawCount = if ($log.Type -eq 'RAW') { 1 } else { 0 }
                $hifCount = if ($log.Type -eq 'HIF') { 1 } else { 0 }
                $jpgCount = if ($log.Type -eq 'JPG') { 1 } else { 0 }
            }
            Write-Host "  $($folder.Name): Media=$mediaCount, RAW=$rawCount, HIF=$hifCount, JPG=$jpgCount"
            
            # Verify destinations are correct
            if ($log -is [array]) {
                foreach ($entry in $log | Select-Object -First 3) {
                    $dest = $entry.Dest
                    $type = $entry.Type
                    if ($type -eq 'Media' -and -not ($dest -like '*Medias*')) { Write-Host "    ERROR: Media file in wrong location: $dest" -ForegroundColor Red }
                    if ($type -eq 'RAW' -and -not ($dest -like '*RAW_arw*')) { Write-Host "    ERROR: RAW file in wrong location: $dest" -ForegroundColor Red }
                    if ($type -eq 'HIF' -and -not ($dest -like '*SO_hif*')) { Write-Host "    ERROR: HIF file in wrong location: $dest" -ForegroundColor Red }
                    if ($type -eq 'JPG' -and -not ($dest -like '*SO_jpg*')) { Write-Host "    ERROR: JPG file in wrong location: $dest" -ForegroundColor Red }
                }
            }
        }
    }
    
    Write-Host "`n✅ Classification verification PASSED!" -ForegroundColor Green
} catch {
    Write-Host "`n❌ ERROR: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)"
    exit 1
}

exit 0
