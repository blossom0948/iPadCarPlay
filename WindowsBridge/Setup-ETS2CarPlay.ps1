$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
$script:setupLogPath = if ([string]::IsNullOrWhiteSpace($env:ETS2CP_SETUP_LOG)) {
    Join-Path $env:TEMP "ETS2CarPlay-setup.log"
} else {
    $env:ETS2CP_SETUP_LOG
}

function Write-SetupLog([string]$message) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $message
    try { Add-Content -LiteralPath $script:setupLogPath -Value $line -Encoding UTF8 } catch {}
    Write-Host $line
}

function Show-Message([string]$text, [string]$title, [System.Windows.Forms.MessageBoxIcon]$icon = [System.Windows.Forms.MessageBoxIcon]::Information) {
    Write-SetupLog ("{0}: {1}" -f $title, $text)
    [System.Windows.Forms.MessageBox]::Show($text, $title, [System.Windows.Forms.MessageBoxButtons]::OK, $icon) | Out-Null
}

trap {
    $errorText = $_ | Out-String
    Write-SetupLog "Unexpected setup error: $errorText"
    try {
        Show-Message "설치 중 예상하지 못한 오류가 발생했습니다.`n`n$errorText`n로그: $script:setupLogPath" "설치 오류" ([System.Windows.Forms.MessageBoxIcon]::Error)
    } catch {}
    exit 1
}

Write-SetupLog "Setup started. Bundle folder: $PSScriptRoot"
$requiredFiles = @("BridgeServer.exe", "controls.json", "ets2carplay_telemetry.dll", "Install-ETS2Plugin.ps1", "Start-Bridge.bat", "Reset-Pairing.bat", "README-FIRST.txt")
$missingFiles = $requiredFiles | Where-Object { -not (Test-Path (Join-Path $PSScriptRoot $_)) }
if ($missingFiles) {
    Show-Message ("다운로드한 Windows ZIP을 모두 압축 풀었는지 확인하세요. 다음 파일이 없습니다:`n" + ($missingFiles -join "`n")) "설치 파일을 찾지 못했습니다" ([System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

if (Get-Process -Name eurotrucks2 -ErrorAction SilentlyContinue) {
    Show-Message "설치 전에 ETS2를 완전히 종료해 주세요." "ETS2를 먼저 종료하세요" ([System.Windows.Forms.MessageBoxIcon]::Warning)
    exit 1
}
if (Get-Process -Name BridgeServer -ErrorAction SilentlyContinue) {
    Show-Message "업데이트 전에 ETS2 CarPlay 브리지 검은 창을 닫아 주세요. 설치가 끝난 뒤 바탕 화면 바로 가기로 다시 실행하면 됩니다." "브리지를 먼저 종료하세요" ([System.Windows.Forms.MessageBoxIcon]::Warning)
    exit 1
}

$gameRoot = $null
$defaultRoot = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)) "Steam\steamapps\common\Euro Truck Simulator 2"
if (Test-Path (Join-Path $defaultRoot "bin\win_x64")) {
    Write-SetupLog "Found ETS2 in the default Steam folder: $defaultRoot"
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "기본 Steam 위치에서 ETS2를 찾았습니다.`n`n$defaultRoot`n`n이 폴더를 사용하시겠습니까?",
        "ETS2 설치 위치 확인",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) { $gameRoot = $defaultRoot }
}

if (-not $gameRoot) {
    Write-SetupLog "Default Steam folder not found or declined; opening folder picker."
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Steam의 Euro Truck Simulator 2 폴더를 선택하세요. 선택할 폴더 안에 bin\win_x64가 있어야 합니다."
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Show-Message "폴더 선택이 취소되어 설치를 끝내지 않았습니다. 다시 실행한 뒤 ETS2 설치 폴더를 선택하세요." "ETS2 폴더 선택 취소" ([System.Windows.Forms.MessageBoxIcon]::Information)
        exit 1
    }
    $gameRoot = $dialog.SelectedPath
}
Write-SetupLog "Selected ETS2 folder: $gameRoot"

