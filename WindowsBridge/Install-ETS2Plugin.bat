@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-ETS2Plugin.ps1"
if errorlevel 1 (
  echo.
  echo Plugin installation did not finish. See the message above and try again.
)
pause
