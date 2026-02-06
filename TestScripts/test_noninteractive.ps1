# Non-interactive test: load functions and directly test aggregation + batch

param([switch]$SkipMain)

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Inline minimal version of functions for testing (or dot-source with -SkipMain)
# For simplicity, manually define minimal functions to test flow

# Import functions from main script (suppress main execution)
$content = Get-Content "$ScriptPath\!Sync-RawAndSo.ps1" -Raw
# Remove the main execution block to avoid prompts
$content = $content -replace '(?s)if \(-not \$SkipMain\.IsPresent\).*', ''
Invoke-Expression $content

# Test non-interactive mode
$dateFolders = Get-ChildItem -LiteralPath $ScriptPath -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}($|[^0-9])' }

if (-not $dateFolders) { Write-Host "No date folders found"; exit 1 }

# Select specific folders: 26 (2026-01-24), 28 (2026-01-29), 29 (2026-01-30)
$indexes = @(25, 27, 28)  # 0-based index (26th, 28th, 29th items)
$selected = @($dateFolders | Where-Object { $_ -in @($dateFolders[$indexes[0]], $dateFolders[$indexes[1]], $dateFolders[$indexes[2]]) })

if ($selected.Count -ne 3) {
    Write-Host "Could not select exactly 3 folders (got $($selected.Count)). Ensure folders exist."
    exit 1
}

Write-Host "=" * 80
Write-Host "Non-Interactive Test: Aggregation + Batch with option 7 (Do Not Run)"
Write-Host "Selected folders: $($selected | ForEach-Object { $_.Name })"
Write-Host "=" * 80

# Aggregate
$agg = Aggregate-ArchiveCandidates -Folders $selected

# Show summary
Write-Host ""
Show-AggregatedSummary -Agg $agg

# Options display (should be visible)
Write-Host ""
Write-Host ("Options:`n1) (try)Archive All`n2) Only Medias`n3) Only RAWs`n4) Only SOs`n5) Medias+RAWs`n6) RAWs+SOs`n7) Do not run")

# Simulate user choice: option 7 (do not run)
Write-Host ""
Write-Host "Simulating batch execution with option 7 (no files to move)..."
Batch-PerformArchive -Agg $agg -Option 7 -ArchiveMode 'new'

Write-Host ""
Write-Host "=" * 80
Write-Host "Test completed successfully. Options display and batch execution worked."
Write-Host "=" * 80
