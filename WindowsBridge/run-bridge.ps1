$ErrorActionPreference = "Stop"
$executable = Join-Path $PSScriptRoot "dist\BridgeServer\BridgeServer.exe"
if (-not (Test-Path $executable)) {
    throw "먼저 build-bridge.ps1을 실행해 Windows 브리지를 빌드하세요."
}
& $executable
