Test Report: Sync-RawAndSo_.ps1 functional tests (2025-12-29)

Summary:
- Test folder: D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\2025-11-21 - Copyfortest
- Actions performed:
  1) Loaded script functions (dot-sourced with `-SkipMain`).
  2) Ran `Get-Context` and `Find-RawSoFolders` — detected `RAW_arw` and `SO_hif` folders.
  3) Performed DryRun rollback: `Invoke-Rollback -DateFolder <test> -BatchSize 50`.
     - Result: `rollback_log.json` produced; grouped statuses: MissingDest: 82
  4) Single-file conflict test:
     - Selected sample original: C0307.MP4
     - Created conflicting copy at `Medias\C0307.MP4` (duplicate dest present).
     - Ran `Invoke-Rollback -Apply` (no `-Overwrite`): function reported "no move entries found" (no archive_move_log.json present); no changes performed. Grouped statuses still: MissingDest: 82
     - Ran `Invoke-Rollback -Apply -Overwrite`: same "no move entries found"; no changes.

Key findings:
- A `unified_archive.json` exists in the date folder (size ~11.7 MB). `archive_move_log.json` is not present. Current `Invoke-Rollback` prefers `archive_move_log.json` and may return "no move entries found" when it isn't present or lacks expected structure.
- `rollback_log.json` exists (produced earlier by DryRun) and shows 82 MissingDest entries — likely because original Apply had restored originals earlier and dest paths were missing at DryRun time.
- Conflict test could not proceed because the rollback source (move log) was not found by `Invoke-Rollback` in the expected format.

Recommendations / Next steps:
- Ensure `archive_move_log.json` is written by the archive phase alongside `unified_archive.json` so `Invoke-Rollback` can use it reliably.
- Update `Invoke-Rollback` to accept `unified_archive.json` as a fallback if `archive_move_log.json` is absent, or to parse the unified file if present (robust fallback implemented).
- If testing Apply semantics, create a controlled `archive_move_log.json` with a small subset entry to exercise conflict handling and overwrite behavior.

Files referenced:
- unified_archive.json (present)
- rollback_log.json (present)

Detailed logs are in `latest.log` and `rollback_log.json` in the test folder.
