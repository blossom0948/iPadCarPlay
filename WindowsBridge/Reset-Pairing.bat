@echo off
setlocal
cd /d "%~dp0"
if not exist "BridgeServer.exe" (
  echo BridgeServer.exe is missing. Re-run the ETS2 CarPlay setup from the downloaded bundle.
  pause
  exit /b 1
)
echo Close any other ETS2 CarPlay bridge window first.
echo This creates a new one-time code and replaces the saved iPad pairing.
echo.
pause
"%~dp0BridgeServer.exe" --reset-pairing
