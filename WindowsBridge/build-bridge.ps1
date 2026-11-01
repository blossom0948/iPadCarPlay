$ErrorActionPreference = "Stop"
$project = Join-Path $PSScriptRoot "BridgeServer\BridgeServer.csproj"
$output = Join-Path $PSScriptRoot "dist\BridgeServer"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET 8 SDK가 필요합니다. https://dotnet.microsoft.com/download/dotnet/8.0 에서 Windows x64 SDK를 설치하세요."
}

dotnet publish $project -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o $output
if ($LASTEXITCODE -ne 0) { throw "Windows 브리지 빌드에 실패했습니다." }
Write-Host "완료: $output\BridgeServer.exe"
