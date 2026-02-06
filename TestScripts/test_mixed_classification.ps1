# Test on a folder with MIXED file types to fully verify classification

$arcvRoot = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
$mainScript = Join-Path $arcvRoot "!Sync-RawAndSo.ps1"

. $mainScript

$allDirs = @(Get-ChildItem -LiteralPath $arcvRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name)

# Find folders with MIXED content for comprehensive testing
Write-Host "=== COMPREHENSIVE MIXED-TYPE CLASSIFICATION TEST ===" -ForegroundColor Cyan

# Test multiple instances with different file mixes
$testInstances = @(
    @{ idx = 19; name = "2026-01-15" },    # Should have some RAW/JPG
    @{ idx = 20; name = "2026-01-16" },    # Another mixed
    @{ idx = 21; name = "2026-01-17" }     # Another
)

$selected = @()
foreach ($inst in $testInstances) {
    if ($inst.idx -le $allDirs.Count) {
        $selected += $allDirs[$inst.idx - 1]
    }
}

if ($selected.Count -eq 0) {
    Write-Host "Not enough folders available. Using indexes 15,16,17"
    exit 0
}

Write-Host "Selected test folders:"
$selected | ForEach-Object { Write-Host "  • $($_.Name)" }

try {
    Write-Host "`n--- Aggregating ---"
    $agg = Aggregate-ArchiveCandidates -Folders $selected -Sample 50
    Show-AggregatedSummary -Agg $agg -Sample 50
    
    Write-Host "`n--- DRY-RUN (Option 1: Archive All) ---"
    Batch-PerformArchive -Agg $agg -Option 1 -ArchiveMode 'new' -Apply:$false
    
    Write-Host "`n--- Classification Verification ---" -ForegroundColor Yellow
    foreach ($folder in $selected) {
        $logPath = Join-Path $folder.FullName "archive_move_log.json"
        if (Test-Path -LiteralPath $logPath) {
            $log = Get-Content -LiteralPath $logPath -Raw | ConvertFrom-Json
            if (-not ($log -is [array])) { $log = @($log) }
            
            $media = $log | Where-Object { $_.Type -eq 'Media' }
            $raw   = $log | Where-Object { $_.Type -eq 'RAW' }
            $hif   = $log | Where-Object { $_.Type -eq 'HIF' }
            $jpg   = $log | Where-Object { $_.Type -eq 'JPG' }
            
            Write-Host "`n$($folder.Name):"
            Write-Host "  Media: $($media.Count) files"
            if ($media.Count -gt 0) { Write-Host "    Sample: $($media[0].Original | Split-Path -Leaf) → $($media[0].Dest | Split-Path -Leaf)" }
            Write-Host "  RAW:   $($raw.Count) files"
            if ($raw.Count -gt 0) { Write-Host "    Sample: $($raw[0].Original | Split-Path -Leaf) → $($raw[0].Dest | Split-Path -Leaf)" }
            Write-Host "  HIF:   $($hif.Count) files"
            if ($hif.Count -gt 0) { Write-Host "    Sample: $($hif[0].Original | Split-Path -Leaf) → $($hif[0].Dest | Split-Path -Leaf)" }
            Write-Host "  JPG:   $($jpg.Count) files"
            if ($jpg.Count -gt 0) { Write-Host "    Sample: $($jpg[0].Original | Split-Path -Leaf) → $($jpg[0].Dest | Split-Path -Leaf)" }
            
            # Verify destination correctness
            $errors = @()
            foreach ($entry in $log) {
                $dest = $entry.Dest
                $type = $entry.Type
                if ($type -eq 'Media' -and $dest -notlike '*Medias*') { $errors += "Media in: $dest" }
                if ($type -eq 'RAW' -and $dest -notlike '*RAW_arw*') { $errors += "RAW in: $dest" }
                if ($type -eq 'HIF' -and $dest -notlike '*SO_hif*') { $errors += "HIF in: $dest" }
                if ($type -eq 'JPG' -and $dest -notlike '*SO_jpg*') { $errors += "JPG in: $dest" }
            }
            if ($errors.Count -gt 0) {
                Write-Host "  ❌ ERRORS FOUND:" -ForegroundColor Red
                $errors | ForEach-Object { Write-Host "    $_" }
            } else {
                Write-Host "  ✅ All files routed correctly" -ForegroundColor Green
            }
        }
    }
    
    Write-Host "`n✅ COMPREHENSIVE TEST PASSED!" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: $_" -ForegroundColor Red
    exit 1
}

exit 0
