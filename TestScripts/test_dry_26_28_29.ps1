# Dry-run test for indexes 26, 28~29 (should show aggregated summary only)
param([switch]$SkipMain)

$ScriptPath = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"
$mainScript = Join-Path $ScriptPath "!Sync-RawAndSo.ps1"

# Load main script (skip main execution)
. $mainScript -SkipMain -ScriptPath $ScriptPath

# Get base path (the ArcvRoot containing date folders)
$basePath = Split-Path $ScriptPath -Parent

# Find date folders
$dateFolders = @()
try {
    $allDirs = @(Get-ChildItem -LiteralPath $basePath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } | Sort-Object Name)
    Write-Host "Available date folders: $($allDirs.Count)"
    for ($i = 0; $i -lt $allDirs.Count; $i++) {
        Write-Host "$($i+1). $($allDirs[$i].Name)"
    }
} catch {
    Write-Host "Error enumerating folders: $_"
    exit 1
}

# Parse selection: 26,28~29 -> indexes 26,28,29
$selection = "26,28~29"
$indexes = Parse-IndexSelection -Selection $selection -Max $allDirs.Count
Write-Host "Selection '$selection' -> indexes: $($indexes -join ', ')"

# Get folder objects
$selected = @()
foreach ($idx in $indexes) {
    if ($idx -ge 1 -and $idx -le $allDirs.Count) {
        $selected += $allDirs[$idx - 1]
    }
}

if ($selected.Count -eq 0) {
    Write-Host "No folders selected. Exiting."
    exit 0
}

Write-Host "Selected folders: $($selected | ForEach-Object { $_.Name } | Join-String -Separator ', ')"

# ===== Run aggregation and display =====
try {
    Write-Host "`n--- Starting aggregation (dry-run) ---`n"
    $agg = Aggregate-ArchiveCandidates -Folders $selected -Sample 50
    Show-AggregatedSummary -Agg $agg -Sample 50
} catch {
    Write-Host "ERROR during aggregation: $_"
    Write-Host "Stack: $($_.ScriptStackTrace)"
    exit 1
}

# ===== Show options and simulate dry-run =====
Write-Host "`n--- Archive options ---"
Write-Host "1) Archive All"
Write-Host "2) Only Medias"
Write-Host "3) Only RAWs"
Write-Host "4) Only SOs"
Write-Host "5) Medias+RAWs"
Write-Host "6) RAWs+SOs"
Write-Host "7) Do not run"

$option = 1  # Default: Archive All
Write-Host "Using option: $option (dry-run)"

# ===== Run batch with dry-run (no Apply) =====
try {
    Write-Host "`n--- Running dry-run batch archive (option $option) ---`n"
    Batch-PerformArchive -Agg $agg -Option $option -ArchiveMode 'new' -Apply:$false
} catch {
    Write-Host "ERROR during batch archive: $_"
    Write-Host "Stack: $($_.ScriptStackTrace)"
    exit 1
}

Write-Host "`nDry-run completed successfully. No files were moved."
exit 0
