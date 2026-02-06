README — Sync-RawAndSo (Updated)

English / 中文 (简体)

**Purpose / 目的**:
- This script auto-archives media and RAW files in a date folder, produces per-file move logs (with SHA256 checksums), writes unified JSON, and provides rollback utilities (DryRun / Apply / Overwrite).
- 脚本会在日期文件夹内归档媒体与 RAW 文件，记录每个移动操作（含 SHA256 校验和），生成统一 JSON，并提供回滚工具（模拟/应用/强制覆盖）。

**Quick Usage / 快速使用**:
- Load functions only (recommended for testing):

```powershell
& 'D:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2\Sync-RawAndSo_.ps1-modify.ps1' -SkipMain
# then call functions, e.g.:
Invoke-AutoArchiveOption -DateFolder 'D:\...\2025-11-21 - Copyfortest' -Option 1
Write-UnifiedArchiveJson -DateFolder 'D:\...\2025-11-21 - Copyfortest'
Invoke-Rollback -DateFolder 'D:\...\2025-11-21 - Copyfortest' -BatchSize 50   # DryRun
Invoke-Rollback -DateFolder 'D:\...\2025-11-21 - Copyfortest' -BatchSize 50 -Apply   # Apply
Invoke-Rollback -DateFolder 'D:\...\2025-11-21 - Copyfortest' -BatchSize 50 -Apply -Overwrite  # Force
```

**What changed (Dec 29, 2025)**
- Added `Get-FileChecksum` helper; archive move logs now include `OrigChecksum` (SHA256). Conflicts include `DestChecksum` where destination exists.
- Added checksums to both interactive and non-interactive archive flows; unified JSON includes move log with checksums.
- Normalized JSON parsing for single-element MoveLog (robust iteration).

**Rollback / 回滚要点**:
- Always run DryRun first: `Invoke-Rollback -DateFolder <path>` and inspect `rollback_log.json`.
- Apply only after confirming results: `Invoke-Rollback -DateFolder <path> -Apply`.
- Force-overwrite will back up existing originals with `.pre_rollback_YYYYMMDD_HHMMSS` suffix before restoring.

**Testing performed / 已完成测试**:
- Non-interactive full archive on `2025-11-21 - Copyfortest`: moved 82 files, ~3.2 GB, all move-log entries include `OrigChecksum`.
- DryRun rollback, Apply, and Apply+Overwrite executed and logs written to `rollback_log.json`.

**Notes and Recommendations / 说明与建议**:
- Checksumming large media may take time; adjust expectations for very large datasets.
- Consider adding per-file verification after restore comparing `OrigChecksum` to checksum of restored file before deleting backups.
- Back up important data before mass operations.

---
If you want, I can replace the original `README.md` with this updated version, or merge parts into it. 要我把原始 README.md 替换为此文档，或把内容合并进去吗？