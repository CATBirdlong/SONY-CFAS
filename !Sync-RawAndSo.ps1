<#
Sync-RawAndSo_.ps1-modify.ps1

Purpose:
- Auto-archive files in a date folder before sync, produce unified JSON logs and provide rollback utilities.
- Features: interactive/non-interactive archive, whitelist handling, per-file move logs (archive_move_log.json), session metadata (archive_session.json), unified output (unified_archive.json), and rollback tools (Invoke-Rollback / Prompt-And-Run-Rollback).

Safety Notice:
- This script uses Move-Item to relocate files. Verify with backups or run on test copies before using in production.
- Always run rollback in DryRun mode first and inspect `rollback_log.json` before applying changes.

Usage examples:
- Run main flow:
    powershell -NoProfile -ExecutionPolicy Bypass -File "D:\...\Sync-RawAndSo_.ps1-modify.ps1"
- Load functions only (no main run), then use rollback interactively:
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& { . 'D:\...\Sync-RawAndSo_.ps1-modify.ps1' ; Prompt-And-Run-Rollback }"

Output files (per date folder):
- `archive_move_log.json`, `archive_session.json`, `unified_archive.json`, `archive_summary.txt`, `archive_list_full.txt`, `rollback_log.json`

Author/Modifier: GitHub Copilot (assistant) — Please review and backup data
Date: 2025-12-29
#>

param(
        [string]$ScriptPath = $PSScriptRoot,
        [switch]$SkipMain
)

# --------- logging ----------
function Init-LatestLog {
    param([string]$BasePath)
    $logPath = Join-Path $BasePath "latest.log"
    Set-Content -Path $logPath -Value "=== Log started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
    return $logPath
}

function Write-Log {
    param([string]$BasePath,[string]$Level="INFO",[string]$Message)
    try {
        $logPath = Join-Path $BasePath "latest.log"
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -Path $logPath -Value "[$ts] ${Level}: $Message"
    } catch {
        Write-Host "LOGGING ERROR: $($_.Exception.Message)"
    }
}

# Write to console and append to latest.log
function Write-HostAndLog {
    param([string]$BasePath, [string]$Level="INFO", [string]$Message)
    try {
        Write-Host $Message
    } catch {}
    try {
        Write-Log -BasePath $BasePath -Level $Level -Message $Message
    } catch {}
}

# Compute file checksum (SHA256). Returns hex string or $null on error.
function Get-FileChecksum {
    param([string]$Path)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        $h = Get-FileHash -Path $Path -Algorithm SHA256 -ErrorAction Stop
        return $h.Hash
    } catch {
        return $null
    }
}

# Save a versioned backup of an existing file before overwrite.
# Returns the backup path or $null on failure.
function Save-FileVersionBackup {
    param([string]$OrigPath, [string]$DateFolder)
    try {
        if (-not (Test-Path -LiteralPath $OrigPath)) { return $null }
        $rel = [IO.Path]::GetFileName($OrigPath)
        $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $backupDir = Join-Path $DateFolder 'rollback_backups'
        if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        # keep subfolders by using original folder name hash to avoid collisions
        $origDirName = (Split-Path $OrigPath -Parent) -replace '[:\\]','_'
        $destFolder = Join-Path $backupDir $origDirName
        if (-not (Test-Path -LiteralPath $destFolder)) { New-Item -ItemType Directory -Path $destFolder -Force | Out-Null }
        $base = [IO.Path]::GetFileNameWithoutExtension($OrigPath)
        $ext = [IO.Path]::GetExtension($OrigPath)
        $bakName = "${base}.backup.${ts}${ext}"
        $bakPath = Join-Path $destFolder $bakName
        Move-Item -LiteralPath $OrigPath -Destination $bakPath -Force
        return $bakPath
    } catch {
        Write-HostAndLog -BasePath $DateFolder -Level "WARN" -Message ("Save-FileVersionBackup failed for $OrigPath - " + $_.Exception.Message)
        return $null
    }
}

