# Interactive test for range selection with folders 30~33
# This test will verify that:
# 1. All 4 folders (30,31,32,33) are selected
# 2. All 4 folders are archived sequentially
# 3. Enter key works for exit

Write-Host @"
╔════════════════════════════════════════════════════════════════════════╗
║  MANUAL TEST: Range Selection and Multi-Folder Archive (30~33)        ║
╚════════════════════════════════════════════════════════════════════════╝

This test requires manual interaction. Follow these steps:

1. You will be asked if you want to run rollback mode
   → Answer: N

2. You will see a list of date folders (1-33)
   → Select: 30~33 (to select folders 30, 31, 32, and 33)

3. You will be asked to choose archive architecture
   → Answer: 1 (for New architecture)

4. For each of the 4 folders, you will see file counts and archive options
   → Choose: 1 (to archive all files: Medias+RAWs+SOs)

5. After all 4 folders are processed:
   - You should see "All archives complete: 4 folders processed"
   - You will be asked "All archives complete. Press 'C' then Enter to continue to sync, or press Enter to end"
   → Answer: (just press Enter to skip sync and exit)

6. Final exit prompt
   → Press Enter to exit

Expected Result: All 4 folders (30, 31, 32, 33) should be archived.

Press Enter to start the test...
"@

Read-Host

cd "d:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2"

# Run the actual script
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File !Sync-RawAndSo.ps1