if (-not (Test-Path (Join-Path $gameRoot "bin\win_x64"))) {
    Show-Message "선택한 폴더에서 bin\win_x64를 찾지 못했습니다. Steam에서 ETS2를 마우스 오른쪽 버튼으로 눌러 관리 > 로컬 파일 보기를 선택한 뒤 열린 Euro Truck Simulator 2 폴더를 사용하세요." "ETS2 폴더를 확인하세요" ([System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

$pluginInstaller = Join-Path $PSScriptRoot "Install-ETS2Plugin.ps1"
$arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -GameRoot "{1}" -LogPath "{2}" -Elevated' -f $pluginInstaller, $gameRoot, $script:setupLogPath
try {
    Write-SetupLog "Starting elevated telemetry plugin installer."
    $installProcess = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $arguments -Wait -PassThru
    Write-SetupLog "Elevated plugin installer exit code: $($installProcess.ExitCode)"
    if ($installProcess.ExitCode -ne 0) {
        Show-Message "ETS2 플러그인 설치가 종료 코드 $($installProcess.ExitCode)(으)로 실패했습니다.`n`n로그: $script:setupLogPath" "플러그인 설치 실패" ([System.Windows.Forms.MessageBoxIcon]::Error)
        exit $installProcess.ExitCode
    }
} catch {
    Show-Message "Windows 관리자 권한 확인을 취소했거나 플러그인을 설치하지 못했습니다. 다시 실행해 권한 안내에서 예를 선택하세요.`n`n$($_.Exception.Message)" "플러그인 설치 실패" ([System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

$installDirectory = Join-Path $env:LOCALAPPDATA "ETS2CarPlay"
New-Item -ItemType Directory -Force -Path $installDirectory | Out-Null
foreach ($file in @("BridgeServer.exe", "controls.json", "ets2carplay_telemetry.dll", "Start-Bridge.bat", "Reset-Pairing.bat", "README-FIRST.txt")) {
    $source = Join-Path $PSScriptRoot $file
    $destination = Join-Path $installDirectory $file
    if ($file -eq "controls.json" -and (Test-Path $destination)) { continue }
    if (Test-Path $source) { Copy-Item -Force $source $destination }
}

$desktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
$startMenu = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)) "ETS2 CarPlay"
New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
$shell = New-Object -ComObject WScript.Shell

function New-Shortcut([string]$path, [string]$target, [string]$description) {
    $shortcut = $shell.CreateShortcut($path)
    $shortcut.TargetPath = $target
    $shortcut.WorkingDirectory = $installDirectory
    $shortcut.Description = $description
    $shortcut.Save()
}

New-Shortcut (Join-Path $desktop "ETS2 CarPlay 브리지.lnk") (Join-Path $installDirectory "Start-Bridge.bat") "ETS2 텔레메트리 브리지를 시작합니다."
New-Shortcut (Join-Path $startMenu "ETS2 CarPlay 브리지.lnk") (Join-Path $installDirectory "Start-Bridge.bat") "ETS2 텔레메트리 브리지를 시작합니다."
New-Shortcut (Join-Path $startMenu "ETS2 CarPlay 페어링 복구.lnk") (Join-Path $installDirectory "Reset-Pairing.bat") "저장된 iPad 페어링을 초기화하고 새 코드를 발급합니다."

Show-Message "설치가 끝났습니다.`n`n앞으로 ETS2를 실행할 때 바탕 화면의 'ETS2 CarPlay 브리지'를 눌러 검은 창을 열어 두세요. iPad는 같은 공유기 네트워크에 연결합니다. 첫 페어링 뒤에는 브리지를 다시 시작해도 자동으로 연결됩니다.`n`n연결을 새로 설정해야 할 때는 시작 메뉴 > ETS2 CarPlay > ETS2 CarPlay 페어링 복구를 사용하세요." "ETS2 CarPlay 설치 완료"
Write-SetupLog "Setup completed successfully."
