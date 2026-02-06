# Sync-RawAndSo\_.ps1 — Purpose, Usage, and Test Summary ✅

## Overview

**Purpose:** Auto-archive files from a single **date folder** before syncing, produce canonical per-file move logs and session metadata, and provide robust rollback utilities with optional verification and versioned backups.

This repository contains a single PowerShell script: `Sync-RawAndSo\\\_.ps1-modify.ps1` (dot-source with `-SkipMain` to load functions without running the main flow).

---

## Key Features 🔧

* Per-file move records: `archive\\\_move\\\_log.json` (preferred for rollback).
* Session metadata: `archive\\\_session.json` (counts, elapsed time, SessionId).
* Unified representation: `unified\\\_archive.json` (MoveLog + Session + Summary).
* Rollback tool: `Invoke-Rollback` (supports DryRun/Apply/Overwrite and optional `-VerifyAfterRestore`).
* Checksums: SHA256 checksums recorded and used to verify restored files.
* Versioned backups: overwritten originals are preserved under `rollback\\\_backups`.
* Archive architecture modes: **new** (recommended) and **old** (legacy) — selectable interactively or via `-ArchiveMode` parameter.

---

## Archive Architecture (layouts) 🗂️

* **New (default)**: date folder contains `Medias` and `Stills`, and inside `Stills` folders such as `RAW\\\_arw`, `SO\\\_hif`, `SO\\\_jpg`.

  * Example:

    * `<date>/Medias/\\\*.mp4`
    * `<date>/Stills/RAW\\\_arw/\\\*.arw`
    * `<date>/Stills/SO\\\_hif/\\\*.hif`
    * `<date>/Stills/SO\\\_jpg/\\\*.jpg`

* **Old (legacy)**: `Medias`, `RAW\\\_\\\*`, and `SO\\\_\\\*` are at the same level under the date folder.

  * Example:

    * `<date>/Medias/\\\*.mp4`
    * `<date>/RAW\\\_arw/\\\*.arw`
    * `<date>/SO\\\_hif/\\\*.hif`

Choose the layout interactively (`Show-ArchiveModes`) or non-interactively using:

```powershell
Invoke-AutoArchiveOption -DateFolder '<date>' -Option 1 -ArchiveMode new
```

---

## Quick Usage — commands \& examples ⚙️

Load functions only (do not run the main workflow):

```powershell
. 'D:\\\\Pictures\\\\PhotosPics-ofCBLnSONY\\\\SONY\\\_Alpha\\\\arcv-e10m2\\\\Sync-RawAndSo\\\_.ps1-modify.ps1' -SkipMain
```

Interactive archive run (recommended for first use):

```powershell
Invoke-AutoArchive -DateFolder '<date>'
# Follow prompts to choose which groups to archive and the archive architecture
```

Non-interactive archive (example, Option 1 archives everything):

```powershell
Invoke-AutoArchiveOption -DateFolder '<date>' -Option 1 -ArchiveMode new
```

Rollback (DryRun) — safe check:

```powershell
Invoke-Rollback -DateFolder '<date>' -BatchSize 50
```

Rollback (Apply) — after careful review:

```powershell
Invoke-Rollback -DateFolder '<date>' -Apply -BatchSize 50
```

Rollback (Apply + overwrite existing originals) — use with extreme caution:

```powershell
Invoke-Rollback -DateFolder '<date>' -Apply -Overwrite -BatchSize 50
```

Apply + Verify (restored file checksums compared to original):

```powershell
Invoke-Rollback -DateFolder '<date>' -Apply -VerifyAfterRestore
```

---

## Logs and Output files 📁

* `archive\\\_move\\\_log.json`: per-file move entries (source, destination, OrigChecksum, DestChecksum when applicable).
* `archive\\\_session.json`: metadata for the archive run (SessionId, counts, elapsed time).
* `unified\\\_archive.json`: merged JSON useful for auditing and ingestion.
* `archive\\\_summary.txt` / `archive\\\_list\\\_full.txt`: human-readable outputs.
* `rollback\\\_log.json`: produced by `Invoke-Rollback` and includes `Status` and `Verified` when verification succeeds.
* `rollback\\\_backups/`: preserved original files when overwrite occurs (versioned).

---

## Safety \& Best Practices ⚠️

* **Always run DryRun first**: `Invoke-Rollback` without `-Apply` will report planned actions in `rollback\\\_log.json`.
* Keep off-site copies of `archive\\\_move\\\_log.json` and `unified\\\_archive.json` until verification is complete.
* Use small `-BatchSize` during initial tests to limit impact.
* If `rollback\\\_log.json` shows `Status: MissingDest`, it means the script cannot find the archived destination file; re-run archive on the date folder before applying the rollback.
* Use `-VerifyAfterRestore` to ensure restored files checksum-match their originals (script records `RestoredChecksum` and `Verified: true/false`).

---

## Test Summary (completed) ✅

All planned tests and fixes for the archive and rollback flows have been completed (no further automated tests will be run per your request). Key results are summarized in `TEST\\\_REPORT.md` and a short executive summary is in `FINAL\\\_SEASON\\\_REPORT.md`.

Highlights:

* Non-interactive archive on the real dataset: **82 files moved**, **~3.21 GB** transferred (SessionId recorded).
* Sandbox tests: both **new** and **old** archive modes exercised; sample archives and rollbacks performed successfully.
* Rollback Apply+Verify in sandboxes: **Restored** entries recorded with **Verified: true** (checksums matched).
* Main dataset rollback observed `MissingDest` results in one run; this is due to archived destination files being absent at that time — recommended action: re-run archive then apply+verify.

---

## Where to find artifacts \& logs 🔍

* `latest.log` — script-level logs
* `<date>/archive\\\_move\\\_log.json` — per-file move records
* `<date>/unified\\\_archive.json` — unified archive output
* `<date>/rollback\\\_log.json` — rollback run results (DryRun \& Apply)
* `<date>/rollback\\\_backups/` — versioned backups created by overwrite during rollback (if used)

---

*Last updated: 2025-12-30*

---

