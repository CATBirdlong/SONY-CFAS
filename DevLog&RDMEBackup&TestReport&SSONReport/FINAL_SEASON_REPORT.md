FINAL SEASON REPORT — Sync-RawAndSo
Date: 2025-12-29

Summary
-------
This season we implemented versioned backups and post-restore verification for the `Sync-RawAndSo_.ps1-modify.ps1` workflow, ran archive and rollback exercises on the test date folder, and produced unified logs and reports.

What I changed (code)
---------------------
- Added `Get-FileChecksum(Path)` — computes SHA256 checksums for files.
- Added `Save-FileVersionBackup(OrigPath, DateFolder)` — moves existing originals into
  `DateFolder\rollback_backups\<orig-folder-identifier>\<filename>.backup.<timestamp>` keeping every version.
- Updated interactive and non-interactive archive flows to record `OrigChecksum` (and `DestChecksum` in conflicts) into `archive_move_log.json`.
- Improved `Get-ArchiveMoveEntries` normalization (handles single-entry JSON objects).
- Enhanced `Invoke-Rollback`:
  - New parameter `-VerifyAfterRestore` to enable checksum verification after restore.
  - When overwriting an existing original, `Save-FileVersionBackup` is used to preserve the previous version.
  - After restore the script computes `RestoredChecksum` and compares against the recorded `OrigChecksum`. Results are logged in `rollback_log.json` with fields: `BackupPath`, `ExpectedChecksum`, `RestoredChecksum`, `Verified` (true/false).

What I ran (operations)
-----------------------
1) Dot-sourced the script for testing (no main run):

```powershell
& 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\Sync-RawAndSo_.ps1-modify.ps1' -SkipMain
```

2) Non-interactive full archive on test folder (option 1):

```powershell
Invoke-AutoArchiveOption -DateFolder 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\2025-11-21 - Copyfortest' -Option 1
```
- Result: moved 82 files, total bytes 3,214,664,637, `archive_move_log.json` includes `OrigChecksum`.

3) Generated unified JSON:

```powershell
Write-UnifiedArchiveJson -DateFolder 'D:\...\2025-11-21 - Copyfortest'
```

4) Rollback runs (test):

```powershell
# Dry run
Invoke-Rollback -DateFolder '<date-folder>' -BatchSize 50

# Apply (restore)
Invoke-Rollback -DateFolder '<date-folder>' -BatchSize 50 -Apply

# Apply + Overwrite + Verify
Invoke-Rollback -DateFolder '<date-folder>' -BatchSize 50 -Apply -Overwrite -VerifyAfterRestore
```

Observations / Test results
---------------------------
- Archive produced `archive_move_log.json` entries containing `OrigChecksum` (SHA256). Sample entry contains `OrigChecksum` and Size, Timestamp, Status.
- During the final `Invoke-Rollback -Apply -Overwrite -VerifyAfterRestore` run, all entries in `rollback_log.json` were `MissingDest` (count: 82). No restored entries were available to verify because the destination files in the archive locations were absent at the time of the run.
- Summary counts from `rollback_log.json`:
  - MissingDest: 82
  - Verified: 0
  - VerifyFailed: 0

Why MissingDest occurred
------------------------
- The test environment had the archive destination files removed or already restored earlier; `Invoke-Rollback` checks the recorded `Dest` path for existence and returns `MissingDest` when that path does not exist. Because the restore step requires the archived file to be present, verification could not proceed.

Files created/modified
----------------------
- Modified: `Sync-RawAndSo_.ps1-modify.ps1` — added checksum, backups, and verification support.
- Created: `README_UPDATED.md` (draft), `TEST_REPORT_UPDATED.md`, `FINAL_SEASON_REPORT.md`, `c:\Users\catbl\summarize_rollback.ps1` (helper script for summarizing logs).
- Logs in test folder: `archive_move_log.json`, `archive_session.json`, `unified_archive.json`, `rollback_log.json` (updated by runs).
- Backups (if any restores occurred) would be under `<DateFolder>\rollback_backups\...` — none created in the final run because restores were skipped due to MissingDest.

Next recommended actions
------------------------
- Re-run the archive flow to ensure `archive_move_log.json` and the destination files exist (i.e., ensure the archive step created/moved files into the `Medias`, `RAW_arw`, `SO_hif`, `SO_jpg` folders). Then re-run `Invoke-Rollback -Apply -VerifyAfterRestore` to exercise verification and generate `Verified:true` entries.
- Optionally implement an automated post-restore verification step that will delete backups only after `Verified:true` is recorded (this is currently advised in recommendations but backups are preserved by default).
- If you prefer incremental version numbering instead of timestamped backups, we can swap the naming scheme to `.v1`, `.v2` by scanning existing backups in the backups folder.

Appendix: quick verify command
-----------------------------
To re-run rollback verification once the destination files are present, run:

```powershell
& 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\Sync-RawAndSo_.ps1-modify.ps1' -SkipMain
Invoke-Rollback -DateFolder 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\2025-11-21 - Copyfortest' -BatchSize 50 -Apply -Overwrite -VerifyAfterRestore
```

If you want, I can now:
- Re-run the archive step to re-create the archive destination files and then re-run `Invoke-Rollback -Apply -VerifyAfterRestore` so we get Verified results, or
- Modify the backup naming to use incremental `.vN` versions instead of timestamp backups.

Prepared by: GitHub Copilot (assistant)
