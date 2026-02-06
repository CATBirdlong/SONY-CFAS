# Automated mixed test: 1,3,5~7 then choose 7 (Do not run) and Enter for dry-run
$scriptPath = 'd:\Pictures\PhotosPics-ofCBLnSONY\SONY_Alpha\arcv-e10m2'
$input = @(
    'N',
    '1,3,5~7',
    '7',
    '',
    ''
) -join "`n"

Write-Host "Running mixed dry-run debug test..."
$output = $input | & "$scriptPath\!Sync-RawAndSo.ps1" 2>&1

# Dump last 200 lines for inspection
$output | Select-Object -Last 200 | ForEach-Object { Write-Host $_ }