# Pause helper: show message and wait for Enter before exit (robust across hosts)
# TimeoutSec parameter is provided for legacy compatibility but is unused (Read-Host always blocks interactively)
function SafeExitWithPause {
    param([string]$Message = "Press Enter to exit...", [int]$TimeoutSec = 0)
    try { Write-Host $Message } catch {}
    # Use a simple, reliable blocking prompt when interactive (Read-Host is the most compatible approach)
    try {
        [void](Read-Host "(press Enter to finish)")
    } catch {
        # If Read-Host is not available, attempt RawUI ReadKey if possible
        try {
            if ($Host -and $Host.UI -and $Host.UI.RawUI) {
                [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            }
        } catch {}
    }
}

# --------- selection ----------
function Select-DateFolder {
    param([System.IO.DirectoryInfo[]]$Folders, [string]$BasePath)
    while ($true) {
        Write-Host "Available date folders:"
        for ($i = 0; $i -lt $Folders.Count; $i++) {
            Write-Host "$($i + 1). $($Folders[$i].Name)"
        }
        $userInput = Read-Host "Select date folder by number or name"
        try {
            if ($userInput -match '^\d+$') {
                $index = [int]$userInput - 1
                if ($index -ge 0 -and $index -lt $Folders.Count) {
                    return $Folders[$index]
                } else {
                    throw "Index out of range"
                }
            } else {
                $match = $Folders | Where-Object { $_.Name -ieq $userInput } | Select-Object -First 1
                if ($match) { return $match } else { throw "Folder name not found" }
            }
        } catch {
            Write-HostAndLog -BasePath $BasePath -Level "ERROR" -Message "Invalid input. Please try again."
            Write-Log -BasePath $BasePath -Level "ERROR" -Message "Invalid folder selection: '$userInput' - $($_.Exception.Message)"
        }
    }
}

function Parse-IndexSelection {
    param([string]$Selection, [int]$Max)
    $s = $Selection.Trim()
    $parts = $s -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    $idxs = @()
    foreach ($p in $parts) {
        if ($p -match '^\s*(\d+)\s*~\s*(\d+)\s*$') {
            $a = [int]$matches[1]; $b = [int]$matches[2]
            if ($a -gt $b) { $tmp=$a; $a=$b; $b=$tmp }
            for ($i = $a; $i -le $b; $i++) { if ($i -ge 1 -and $i -le $Max) { $idxs += $i } }
        } elseif ($p -match '^\d+$') {
            $n = [int]$p
            if ($n -ge 1 -and $n -le $Max) { $idxs += $n }
        }
    }
    return ($idxs | Sort-Object -Unique)
}

function Select-DateFoldersRange {
    param([System.IO.DirectoryInfo[]]$Folders, [string]$BasePath)
    while ($true) {
        Write-Host "Available date folders:"
        for ($i = 0; $i -lt $Folders.Count; $i++) {
            Write-Host "$($i + 1). $($Folders[$i].Name)"
        }
        $userInput = Read-Host "Select date folder by number, name, or range (e.g. 1~5,1,3,5)"
        try {
            if ($userInput -match '[,~]') {
                $idxs = Parse-IndexSelection -Selection $userInput -Max $Folders.Count
                if (-not $idxs -or $idxs.Count -eq 0) { throw "No valid indices" }
                $selected = $idxs | ForEach-Object { $Folders[$_ - 1] }
                Write-Host "Selected indexes: $($idxs -join ', ') (total $($selected.Count) folders)."
                return $selected
            }

            if ($userInput -match '^\d+$') {
                $index = [int]$userInput - 1
                if ($index -ge 0 -and $index -lt $Folders.Count) { return @($Folders[$index]) } else { throw "Index out of range" }
            }

            $names = $userInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            if ($names.Count -gt 1) {
                $matches = @()
                foreach ($n in $names) {
                    $m = $Folders | Where-Object { $_.Name -ieq $n } | Select-Object -First 1
                    if ($m) { $matches += $m } else { throw "Folder name not found: $n" }
                }
                return $matches
            } else {
                $match = $Folders | Where-Object { $_.Name -ieq $userInput } | Select-Object -First 1
                if ($match) { return @($match) } else { throw "Folder name not found" }
            }
        } catch {
            Write-HostAndLog -BasePath $BasePath -Level "ERROR" -Message "Invalid input. Please try again."
        }
    }
}

# --------- context detection ----------
function Get-Context {
    param([string]$ScriptPath)
    $parent  = Split-Path $ScriptPath -Parent
    $current = Split-Path $ScriptPath -Leaf
    $context = @{ Mode='Invalid'; DateFolder=$null; StillsFolder=$null }

    if ($current -match '^\d{4}-\d{2}-\d{2}$') {
        $context.Mode='Date'
        # Date folder detected: DateFolder should be the current path
        $context.DateFolder=Get-Item -LiteralPath $ScriptPath
        $sf=Join-Path $ScriptPath "Stills"
        if (Test-Path -LiteralPath $sf) { $context.StillsFolder=$sf } else { $context.StillsFolder=$ScriptPath }
        return $context
    }

    if ($current -match '^(?i)arcv.*e10m2') {
        $context.Mode='ArcvRoot'
        $context.StillsFolder=$ScriptPath
        return $context
    }

    if ($current -ieq 'Stills') {
        $context.Mode='Stills'
        $context.DateFolder=Get-Item -LiteralPath $parent
        $context.StillsFolder=$ScriptPath
        return $context
    }

    return $context
}

function Find-RawSoFolders {
    param([string]$BasePath,[bool]$SearchSameLevel=$false)
    if ($SearchSameLevel) {
        $dirs = Get-ChildItem -LiteralPath $BasePath -Directory -ErrorAction SilentlyContinue
    } else {
        $dirs = Get-ChildItem -LiteralPath $BasePath -Directory -Recurse -ErrorAction SilentlyContinue
    }
    # Use user-selected regex lists if present, otherwise fall back to defaults
    if (-not $global:RawRegexList) {
        $global:RawRegexList = @('^(RAW$|RAW_arw$|RAWs$)','(?i)raw')
    }
    if (-not $global:SoRegexList) {
        $global:SoRegexList = @('^(SO$|SO_hif$|SO_jpg$|SO_jpeg$)','(?i)^so')
    }

    $raw = $null
    foreach ($pattern in $global:RawRegexList) {
        $raw = $dirs | Where-Object { $_.Name -match $pattern } | Select-Object -First 1
        if ($raw) { break }
    }

    $so = $null
    foreach ($pattern in $global:SoRegexList) {
        $so = $dirs | Where-Object { $_.Name -match $pattern } | Select-Object -First 1
        if ($so) { break }
    }
    return @{ RawFolder=$raw; SoFolder=$so }
}

# Present matching strategies and let user choose; sets $global:RawRegexList and $global:SoRegexList
function Show-MatchOptions {
    Write-Host "Matching strategy options:" 
    Write-Host "1) Strict exact names (preferred, safe)"
    Write-Host "   Raw: ^(RAW$|RAW_arw$|RAWs$)   So: ^(SO$|SO_hif$|SO_jpg$|SO_jpeg$)"
    Write-Host "2) Broad contains (fast, permissive)"
    Write-Host "   Raw: (?i)raw   So: (?i)so"
    Write-Host "3) Boundary-aware (tolerant to separators)"
    Write-Host "   Raw: (?i)(^|[_\-])raw([_\-]|$)   So: (?i)(^|[_\-])so([_\-]|$)"
    $sel = Read-Host "Choose matching option (1/2/3) or press Enter to use defaults"
    switch ($sel) {
        '1' { $global:RawRegexList = @('^(RAW$|RAW_arw$|RAWs$)'); $global:SoRegexList = @('^(SO$|SO_hif$|SO_jpg$|SO_jpeg$)') }
        '2' { $global:RawRegexList = @('(?i)raw'); $global:SoRegexList = @('(?i)so') }
        '3' { $global:RawRegexList = @('(?i)(^|[_\-])raw([_\-]|$)'); $global:SoRegexList = @('(?i)(^|[_\-])so([_\-]|$)') }
        default { return }
    }
    Write-Log -BasePath $PSScriptRoot -Level "INFO" -Message "Match option $sel selected"
}

# Ensure a whitelist file exists; create example and allow user to edit. Returns 'use','no','modify'
function Ensure-Whitelist {
    param([string]$WhitelistPath)
    $example = @(
        "CAT00001",
        "IMG_0001",
        "another_base_name"
    )
    if (-not (Test-Path -LiteralPath $WhitelistPath)) {
        # write commented example entries so file does not accidentally match real files
        '# Whitelist file - add base filenames (one per line) without extension' | Out-File -FilePath $WhitelistPath -Encoding UTF8
        '# Example entries (uncomment to enable):' | Out-File -FilePath $WhitelistPath -Append -Encoding UTF8
        '#CAT00001' | Out-File -FilePath $WhitelistPath -Append -Encoding UTF8
        '#IMG_0001' | Out-File -FilePath $WhitelistPath -Append -Encoding UTF8
        '#another_base_name' | Out-File -FilePath $WhitelistPath -Append -Encoding UTF8
        Write-HostAndLog -BasePath $PSScriptRoot -Level "INFO" -Message "Whitelist file created: $WhitelistPath"
        $resp = Read-Host "Choose: Y=use as-is, N=do not enable (continue without whitelist), M=modify now (exit and open Notepad)"
        switch ($resp) {
            'Y' { return 'use' }
            'N' { return 'no' }
            'M' {
                try { Start-Process notepad.exe $WhitelistPath } catch {}
                Write-HostAndLog -BasePath $PSScriptRoot -Level "INFO" -Message "Opened whitelist for editing. Exiting for user to modify."
                SafeExitWithPause "Whitelist opened in Notepad. Press Enter when ready to exit."
                return 'modify'
            }
            default { return 'use' }
        }
    } else {
        return 'use'
    }
}

# --------- test mode ----------
function Invoke-TestMode {
    param([string]$BasePath)
    Write-Host "Invalid or unsupported path context. Entering TEST MODE."
    Write-Log -BasePath $BasePath -Level "ERROR" -Message "TEST MODE at '$BasePath' (invalid/missing context)"

    $simDates = Get-ChildItem -LiteralPath $BasePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}($|[^0-9])' }
    $simDateNames = ($simDates | Select-Object -ExpandProperty Name) -join ', '
    Write-Host "[TEST MODE] Date-like folders: $simDateNames"
    Write-Log -BasePath $BasePath -Level "INFO" -Message "[TEST MODE] Date-like folders: $simDateNames"

    $simRawSo = Find-RawSoFolders -BasePath $BasePath -SearchSameLevel:$false
    $simRawPath = if ($simRawSo.RawFolder) { $simRawSo.RawFolder.FullName } else { "<none>" }
    $simSoPath  = if ($simRawSo.SoFolder)  { $simRawSo.SoFolder.FullName }  else { "<none>" }
    Write-Host "[TEST MODE] RAW folder: $simRawPath"
    Write-Host "[TEST MODE] SO folder : $simSoPath"
    Write-Log -BasePath $BasePath -Level "INFO" -Message "[TEST MODE] RAW='$simRawPath'; SO='$simSoPath'"

    # Optional: simulate diff calculation
    if ($simRawSo.RawFolder -and $simRawSo.SoFolder) {
        $soBases  = Get-ChildItem -LiteralPath $simSoPath -File -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName }
        $rawFiles = Get-ChildItem -LiteralPath $simRawPath -File -ErrorAction SilentlyContinue
        $wouldMove = @()
        $wouldKeep = @()
        foreach ($rf in $rawFiles) {
            if (-not ($soBases -contains $rf.BaseName)) { $wouldMove += $rf.Name } else { $wouldKeep += $rf.Name }
        }
        Write-Host "[TEST MODE] Would move: $($wouldMove.Count) files"
        Write-Host "[TEST MODE] Would keep: $($wouldKeep.Count) files"
        Write-Log -BasePath $BasePath -Level "INFO" -Message "[TEST MODE] Would move: $($wouldMove -join ', ')"
        Write-Log -BasePath $BasePath -Level "INFO" -Message "[TEST MODE] Would keep: $($wouldKeep -join ', ')"
    }

    [void](Read-Host "`nPress Enter to end test mode")
}

