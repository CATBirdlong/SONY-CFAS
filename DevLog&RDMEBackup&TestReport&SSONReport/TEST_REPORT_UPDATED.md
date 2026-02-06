TEST REPORT — Sync-RawAndSo (Dec 29, 2025)

Environment:
- OS: Windows
- Script: D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\Sync-RawAndSo_.ps1-modify.ps1
- Test folder: D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\2025-11-21 - Copyfortest

Actions performed:
1) Patched script to add `Get-FileChecksum` (SHA256) and include `OrigChecksum` / `DestChecksum` in `archive_move_log.json`.
2) Performed non-interactive full archive (`Invoke-AutoArchiveOption -Option 1`) on test folder.
3) Generated unified JSON (`unified_archive.json`).
4) Ran rollback tests:
   - DryRun: `Invoke-Rollback -DateFolder <path>` — produced `rollback_log.json`.
   - Apply: `Invoke-Rollback -DateFolder <path> -Apply` — restored files.
   - Apply+Overwrite: `Invoke-Rollback -DateFolder <path> -Apply -Overwrite` — exercised overwrite/backups.

Key results:
- Files moved: 82
- Total bytes moved: 3,214,664,637
- Archive elapsed (measured during run): ~00:00:06.76
- SessionId: e257aef9-1bc0-4c56-a1c9-69d051573020
- `archive_move_log.json` entries include `OrigChecksum` for moved files (SHA256).
- `rollback_log.json` produced and contains per-entry statuses (DryRun/Restored/RestoredOverwrote/Conflict/MissingDest/Failed).

Sample commands used (copy-paste):

```powershell
# load functions only
& 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\Sync-RawAndSo_.ps1-modify.ps1' -SkipMain

# run non-interactive full archive
Invoke-AutoArchiveOption -DateFolder 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\2025-11-21 - Copyfortest' -Option 1

# dry-run rollback
Invoke-Rollback -DateFolder 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\2025-11-21 - Copyfortest' -BatchSize 50

# apply rollback (restore)
Invoke-Rollback -DateFolder 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\2025-11-21 - Copyfortest' -BatchSize 50 -Apply

# apply with overwrite (force)
Invoke-Rollback -DateFolder 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\2025-11-21 - Copyfortest' -BatchSize 50 -Apply -Overwrite
```

Recommendations / Next steps:
- Add optional verification step after restore to compare restored file checksum with `OrigChecksum` before deleting any `.pre_rollback_` backups.
- (Optional) Add a `--verify-only` run that checks checksums without moving files.
- (Optional) Add a progress indicator for checksum computation on large datasets.

Prepared by: GitHub Copilot (assistant)
Date: 2025-12-29