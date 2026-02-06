@echo off
setlocal

set "ps1=%~dp0Sync-RawAndSo.ps1"

if not exist "%ps1%" (
  echo PS1 script not found: "%ps1%"
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ps1%" -ScriptPath "%~dp0"

endlocal