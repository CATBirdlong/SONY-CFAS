# SONY-CFAS
SONY-Cam File Archiving &amp; Synchronization/SONY-Cam文件归档与同步, 用于相机拷卡后对文件(包括但不限于视频/图像等多个扩展名的文件)进行架构化归档与选片后的同步机制

## Implemented Features:

**Archive Modes**: interactive and non-interactive archive flows (Invoke-AutoArchive, Invoke-AutoArchiveOption) and architecture choice (Show-ArchiveModes).

**Type Detection & Categorization**: identifies Medias / RAW_arw / SO_hif / SO_jpg by extensions and moves files into those folders.

**Move & Session Logging**: produces archive_move_log.json, archive_session.json, archive_summary.txt, archive_list_full.txt, and unified_archive.json.

**Rollback & Restore**: dry-run and apply rollback utilities (Get-ArchiveMoveEntries, Invoke-Rollback, Prompt-And-Run-Rollback, Restore-ArtifactsFromEarlier) with versioned backups (Save-FileVersionBackup).

**Whitelist Support**: Ensure-Whitelist and runtime whitelist parsing (whitelist.txt) to skip named bases.

**Folder Matching Options**: Show-MatchOptions + Find-RawSoFolders using configurable regex lists.

**Test Mode**: Invoke-TestMode to simulate actions without moving files.

**Legacy Migration**: Migrate-OldArtifacts to move legacy artifacts to earlierLOGs.

**Checksum & Verification**: Get-FileChecksum used for conflict detection and optional verification after restore.

**Trash & Recycle Integration**: moves scrap files to trashTEMP and can send to Recycle Bin via Shell COM.

**Logging Helpers**: Init-LatestLog, Write-Log, Write-HostAndLog.

**Safe-exit helper**: SafeExitWithPause used in several exit/error flows.

**Entrypoint & options**: Sync-RawAndSo driver, -SkipMain param, startup rollback prompt.
