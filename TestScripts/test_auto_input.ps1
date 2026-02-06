#!/usr/bin/env powershell
# Automated test: 26,28~29 with option 7 (dry-run, no moves)
# Input: 26,28~29 (range), option 7 (do not run), Enter (dry-run)

$testInput = @(
    "26,28~29",    # folder selection
    "7",           # option 7 (do not run)
    "",            # press Enter (dry-run, default)
    ""             # press Enter (end after dry-run)
) -join "`n"

$ScriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
$testInput | & "$ScriptPath\!Sync-RawAndSo.ps1"
