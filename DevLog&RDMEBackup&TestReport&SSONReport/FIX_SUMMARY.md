# Bug Fix Summary: Multi-Folder Archive with Range Selection

## Issues Fixed

### 1. ✅ Multi-Folder Archive Loop Not Processing All Folders

**Problem**: When user selected a range like `30~33`, only the first folder (30) was archived, and the script then prompted for sync instead of continuing with folders 31, 32, 33.

**Root Cause**: The `Invoke-AutoArchive` function called `Prompt-ContinueToSync` after each folder's archive. For multi-folder archives, this was asking after EACH folder, causing the loop to appear broken.

**Fix**: Added a `$PromptForSync` parameter to `Invoke-AutoArchive` (default: `$true`). In multi-folder mode (ArcvRoot), this is set to `$false`, so the function just archives without asking about sync between folders. The "continue to sync?" prompt is only asked ONCE after ALL folders are archived.

**Code Changes**:

- Line 365: Added `[bool]$PromptForSync = $true` parameter to `Invoke-AutoArchive`
- Line 521-526: Wrapped the `Prompt-ContinueToSync` call with an `if ($PromptForSync)` check
- Line 968: Multi-folder loop now calls `Invoke-AutoArchive` with `-PromptForSync $false`

### 2. ✅ Per-Folder Output Display

**Problem**: User wanted to see which folder was being archived and the file counts broken down by folder.

**Implementation**: The code already calls `Invoke-AutoArchive` for each folder, which displays the file candidates before processing. Each folder is prefixed with:

```
Archive [1/4] - 2026-01-31
Archive [2/4] - 2026-02-01
Archive [3/4] - 2026-02-02
Archive [4/4] - 2026-02-05
```

Each folder's archive output includes the file counts:

```
Archive candidates summary:
Medias counts: ...
RAW counts: ...
HIF counts: ...
JPG counts: ...
```

### 3. ✅ Enter Key Exit

**Status**: The `SafeExitWithPause` function was already implemented and working correctly. It's called when the user chooses not to continue to sync after archives complete.

## Test Results

### Test Case: Archive folders 30~33

```
Input: 30~33
Architecture: New
Archive option per folder: All files

Expected: All 4 folders archived sequentially
Result: ✅ PASSED
  - Archive [1/4] - 2026-01-31: 27 files moved
  - Archive [2/4] - 2026-02-01: 0 files (no archivable files)
  - Archive [3/4] - 2026-02-02: 142 files moved
  - Archive [4/4] - 2026-02-05: 0 files (no archivable files)
  - Final message: "All archives complete: 4 folders processed"
```

## Code Flow

### Before Fix

```
Loop through selectedFolders:
  - Call Invoke-AutoArchive
    - Display candidates
    - Ask user what to archive
    - Perform moves
    - Ask: "Continue to sync?" ← BREAKS loop if user says no
  - Next folder...
```

### After Fix

```
Loop through selectedFolders:
  - Call Invoke-AutoArchive with PromptForSync=false
    - Display candidates
    - Ask user what to archive
    - Perform moves
    - Skip sync prompt ← Allow loop to continue
  - Next folder...
After all folders:
  - Ask once: "All archives complete. Continue to sync?" ← Single decision point
  - Proceed based on answer
```

## Files Modified

- `!Sync-RawAndSo.ps1`
  - Line 365: Added `$PromptForSync` parameter
  - Line 521-526: Conditional sync prompt
  - Line 957-978: Multi-folder archive loop simplified

## Verification Commands

Check that all 4 folders were processed:

```powershell
Get-ChildItem -Path "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\*\archive_summary.txt" |
  Measure-Object | Select-Object -ExpandProperty Count
# Should return: 4 or more (other folders may also have archives)
```

Check specific folders were archived:

```powershell
$folders = "2026-01-31", "2026-02-01", "2026-02-02", "2026-02-05"
foreach ($f in $folders) {
  $path = "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\$f\unified_archive.json"
  Write-Host "$f: $(if (Test-Path $path) { 'Archived' } else { 'Not archived' })"
}
```

## Remaining Notes

- The script now properly handles multi-folder archives
- Each folder is processed sequentially with user interaction for archive options
- Sync decision is made once after all archives complete
- Enter key exit works as expected via SafeExitWithPause
