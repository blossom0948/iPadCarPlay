@echo off
setlocal
cd /d "%~dp0"
set "ETS2CP_SETUP_LOG=%TEMP%\ETS2CarPlay-setup.log"
set "ETS2CP_SETUP_CONSOLE_LOG=%TEMP%\ETS2CarPlay-setup-console.log"
> "%ETS2CP_SETUP_LOG%" echo [%DATE% %TIME%] Launcher started from "%~dp0"
> "%ETS2CP_SETUP_CONSOLE_LOG%" echo PowerShell setup output
if not exist "%~dp0Setup-ETS2CarPlay.ps1" (
  >> "%ETS2CP_SETUP_LOG%" echo Required file missing: Setup-ETS2CarPlay.ps1
  echo The setup script is missing from this folder. Download the complete ETS2CarPlay-Windows artifact and extract all files.
  echo Log: "%ETS2CP_SETUP_LOG%"
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-ETS2CarPlay.ps1" > "%ETS2CP_SETUP_CONSOLE_LOG%" 2>&1
set "SETUP_EXIT_CODE=%ERRORLEVEL%"
if not "%SETUP_EXIT_CODE%"=="0" (
  echo.
  echo Setup stopped with exit code %SETUP_EXIT_CODE%. The reason is recorded below.
  echo.
  type "%ETS2CP_SETUP_LOG%"
  echo.
  type "%ETS2CP_SETUP_CONSOLE_LOG%"
  echo.
  echo Logs: "%ETS2CP_SETUP_LOG%" and "%ETS2CP_SETUP_CONSOLE_LOG%"
  pause
)
exit /b %SETUP_EXIT_CODE%
