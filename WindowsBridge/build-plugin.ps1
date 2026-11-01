param(
    [string]$GameRoot = ""
)

$ErrorActionPreference = "Stop"
$source = Join-Path $PSScriptRoot "TelemetryPlugin"
$build = Join-Path $PSScriptRoot "build\TelemetryPlugin"

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    throw "CMake와 Visual Studio C++ 빌드 도구가 필요합니다. Visual Studio Installer에서 Desktop development with C++를 추가하세요."
}

cmake -S $source -B $build -A x64
if ($LASTEXITCODE -ne 0) { throw "SCS 텔레메트리 플러그인 설정에 실패했습니다." }

cmake --build $build --config Release
if ($LASTEXITCODE -ne 0) { throw "SCS 텔레메트리 플러그인 빌드에 실패했습니다." }

$dll = Join-Path $build "Release\ets2carplay_telemetry.dll"
if (-not (Test-Path $dll)) { throw "빌드된 DLL을 찾을 수 없습니다: $dll" }
Write-Host "완료: $dll"

if (-not [string]::IsNullOrWhiteSpace($GameRoot)) {
    $pluginDirectory = Join-Path $GameRoot "bin\win_x64\plugins"
    New-Item -ItemType Directory -Force -Path $pluginDirectory | Out-Null
    Copy-Item -Force $dll (Join-Path $pluginDirectory "ets2carplay_telemetry.dll")
    Write-Host "ETS2 플러그인 폴더에 설치했습니다: $pluginDirectory"
}