# Archive architecture chooser: new (default) or old
function Show-ArchiveModes {
    Write-Host "Archive architecture options:"
    Write-Host "1) New (default): create 'Medias' and 'Stills' at date folder; 'Stills' contains RAW_arw, SO_hif, SO_jpg"
    Write-Host "2) Old: 'Medias' and RAW/SO folders are at the same level (legacy)"
    $sel = Read-Host "Choose architecture (1=New, 2=Old) or press Enter for default (New)"
    switch ($sel) {
        '2' { return 'old' }
        default { return 'new' }
    }
}

# Auto archive: scan date folder and move files to parent-level archive folders
function Invoke-AutoArchive {
    param([string]$DateFolder, [int]$ListLimit = 100, [ValidateSet('new','old')][string]$ArchiveMode = 'new')

    if (-not (Test-Path -LiteralPath $DateFolder)) { return $true }
    # Use the date folder itself as the archive root to avoid moving files to the parent-level folders
    $archiveRoot = $DateFolder
    $startTime = Get-Date

    $mediaExt = @('mp4','mov','mkv')
    $rawExt   = @('arw')
    $soHifExt = @('hif','heic')
    $soJpgExt = @('jpg','jpeg')

    $allFiles = Get-ChildItem -LiteralPath $DateFolder -File -ErrorAction SilentlyContinue

    $medias = @($allFiles | Where-Object { $mediaExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    $raws   = @($allFiles | Where-Object { $rawExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    $soHif  = @($allFiles | Where-Object { $soHifExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    $soJpg  = @($allFiles | Where-Object { $soJpgExt -contains ($_.Extension.TrimStart('.').ToLower()) })

    $archiveFullList = Join-Path $archiveRoot "archive_list_full.txt"
    $archiveMoveLog  = Join-Path $archiveRoot "archive_move_log.json"
    $summaryPath     = Join-Path $archiveRoot "archive_summary.txt"

    "Archive scan of: $DateFolder`n" | Out-File -FilePath $archiveFullList -Encoding UTF8
    $allFiles | ForEach-Object { $_.FullName } | Out-File -FilePath $archiveFullList -Append -Encoding UTF8

    Write-Host "Archive candidates summary:"
    Write-Host "Medias counts: $($medias.Count)"
    $medias | Select-Object -First $ListLimit | ForEach-Object { Write-Host $_.Name }
    Write-Host "RAW counts: $($raws.Count)"
    $raws | Select-Object -First $ListLimit | ForEach-Object { Write-Host $_.Name }
    Write-Host "HIF counts: $($soHif.Count)"
    $soHif | Select-Object -First $ListLimit | ForEach-Object { Write-Host $_.Name }
    Write-Host "JPG counts: $($soJpg.Count)"
    $soJpg | Select-Object -First $ListLimit | ForEach-Object { Write-Host $_.Name }

    Write-Host "`nOptions:`n1) (try)Archive All`n2) Only Medias`n3) Only RAWs`n4) Only SOs`n5) Medias+RAWs`n6) RAWs+SOs`n7) Do not run"
    $opt = Read-Host "Choose option number"
    switch ($opt) {
        '1' { $toMove = $medias + $raws + $soHif + $soJpg }
        '2' { $toMove = $medias }
        '3' { $toMove = $raws }
        '4' { $toMove = $soHif + $soJpg }
        '5' { $toMove = $medias + $raws }
        '6' { $toMove = $raws + $soHif + $soJpg }
        '7' { $toMove = @() }
        default { Write-Host "No archive action selected."; $toMove = @() }
    }

    # Helper: prompt user to continue to sync or end; returns $true to continue
function Prompt-ContinueToSync {
    param([string]$PromptMessage = "Press 'C' then Enter to continue to sync, or press Enter to end")
    try {
        $resp = $null
        try { $resp = Read-Host $PromptMessage } catch { $resp = '' }
        if ([string]::IsNullOrWhiteSpace($resp)) { return $false }
        return ($resp -ieq 'C')
    } catch {
        return $false
    }
}

# If nothing to move, ask user whether to continue to the sync module or end
    if (-not $toMove -or $toMove.Count -eq 0) {
        Write-HostAndLog -BasePath $archiveRoot -Level "INFO" -Message "No files to move for the selected archive option ($opt)."
        $cont = Prompt-ContinueToSync -PromptMessage "No files to archive. Press 'C' then Enter to continue to sync, or press Enter to end"
        if ($cont) { return $true } else { return $false }
    }

    # Prepare target folders under the date folder only when needed
    if ($ArchiveMode -eq 'new') {
        $mediaFolder = if ($medias.Count -gt 0) { Join-Path $archiveRoot 'Medias' } else { $null }
        $stillsFolder = Join-Path $archiveRoot 'Stills'
        $rawFolder   = if ($raws.Count -gt 0)   { Join-Path $stillsFolder 'RAW_arw' } else { $null }
        $soHifFolder = if ($soHif.Count -gt 0)  { Join-Path $stillsFolder 'SO_hif' } else { $null }
        $soJpgFolder = if ($soJpg.Count -gt 0)  { Join-Path $stillsFolder 'SO_jpg' } else { $null }
        foreach ($f in @($mediaFolder,$stillsFolder,$rawFolder,$soHifFolder,$soJpgFolder)) {
            if ($f -and -not (Test-Path -LiteralPath $f)) { New-Item -ItemType Directory -Path $f -Force | Out-Null }
        }
    } else {
        # old layout: all type folders at date root
        $mediaFolder = if ($medias.Count -gt 0) { Join-Path $archiveRoot 'Medias' } else { $null }
        $rawFolder   = if ($raws.Count -gt 0)   { Join-Path $archiveRoot 'RAW_arw' } else { $null }
        $soHifFolder = if ($soHif.Count -gt 0)  { Join-Path $archiveRoot 'SO_hif' } else { $null }
        $soJpgFolder = if ($soJpg.Count -gt 0)  { Join-Path $archiveRoot 'SO_jpg' } else { $null }
        foreach ($f in @($mediaFolder,$rawFolder,$soHifFolder,$soJpgFolder)) {
            if ($f -and -not (Test-Path -LiteralPath $f)) { New-Item -ItemType Directory -Path $f -Force | Out-Null }
        }
    }

    $moveLog = @()
    $movedCount = 0; $skippedCount = 0; $failedCount = 0; $totalBytes = 0

    foreach ($file in $toMove) {
        $ext = $file.Extension.TrimStart('.').ToLower()
        if ($mediaExt -contains $ext) { $destFolder = $mediaFolder }
        elseif ($rawExt -contains $ext) { $destFolder = $rawFolder }
        elseif ($soHifExt -contains $ext) { $destFolder = $soHifFolder }
        else { $destFolder = $soJpgFolder }

        # If a destination folder wasn't created because there were no items of that type, create it now
        if (-not $destFolder) {
            $destFolder = Join-Path $archiveRoot (if ($mediaExt -contains $ext) { 'Medias' } elseif ($rawExt -contains $ext) { 'RAW_arw' } elseif ($soHifExt -contains $ext) { 'SO_hif' } else { 'SO_jpg' })
            if (-not (Test-Path -LiteralPath $destFolder)) { New-Item -ItemType Directory -Path $destFolder -Force | Out-Null }
        }

        $destPath = Join-Path $destFolder $file.Name
        # compute checksum for source file (may be $null on error)
        $origChecksum = Get-FileChecksum -Path $file.FullName
        if (Test-Path -LiteralPath $destPath) {
            $skippedCount++
            $destChecksum = Get-FileChecksum -Path $destPath
            $moveLog += @{ Original = $file.FullName; Dest = $destPath; Size = $file.Length; Timestamp = (Get-Date).ToString('o'); Status = 'Conflict'; OrigChecksum = $origChecksum; DestChecksum = $destChecksum }
            continue
        }
        try {
            Move-Item -LiteralPath $file.FullName -Destination $destPath
            $movedCount++
            $totalBytes += $file.Length
            $moveLog += @{ Original = $file.FullName; Dest = $destPath; Size = $file.Length; Timestamp = (Get-Date).ToString('o'); Status = 'Moved'; OrigChecksum = $origChecksum }
        } catch {
            $failedCount++
            $moveLog += @{ Original = $file.FullName; Dest = $destPath; Size = $file.Length; Timestamp = (Get-Date).ToString('o'); Status = 'Failed'; Error = $_.Exception.Message; OrigChecksum = $origChecksum }
        }
    }

    # Write move log JSON
    $moveLog | ConvertTo-Json -Depth 6 | Out-File -FilePath $archiveMoveLog -Encoding UTF8

    # Write structured session metadata for improved JSON unification
    $endTime = Get-Date
    $elapsed = $endTime - $startTime
    $bytesPerSec = if ($elapsed.TotalSeconds -gt 0) { [math]::Round($totalBytes / $elapsed.TotalSeconds,0) } else { 0 }
    $session = @{ SessionId = ([guid]::NewGuid()).Guid; Option = $opt; Start = $startTime.ToString('o'); End = $endTime.ToString('o'); ElapsedSeconds = [math]::Round($elapsed.TotalSeconds,2); Moved = $movedCount; Skipped = $skippedCount; Failed = $failedCount; TotalBytes = $totalBytes; BytesPerSec = $bytesPerSec }
    $sessionPath = Join-Path $archiveRoot 'archive_session.json'
    $session | ConvertTo-Json -Depth 6 | Out-File -FilePath $sessionPath -Encoding UTF8

    # Also write a human-readable summary
    $summary = @()
    $summary += "------------------------------------------------------------------------------"
    $summary += "Archive summary for: $DateFolder"
    $summary += "Start : $($startTime)"
    $summary += "End   : $($endTime)"
    $summary += "Elapsed: $($elapsed)"
    $summary += "Moved : $movedCount"
    $summary += "Skipped(conflicts): $skippedCount"
    $summary += "Failed: $failedCount"
    $summary += "Bytes moved: $totalBytes"
    $summary += "Speed (bytes/sec): $bytesPerSec"
    $summary += "SessionId: $($session.SessionId)"
    $summary += "------------------------------------------------------------------------------"

    $summary | Out-File -FilePath $summaryPath -Encoding UTF8
    $summary | ForEach-Object { Write-Host $_ }

    return Prompt-ContinueToSync -PromptMessage "Enter 'C' then Enter to continue to sync, or press Enter to end"
}

# Non-interactive auto-archive helper: perform archive according to numeric option (1-6).
function Invoke-AutoArchiveOption {
    param([string]$DateFolder, [int]$Option, [ValidateSet('new','old')][string]$ArchiveMode = 'new')
    if (-not (Test-Path -LiteralPath $DateFolder)) { Write-HostAndLog -BasePath $DateFolder -Level "ERROR" -Message "Invoke-AutoArchiveOption: DateFolder not found: $DateFolder"; return $false }
    # replicate the detection of files as in interactive flow
    $archiveRoot = $DateFolder
    $mediaExt = @('mp4','mov','mkv')
    $rawExt   = @('arw')
    $soHifExt = @('hif','heic')
    $soJpgExt = @('jpg','jpeg')

    $allFiles = Get-ChildItem -LiteralPath $DateFolder -File -ErrorAction SilentlyContinue
    $medias = @($allFiles | Where-Object { $mediaExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    $raws   = @($allFiles | Where-Object { $rawExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    $soHif  = @($allFiles | Where-Object { $soHifExt -contains ($_.Extension.TrimStart('.').ToLower()) })
    $soJpg  = @($allFiles | Where-Object { $soJpgExt -contains ($_.Extension.TrimStart('.').ToLower()) })

    switch ([int]$Option) {
        1 { $toMove = $medias + $raws + $soHif + $soJpg }
        2 { $toMove = $medias }
        3 { $toMove = $raws }
        4 { $toMove = $soHif + $soJpg }
        5 { $toMove = $medias + $raws }
        6 { $toMove = $raws + $soHif + $soJpg }
        default { $toMove = @() }
    }

    if (-not $toMove -or $toMove.Count -eq 0) { Write-HostAndLog -BasePath $archiveRoot -Level "INFO" -Message "Invoke-AutoArchiveOption: No files to move for option $Option"; return $false }

    # prepare folders depending on archive architecture
    if ($ArchiveMode -eq 'new') {
        $mediaFolder = if ($medias.Count -gt 0) { Join-Path $archiveRoot 'Medias' } else { $null }
        $stillsFolder = Join-Path $archiveRoot 'Stills'
        $rawFolder   = if ($raws.Count -gt 0)   { Join-Path $stillsFolder 'RAW_arw' } else { $null }
        $soHifFolder = if ($soHif.Count -gt 0)  { Join-Path $stillsFolder 'SO_hif' } else { $null }
        $soJpgFolder = if ($soJpg.Count -gt 0)  { Join-Path $stillsFolder 'SO_jpg' } else { $null }
        foreach ($f in @($mediaFolder,$stillsFolder,$rawFolder,$soHifFolder,$soJpgFolder)) { if ($f -and -not (Test-Path -LiteralPath $f)) { New-Item -ItemType Directory -Path $f -Force | Out-Null } }
    } else {
        $mediaFolder = if ($medias.Count -gt 0) { Join-Path $archiveRoot 'Medias' } else { $null }
        $rawFolder   = if ($raws.Count -gt 0)   { Join-Path $archiveRoot 'RAW_arw' } else { $null }
        $soHifFolder = if ($soHif.Count -gt 0)  { Join-Path $archiveRoot 'SO_hif' } else { $null }
        $soJpgFolder = if ($soJpg.Count -gt 0)  { Join-Path $archiveRoot 'SO_jpg' } else { $null }
        foreach ($f in @($mediaFolder,$rawFolder,$soHifFolder,$soJpgFolder)) { if ($f -and -not (Test-Path -LiteralPath $f)) { New-Item -ItemType Directory -Path $f -Force | Out-Null } }
    }

    $moveLog = @(); $movedCount = 0; $skippedCount = 0; $failedCount = 0; $totalBytes = 0
    $startTime = Get-Date
    foreach ($file in $toMove) {
        $ext = $file.Extension.TrimStart('.').ToLower()
        if ($mediaExt -contains $ext) { $destFolder = $mediaFolder }
        elseif ($rawExt -contains $ext) { $destFolder = $rawFolder }
        elseif ($soHifExt -contains $ext) { $destFolder = $soHifFolder }
        else { $destFolder = $soJpgFolder }
        if (-not $destFolder) { $destFolder = Join-Path $archiveRoot (if ($mediaExt -contains $ext) { 'Medias' } elseif ($rawExt -contains $ext) { 'RAW_arw' } elseif ($soHifExt -contains $ext) { 'SO_hif' } else { 'SO_jpg' }) ; if (-not (Test-Path -LiteralPath $destFolder)) { New-Item -ItemType Directory -Path $destFolder -Force | Out-Null } }
        $destPath = Join-Path $destFolder $file.Name
        $origChecksum = Get-FileChecksum -Path $file.FullName
        if (Test-Path -LiteralPath $destPath) {
            $skippedCount++
            $destChecksum = Get-FileChecksum -Path $destPath
            $moveLog += @{ Original=$file.FullName; Dest=$destPath; Size=$file.Length; Timestamp=(Get-Date).ToString('o'); Status='Conflict'; OrigChecksum=$origChecksum; DestChecksum=$destChecksum }
            continue
        }
        try {
            Move-Item -LiteralPath $file.FullName -Destination $destPath
            $movedCount++
            $totalBytes += $file.Length
            $moveLog += @{ Original=$file.FullName; Dest=$destPath; Size=$file.Length; Timestamp=(Get-Date).ToString('o'); Status='Moved'; OrigChecksum=$origChecksum }
        } catch {
            $failedCount++
            $moveLog += @{ Original=$file.FullName; Dest=$destPath; Size=$file.Length; Timestamp=(Get-Date).ToString('o'); Status='Failed'; Error=$_.Exception.Message; OrigChecksum=$origChecksum }
        }
    }

    $archiveMoveLog  = Join-Path $archiveRoot 'archive_move_log.json'
    $archiveSession  = Join-Path $archiveRoot 'archive_session.json'
    $archiveSummary  = Join-Path $archiveRoot 'archive_summary.txt'
    $moveLog | ConvertTo-Json -Depth 6 | Out-File -FilePath $archiveMoveLog -Encoding UTF8
    $endTime = Get-Date; $elapsed = $endTime - $startTime; $bytesPerSec = if ($elapsed.TotalSeconds -gt 0) {[math]::Round($totalBytes/$elapsed.TotalSeconds,0)} else {0}
    $session = @{ SessionId = ([guid]::NewGuid()).Guid; Option = $Option; Start = $startTime.ToString('o'); End = $endTime.ToString('o'); ElapsedSeconds = [math]::Round($elapsed.TotalSeconds,2); Moved = $movedCount; Skipped = $skippedCount; Failed = $failedCount; TotalBytes = $totalBytes; BytesPerSec = $bytesPerSec }
    $session | ConvertTo-Json -Depth 6 | Out-File -FilePath $archiveSession -Encoding UTF8
    $summary = @(); $summary += '------------------------------------------------------------------------------'; $summary += "Archive summary for: $DateFolder"; $summary += "Start : $($startTime)"; $summary += "End   : $($endTime)"; $summary += "Elapsed: $($elapsed)"; $summary += "Moved : $movedCount"; $summary += "Skipped(conflicts): $skippedCount"; $summary += "Failed: $failedCount"; $summary += "Bytes moved: $totalBytes"; $summary += "Speed (bytes/sec): $bytesPerSec"; $summary += "SessionId: $($session.SessionId)"; $summary += '------------------------------------------------------------------------------'
    $summary | Out-File -FilePath $archiveSummary -Encoding UTF8; $summary | ForEach-Object { Write-Host $_ }
    # produce unified JSON
    try { Write-UnifiedArchiveJson -DateFolder $DateFolder } catch {}
    return $true
}

# Migrate old artifact files (non-log) into an earlierLOGs folder placed alongside date folders (arcv root)
function Migrate-OldArtifacts {
    param([string]$ArcvRoot)
    try {
        if (-not (Test-Path -LiteralPath $ArcvRoot)) { return }
        $earlier = Join-Path $ArcvRoot 'earlierLOGs'
        if (-not (Test-Path -LiteralPath $earlier)) { New-Item -ItemType Directory -Path $earlier -Force | Out-Null }

        # Patterns to migrate (external artifacts we want unified) - exclude .log files and operational logs
        $patterns = @('archive_move_log.json','archive_summary.txt','archive_list_full.txt','unified_archive.json')

        # find files only directly under the arcv root (do not descend into date subfolders)
        $candidates = @()
        foreach ($p in $patterns) {
            $candidates += Get-ChildItem -LiteralPath $ArcvRoot -Filter $p -File -ErrorAction SilentlyContinue
        }

        foreach ($f in $candidates | Sort-Object LastWriteTime) {
            try {
                # build new name using file's last write time
                $ts = $f.LastWriteTime.ToString('yyyyMMdd_HHmmss')
                $newName = "$ts`_$($f.Name)"
                $destPath = Join-Path $earlier $newName
                if (-not (Test-Path -LiteralPath $destPath)) {
                    Move-Item -LiteralPath $f.FullName -Destination $destPath -Force
                    Write-HostAndLog -BasePath $ArcvRoot -Level "INFO" -Message "Migrated artifact: $($f.FullName) -> $destPath"
                } else {
                    # if already exists, append an index
                    $i = 1
                    while (Test-Path -LiteralPath (Join-Path $earlier ("${ts}_$i`_$($f.Name)"))) { $i++ }
                    $destPath = Join-Path $earlier ("${ts}_$i`_$($f.Name)")
                    Move-Item -LiteralPath $f.FullName -Destination $destPath -Force
                    Write-HostAndLog -BasePath $ArcvRoot -Level "INFO" -Message "Migrated artifact (dedup): $($f.FullName) -> $destPath"
                }
            } catch {
                Write-HostAndLog -BasePath $ArcvRoot -Level "ERROR" -Message "Failed migrating $($f.FullName): $($_.Exception.Message)"
            }
        }
    } catch {
        Write-HostAndLog -BasePath $ArcvRoot -Level "ERROR" -Message "Migrate-OldArtifacts failed: $($_.Exception.Message)"
    }
}

# Write a unified JSON that collects move-log, summary and full-list into a single file under the date folder
function Write-UnifiedArchiveJson {
    param([string]$DateFolder)
    try {
        if (-not (Test-Path -LiteralPath $DateFolder)) { return }
        $moveLogPath = Join-Path $DateFolder 'archive_move_log.json'
        $summaryPath = Join-Path $DateFolder 'archive_summary.txt'
        $listPath    = Join-Path $DateFolder 'archive_list_full.txt'
        $outPath     = Join-Path $DateFolder 'unified_archive.json'

        $result = @{}
        $result.Date = (Get-Item -LiteralPath $DateFolder).Name

        if (Test-Path -LiteralPath $moveLogPath) {
            try { $result.MoveLog = Get-Content -LiteralPath $moveLogPath -Raw | ConvertFrom-Json } catch { $result.MoveLog = @() }
        } else { $result.MoveLog = @() }

        # Read structured session metadata if present
        $sessionPath = Join-Path $DateFolder 'archive_session.json'
        if (Test-Path -LiteralPath $sessionPath) {
            try { $result.Session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json } catch { $result.Session = $null }
        } else { $result.Session = $null }

        if (Test-Path -LiteralPath $summaryPath) {
            $summaryLines = Get-Content -LiteralPath $summaryPath -ErrorAction SilentlyContinue
            # try to parse known keys from human summary (fallback)
            $result.Summary = @{ Raw = $summaryLines -join "`n" }
        } else { $result.Summary = @{ Raw = "" } }

        if (Test-Path -LiteralPath $listPath) {
            $listLines = Get-Content -LiteralPath $listPath -ErrorAction SilentlyContinue
            $result.FullList = $listLines
        } else { $result.FullList = @() }

        $result.GeneratedAt = (Get-Date).ToString('o')
        $result | ConvertTo-Json -Depth 6 | Out-File -FilePath $outPath -Encoding UTF8
        Write-HostAndLog -BasePath $DateFolder -Level "INFO" -Message "Unified archive JSON written: $outPath"
    } catch {
        Write-HostAndLog -BasePath $DateFolder -Level "ERROR" -Message "Write-UnifiedArchiveJson failed: $($_.Exception.Message)"
    }
}

# Restore artifact files from earlierLOGs back into a target date folder
function Restore-ArtifactsFromEarlier {
    param([string]$DateFolder)
    $root = Split-Path $DateFolder -Parent
    $earlier = Join-Path $root 'earlierLOGs'
    if (-not (Test-Path -LiteralPath $earlier)) { Write-HostAndLog -BasePath $root -Level "INFO" -Message "No earlierLOGs folder found at $earlier"; return $false }
    $patterns = @('*archive_move_log.json','*archive_summary.txt','*unified_archive.json','*archive_list_full.txt','*archive_session.json')
    $moved = 0
    foreach ($pat in $patterns) {
        $files = Get-ChildItem -LiteralPath $earlier -File -Filter $pat -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $origName = $f.Name -replace '^[0-9_]+',''
            $target = Join-Path $DateFolder $origName
            if (Test-Path -LiteralPath $target) { $target = Join-Path $DateFolder $f.Name }
            try { Move-Item -LiteralPath $f.FullName -Destination $target -Force; Write-HostAndLog -BasePath $root -Level "INFO" -Message "Restored: $($f.Name) -> $target"; $moved++ } catch { Write-HostAndLog -BasePath $root -Level "ERROR" -Message "Restore failed for $($f.Name): $($_.Exception.Message)" }
        }
    }
    if ($moved -eq 0) { Write-HostAndLog -BasePath $root -Level "INFO" -Message "No artifact files restored from earlierLOGs" } else { Write-HostAndLog -BasePath $root -Level "INFO" -Message "Restored $moved artifact files to $DateFolder" }
    return $true
}


# ---------------------------
# Rollback / Restore utilities
# ---------------------------

# Load move entries from unified json or legacy move log
function Get-ArchiveMoveEntries {
    param([string]$DateFolder)
    $entries = @()
    $unified = Join-Path $DateFolder 'unified_archive.json'
    $moveLog = Join-Path $DateFolder 'archive_move_log.json'
    # Prefer explicit archive_move_log.json; fall back to unified if it contains MoveLog
    if (Test-Path -LiteralPath $moveLog) {
        try { $entries = Get-Content -LiteralPath $moveLog -Raw | ConvertFrom-Json } catch { Write-HostAndLog -BasePath $DateFolder -Level "WARN" -Message "Failed parse move log: $($_.Exception.Message)" }
    }
    # Normalize to array: ConvertFrom-Json may return a single PSCustomObject for single-element arrays
    if ($entries -and -not ($entries -is [array])) { $entries = @($entries) }
    if ((-not $entries -or $entries.Count -eq 0) -and (Test-Path -LiteralPath $unified)) {
        try {
            $u = Get-Content -LiteralPath $unified -Raw | ConvertFrom-Json
            if ($u.MoveLog) {
                $entries = $u.MoveLog
                if ($entries -and -not ($entries -is [array])) { $entries = @($entries) }
            }
        } catch {
            Write-HostAndLog -BasePath $DateFolder -Level "WARN" -Message "Failed parse unified json: $($_.Exception.Message)"
        }
    }
    return $entries
}

# Invoke rollback given a date folder's archive records
function Invoke-Rollback {
    param(
        [string]$DateFolder,
        [switch]$Apply,
        [int]$BatchSize = 100,
        [switch]$Overwrite,
        [switch]$VerifyAfterRestore
    )
    if (-not (Test-Path -LiteralPath $DateFolder)) { Write-HostAndLog -BasePath $DateFolder -Level "ERROR" -Message "Rollback: DateFolder not found: $DateFolder"; return $false }

    $entries = Get-ArchiveMoveEntries -DateFolder $DateFolder
    if ($entries -and -not ($entries -is [array])) { $entries = @($entries) }
    if (-not $entries -or $entries.Count -eq 0) { Write-HostAndLog -BasePath $DateFolder -Level "INFO" -Message "Rollback: no move entries found for $DateFolder"; return $false }

    $rollbackLogPath = Join-Path $DateFolder 'rollback_log.json'
    $results = @()
    $total = $entries.Count
    Write-HostAndLog -BasePath $DateFolder -Level "INFO" -Message "Rollback: processing $total entries (BatchSize=$BatchSize) Apply=$($Apply.IsPresent) Overwrite=$($Overwrite.IsPresent)"

    $i = 0
    foreach ($chunk in $entries) {
        # process sequentially; For compatibility we simply iterate
        $i++
        $orig = $chunk.Original
        $dest = $chunk.Dest
        $rec = @{ Original = $orig; Dest = $dest; AttemptedAt = (Get-Date).ToString('o'); Status = 'Pending' }
        if (-not (Test-Path -LiteralPath $dest)) {
            $rec.Status = 'MissingDest'
            $rec.Message = 'Dest not found'
            $results += $rec; continue
        }

        # include expected checksum information if present in move log
        if ($chunk.PSObject.Properties.Match('OrigChecksum').Count -gt 0) { $rec.ExpectedChecksum = $chunk.OrigChecksum }
        if (-not $Apply.IsPresent) {
            # include dest checksum for dry-run visibility
            $rec.DestChecksum = Get-FileChecksum -Path $dest
            $rec.Status = 'DryRun' ; $results += $rec; continue
        }

        try {
            # ensure parent folder for original exists
            $origDir = Split-Path $orig -Parent
            if (-not (Test-Path -LiteralPath $origDir)) { New-Item -ItemType Directory -Path $origDir -Force | Out-Null }

            if (Test-Path -LiteralPath $orig) {
                if ($Overwrite.IsPresent) {
                    # create a versioned backup (preserve all versions)
                    $bak = Save-FileVersionBackup -OrigPath $orig -DateFolder $DateFolder
                    if ($bak) { $rec.BackupPath = $bak }
                    Move-Item -LiteralPath $dest -Destination $orig -Force
                    $rec.Status = 'RestoredOverwrote'
                    $rec.Message = "Original existed; backed up to $bak and restored from $dest"
                } else {
                    # do not touch originals if not overwriting; record checksums for decision
                    $rec.Status = 'Conflict'
                    $rec.Message = 'Original exists; skipped (use Overwrite to force)'
                    $rec.DestChecksum = Get-FileChecksum -Path $dest
                    $results += $rec; continue
                }
            } else {
                Move-Item -LiteralPath $dest -Destination $orig -Force
                $rec.Status = 'Restored'
                $rec.Message = 'Moved dest back to original'
            }

            # post-restore verification (if requested and expected checksum available)
            $restoredChecksum = Get-FileChecksum -Path $orig
            $rec.RestoredChecksum = $restoredChecksum
            if ($chunk.PSObject.Properties.Match('OrigChecksum').Count -gt 0) {
                $rec.ExpectedChecksum = $chunk.OrigChecksum
                if ($VerifyAfterRestore.IsPresent) {
                    if ($restoredChecksum -and ($restoredChecksum -eq $chunk.OrigChecksum)) {
                        $rec.Verified = $true
                        $rec.Message = ($rec.Message + ' -- Verified')
                    } else {
                        $rec.Verified = $false
                        $rec.Message = ($rec.Message + ' -- VerifyFailed')
                        # keep backup if present (do not delete)
                    }
                }
            }
        } catch {
            $rec.Status = 'Failed'; $rec.Message = $_.Exception.Message
        }
        $results += $rec

        # periodic flush
        if (($results.Count % $BatchSize) -eq 0) { $results | ConvertTo-Json -Depth 6 | Out-File -FilePath $rollbackLogPath -Encoding UTF8 }
    }

    # final write
    $results | ConvertTo-Json -Depth 6 | Out-File -FilePath $rollbackLogPath -Encoding UTF8
    Write-HostAndLog -BasePath $DateFolder -Level "INFO" -Message "Rollback complete. Log: $rollbackLogPath"
    return $true
}

# Interactive wrapper to prompt user for rollback options and run
function Prompt-And-Run-Rollback {
    param()
    Write-Host "Rollback mode: enter an arcv root path OR a specific date-folder path."

    # Loop until a valid root or date-folder is provided
    while ($true) {
        $inputPath = Read-Host "Enter arcv root or date-folder path (press Enter for script path: $PSScriptRoot)"
        if ([string]::IsNullOrWhiteSpace($inputPath)) { $inputPath = $PSScriptRoot }

        if (-not (Test-Path -LiteralPath $inputPath)) {
            Write-HostAndLog -BasePath $PSScriptRoot -Level "WARN" -Message "Path not found: $inputPath. Please try again."
            continue
        }

        $item = Get-Item -LiteralPath $inputPath -ErrorAction SilentlyContinue
        if (-not $item -or -not $item.PSIsContainer) {
            Write-HostAndLog -BasePath $PSScriptRoot -Level "WARN" -Message "Path is not a directory: $inputPath. Please enter a directory path."
            continue
        }

        # If the provided path itself is a date-folder, use it directly
        if ($item.Name -match '^\d{4}-\d{2}-\d{2}') {
            $dateFolders = @($item)
        } else {
            # Otherwise, treat input as arcv root and search for date folders beneath it
            $dateFolders = Get-ChildItem -LiteralPath $inputPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}($|[^0-9])' }
        }

        if (-not $dateFolders -or $dateFolders.Count -eq 0) {
            Write-HostAndLog -BasePath $inputPath -Level "WARN" -Message "No date folders found under: $inputPath. Please try again or provide a specific date-folder path."
            continue
        }

        # Let user select a date folder from the discovered list
        $sel = Select-DateFolder -Folders $dateFolders -BasePath $inputPath
        if (-not $sel) { Write-HostAndLog -BasePath $inputPath -Level "INFO" -Message "No selection made. Exiting rollback prompt."; return }
        $dateFolder = $sel.FullName
        break
    }

    # present a small menu of rollback actions to keep interaction simple
    while ($true) {
        Write-Host "`nRollback actions for: $dateFolder"
        Write-Host "1) Dry-run all entries (safe)"
        Write-Host "2) Apply all entries (restore)"
        Write-Host "3) Apply all with Overwrite (force)"
        Write-Host "4) Show available archive sessions"
        Write-Host "5) Exit rollback mode"
        $act = Read-Host "Choose action (1-5)"
        switch ($act) {
            '1' {
                Write-HostAndLog -BasePath $dateFolder -Level "INFO" -Message "Rollback action: Dry-run all"
                Invoke-Rollback -DateFolder $dateFolder -BatchSize 100
            }
            '2' {
                $confirm = Read-Host "Apply restore for all entries? This will MOVE files. Type APPLY to confirm"
                if ($confirm -eq 'APPLY') { Invoke-Rollback -DateFolder $dateFolder -BatchSize 100 -Apply } else { Write-Host "Cancelled." }
            }
            '3' {
                $confirm = Read-Host "Apply restore and overwrite existing originals? Type FORCE to confirm"
                if ($confirm -eq 'FORCE') { Invoke-Rollback -DateFolder $dateFolder -BatchSize 100 -Apply -Overwrite } else { Write-Host "Cancelled." }
            }
            '4' {
                # show session info if available
                $sessPath = Join-Path $dateFolder 'archive_session.json'
                if (Test-Path -LiteralPath $sessPath) { Get-Content -LiteralPath $sessPath | Write-Host } else { Write-Host "No session metadata found." }
            }
            default { break }
        }
    }
}


# --------- main ----------
function Sync-RawAndSo {
    param([string]$ScriptPath)

    Write-Log -BasePath $ScriptPath -Level "INFO" -Message "Sync-RawAndSo start"

    $ctx = Get-Context -ScriptPath $ScriptPath
    Write-Log -BasePath $ScriptPath -Level "INFO" -Message "Context mode: $($ctx.Mode)"

    if ($ctx.Mode -eq 'Invalid') {
        Invoke-TestMode -BasePath $ScriptPath
        return
    }

    $dateFolder = $ctx.DateFolder
    if ($ctx.Mode -eq 'ArcvRoot') {
        $dateFolders = Get-ChildItem -LiteralPath $ScriptPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}($|[^0-9])' }
        if ($dateFolders.Count -eq 0) {
            Write-Host "No date folders found."
            Write-Log -BasePath $ScriptPath -Level "ERROR" -Message "No date folders under '$ScriptPath'"
            Invoke-TestMode -BasePath $ScriptPath
            return
        }
        $selectedFolders = Select-DateFoldersRange -Folders $dateFolders -BasePath $ScriptPath
        Write-Log -BasePath $ScriptPath -Level "INFO" -Message ("Selected folders: " + (($selectedFolders | ForEach-Object Name) -join ', '))
        # Invoke auto-archive for each selected date folder
        try {
            $archMode = Show-ArchiveModes
            $continueAfterArchive = $true
            foreach ($df in $selectedFolders) {
                Write-Log -BasePath $ScriptPath -Level "INFO" -Message "Auto-archiving: '$($df.FullName)'"
                $cont = Invoke-AutoArchive -DateFolder $df.FullName -ListLimit 100 -ArchiveMode $archMode
                try { Write-UnifiedArchiveJson -DateFolder $df.FullName } catch {}
                if (-not $cont) { $continueAfterArchive = $false }
            }
        } catch {
            Write-Log -BasePath $ScriptPath -Level "ERROR" -Message "AutoArchive failed: $($_.Exception.Message)"
            $continueAfterArchive = $true
        }
        if (-not $continueAfterArchive) {
            Write-Log -BasePath $ScriptPath -Level "INFO" -Message "User chose to end after archive."
            return
        }
    }

    if ($ctx.Mode -eq 'Date') {
        $detectedName = Split-Path $ScriptPath -Leaf
        $confirmDate = Read-Host "Detected date folder [$detectedName]. Use this date? (Y/N)"
        if ($confirmDate -eq 'N') {
            Write-Log -BasePath $ScriptPath -Level "ERROR" -Message "User rejected auto-detected date folder."
            Invoke-TestMode -BasePath $ScriptPath
            return
        }
        Write-Log -BasePath $ScriptPath -Level "INFO" -Message "Using date folder: '$($dateFolder.FullName)'"
        # Invoke auto-archive before continuing to sync
        try {
            $archMode = Show-ArchiveModes
            $continueAfterArchive = Invoke-AutoArchive -DateFolder $dateFolder.FullName -ListLimit 100 -ArchiveMode $archMode
            # create unified JSON for this date folder
            try { Write-UnifiedArchiveJson -DateFolder $dateFolder.FullName } catch {}
        } catch {
            Write-Log -BasePath $ScriptPath -Level "ERROR" -Message "AutoArchive failed: $($_.Exception.Message)"
            $continueAfterArchive = $true
        }
        if (-not $continueAfterArchive) {
            Write-Log -BasePath $ScriptPath -Level "INFO" -Message "User chose to end after archive."
            return
        }
    }

    # Determine Stills folder
    if ($ctx.Mode -eq 'Stills') {
        $stillsFolder = $ctx.StillsFolder
    } else {
        $sf = Join-Path $dateFolder.FullName "Stills"
        if (Test-Path -LiteralPath $sf) { $stillsFolder = $sf } else { $stillsFolder = $dateFolder.FullName }
    }
    Write-Log -BasePath $ScriptPath -Level "INFO" -Message "Stills folder: '$stillsFolder'"

    # Let user choose matching strategy before folder detection
    Show-MatchOptions

    # Detect RAW/SO folders
    if ($ctx.Mode -eq 'Stills') {
        $rawSo = Find-RawSoFolders -BasePath $stillsFolder -SearchSameLevel:$true
    } else {
        $rawSo = Find-RawSoFolders -BasePath $dateFolder.FullName -SearchSameLevel:$false
    }

    if (-not $rawSo.RawFolder -or -not $rawSo.SoFolder) {
        Write-Host "RAW/SO folders not found."
        Write-Log -BasePath $ScriptPath -Level "ERROR" -Message "RAW/SO not found; Stills='$stillsFolder'"
        Invoke-TestMode -BasePath $ScriptPath
        return
    }

    $rawFolder = $rawSo.RawFolder.FullName
    $soFolder  = $rawSo.SoFolder.FullName
    Write-Log -BasePath $ScriptPath -Level "INFO" -Message "RAW='$rawFolder'; SO='$soFolder'"

    # Prepare operational log and trash folder
    $trashFolder = Join-Path $stillsFolder "trashTEMP"
    $opLog       = Join-Path $stillsFolder "sync_log.txt"
    if (-not (Test-Path -LiteralPath $trashFolder)) { New-Item -ItemType Directory -Path $trashFolder -Force | Out-Null }
    Write-Log -BasePath $ScriptPath -Level "INFO" -Message "trashTEMP='$trashFolder'; opLog='$opLog'"

    # Whitelist: create or edit via Ensure-Whitelist; supports Y/N/M
    $whitelist = @()
    $whitelistFile = Join-Path $stillsFolder "whitelist.txt"
    $wlAction = Ensure-Whitelist -WhitelistPath $whitelistFile
    if ($wlAction -eq 'modify') {
        Write-HostAndLog -BasePath $ScriptPath -Level "INFO" -Message "User chose to modify whitelist. Exiting for edit."
        SafeExitWithPause "Exiting for whitelist edit. Press Enter to close."
        return
    } elseif ($wlAction -eq 'use') {
        try {
            $rawEntries = Get-Content -LiteralPath $whitelistFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            # normalize: ignore commented lines and strip extensions; compare base names case-insensitive
            $normalizedWhitelist = $rawEntries | Where-Object { -not ($_.StartsWith('#')) } | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_).ToUpperInvariant() }
            $whitelist = $normalizedWhitelist
            Write-HostAndLog -BasePath $ScriptPath -Level "INFO" -Message "Whitelist loaded with $($whitelist.Count) entries."
        } catch {
            Write-HostAndLog -BasePath $ScriptPath -Level "ERROR" -Message "Failed to read whitelist: $($_.Exception.Message)"
            $whitelist = @()
        }
        $useWhitelist = 'Y'
    } else {
        $useWhitelist = 'N'
    }

    # Build diff list
    $soBases  = Get-ChildItem -LiteralPath $soFolder -File -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName }
    $rawFiles = Get-ChildItem -LiteralPath $rawFolder -File -ErrorAction SilentlyContinue
    $diff = @()
    foreach ($rf in $rawFiles) {
        $base = $rf.BaseName
        if (-not ($soBases -contains $base)) {
            if ($useWhitelist -eq 'Y' -and ($whitelist -contains $base.ToUpperInvariant())) {
                Add-Content -Path $opLog -Value "[$(Get-Date)] Skipped by whitelist: $($rf.Name)"
            } else {
                $diff += $rf
            }
        }
    }

    if ($diff.Count -eq 0) {
        Write-Host "No scrap files detected."
        Write-Log -BasePath $ScriptPath -Level "INFO" -Message "No scrap files detected."
        return
    }

    Write-Host "Scrap files detected:"
    $diff | ForEach-Object { Write-Host $_.Name }
    Write-Log -BasePath $ScriptPath -Level "INFO" -Message ("Scrap list: " + (($diff | ForEach-Object Name) -join ', '))

    $choice = Read-Host "`nMove ALL scrap files to trashTEMP? (Y/N)"
    if ($choice -eq 'Y') {
        foreach ($rf in $diff) {
            try {
                Move-Item -LiteralPath $rf.FullName -Destination $trashFolder
                Add-Content -Path $opLog -Value "[$(Get-Date)] Moved to trashTEMP: $($rf.Name)"
            } catch {
                Write-Host "Move failed: $($_.Exception.Message)"
                Write-Log -BasePath $ScriptPath -Level "ERROR" -Message "Move failed for '$($rf.FullName)': $($_.Exception.Message)"
            }
        }
        Write-Host "All scrap files moved."
        Write-Log -BasePath $ScriptPath -Level "INFO" -Message "Moved scrap count: $($diff.Count)"
    } else {
        Write-Host "No files moved."
        Write-Log -BasePath $ScriptPath -Level "INFO" -Message "User declined bulk move."
    }

    $deleteChoice = Read-Host "`nMove trashTEMP contents to Recycle Bin now? (Y/N)"
    if ($deleteChoice -eq 'Y') {
        try {
            $shell = New-Object -ComObject Shell.Application
            $trashItems = Get-ChildItem -LiteralPath $trashFolder -File -ErrorAction SilentlyContinue
            foreach ($item in $trashItems) {
                $folder = Split-Path $item.FullName -Parent
                $file   = Split-Path $item.FullName -Leaf
                $shell.Namespace($folder).ParseName($file).InvokeVerb("delete")
                Add-Content -Path $opLog -Value "[$(Get-Date)] Deleted to Recycle Bin: $($item.Name)"
            }
            Write-Log -BasePath $ScriptPath -Level "INFO" -Message "Recycle Bin deletions: $($trashItems.Count)"
        } catch {
            Write-Host "Delete to Recycle Bin failed: $($_.Exception.Message)"
            Write-Log -BasePath $ScriptPath -Level "ERROR" -Message "RecycleBin delete failed: $($_.Exception.Message)"
        }
    }

    Write-Host "`nDONE! Log saved in: $opLog"
    Start-Process notepad.exe $opLog
}

# --------- entrypoint ----------
try {
    $null = Init-LatestLog -BasePath $ScriptPath
    Write-Log -BasePath $ScriptPath -Level "INFO" -Message "Script started at $ScriptPath"
    # On every start, attempt to migrate legacy artifact files (non-log) into an earlierLOGs sibling folder
    try { Migrate-OldArtifacts -ArcvRoot $ScriptPath } catch { Write-Log -BasePath $ScriptPath -Level "WARN" -Message "Migrate-OldArtifacts failed at startup: $($_.Exception.Message)" }
    # Startup prompt: offer rollback before continuing to sync
    if (-not $SkipMain.IsPresent) {
        $rb = Read-Host "Run rollback mode before sync? (Y/N) [default N]"
        if ($rb -ieq 'Y') {
            Write-HostAndLog -BasePath $ScriptPath -Level "INFO" -Message "User chose to enter rollback mode at startup"
            Prompt-And-Run-Rollback
            $contAfter = Read-Host "Rollback finished. Continue to normal sync? (Y/N) [default N]"
            if ($contAfter -ieq 'Y') { Sync-RawAndSo -ScriptPath $ScriptPath } else { Write-HostAndLog -BasePath $ScriptPath -Level "INFO" -Message "User chose to exit after rollback."; SafeExitWithPause "Exiting as requested."; return }
        } else {
            Sync-RawAndSo -ScriptPath $ScriptPath
        }
    } else {
        # Skip main run so caller can invoke functions (used for tests)
        Write-HostAndLog -BasePath $ScriptPath -Level "INFO" -Message "SkipMain set: not running Sync-RawAndSo automatically"
    }
} 

catch {
    Write-Host "ERROR (unhandled): $($_.Exception.Message)"
    Write-Log -BasePath $ScriptPath -Level "ERROR" -Message "Unhandled exception: $($_.Exception.Message)"
    try { Start-Process notepad.exe (Join-Path $ScriptPath "latest.log") } catch {}
    SafeExitWithPause "Unhandled error occurred. Press Enter to exit."
      }
