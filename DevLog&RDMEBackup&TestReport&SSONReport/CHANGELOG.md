# Changelog

## Version 2.1 - 2026-02-06

### Bug Fixes
- **SafeExitWithPause - Enter Key Handling**: Simplified the exit pause behavior to reliably accept Enter keypress across all PowerShell hosts (console, ISE, VSCode). Removed complex non-blocking detection logic that caused timeouts or ignored input. Now uses straightforward `Read-Host` prompt with RawUI fallback, ensuring users can always exit by pressing Enter without delay.

### New Features
- **Range & Multi-Selection for Date Folders**: Added support for selecting multiple date folders at once from the ArcvRoot main menu. Users can now input:
  - Single index: `1` (selects folder 1 only)
  - Range notation: `1~5` (selects folders 1, 2, 3, 4, 5)
  - List notation: `1,3,5` (selects folders 1, 3, 5 only)
  - Mixed notation: `1~3,5,7~9` (selects folders 1, 2, 3, 5, 7, 8, 9)
  - Folder names: comma-separated folder names (case-insensitive, fallback if numeric fails)
  
  Once selected, the script displays a summary (e.g., "Selected indexes: 1,2,3,4,5 (total 5 folders)") and then processes auto-archive for each selected date folder sequentially using the same archive mode.

### Implementation Details
- **New Function: `Parse-IndexSelection`** — Parses range and list notation into valid index arrays. Parameter renamed to `$Selection` (avoiding conflict with PowerShell's `$Input` automatic variable).
- **New Function: `Select-DateFoldersRange`** — Enhanced folder selection UI supporting ranges, lists, and mixed input. Replaces the previous `Select-DateFolder` single-selection prompt in the ArcvRoot context.
- **ArcvRoot Selection Flow**: Updated to use `Select-DateFoldersRange` and loop through all selected folders for auto-archive, unifying logs as each completes.

### Testing
- Verified `Parse-IndexSelection` correctly parses `1~3,5` → `[1, 2, 3, 5]`
- Verified `Invoke-AutoArchiveOption` continues to work post-patch (dry-run on test folder)
- Verified `SafeExitWithPause` accepts Enter input reliably in interactive mode

### Notes
- All code comments and variable names remain **English only** per project policy.
- No breaking changes to existing API or file structures.
- Archive artifacts (JSON logs, summaries) continue to be generated and unified as before.
