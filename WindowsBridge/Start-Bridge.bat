@echo off
setlocal
cd /d "%~dp0"
if not exist "BridgeServer.exe" (
  echo BridgeServer.exe is missing. Download the complete ETS2CarPlay-Windows bundle.
  pause
  exit /b 1
)
echo Keep this window open while playing ETS2.
echo Allow Windows Firewall access on Private networks only if prompted.
echo.
"%~dp0BridgeServer.exe"
echo.
echo The bridge has stopped. Press any key to close this window.
pause >nul
