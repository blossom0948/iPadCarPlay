@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-ETS2CarPlay.ps1"
if errorlevel 1 (
  echo.
  echo Setup did not finish. Follow the message above and try again.
  pause
)
