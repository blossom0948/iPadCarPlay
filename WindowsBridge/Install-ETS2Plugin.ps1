param(
    [string]$GameRoot = "",
    [switch]$Elevated
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

if ([string]::IsNullOrWhiteSpace($GameRoot)) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Euro Truck Simulator 2 게임 폴더를 선택하세요. 안에 bin 폴더가 있어야 합니다."
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        exit 0
    }
    $GameRoot = $dialog.SelectedPath
}

$pluginSource = Join-Path $PSScriptRoot "ets2carplay_telemetry.dll"
$pluginDirectory = Join-Path $GameRoot "bin\win_x64\plugins"
if (-not (Test-Path $pluginSource)) {
    [System.Windows.Forms.MessageBox]::Show(
        "ets2carplay_telemetry.dll이 없습니다. 다운로드한 Windows 묶음의 파일을 모두 압축 해제했는지 확인하세요.",
        "ETS2 CarPlay 플러그인 설치",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
if (-not (Test-Path (Join-Path $GameRoot "bin\win_x64"))) {
    [System.Windows.Forms.MessageBox]::Show(
        "선택한 폴더 안에서 bin\win_x64를 찾지 못했습니다. Steam의 ETS2 → 관리 → 로컬 파일 보기를 눌러 열린 Euro Truck Simulator 2 폴더를 선택하세요.",
        "ETS2 폴더를 확인하세요",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit 1
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdministrator -and -not $Elevated) {
    $quotedScript = '"' + $PSCommandPath + '"'
    $quotedRoot = '"' + $GameRoot + '"'
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File $quotedScript -GameRoot $quotedRoot -Elevated"
    try {
        Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $arguments -Wait
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "관리자 권한을 허용하지 않아 플러그인을 설치하지 않았습니다. 다시 실행하고 Windows 권한 안내에서 예를 누르세요.",
            "설치가 취소되었습니다",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        exit 1
    }
    exit 0
}

try {
    New-Item -ItemType Directory -Force -Path $pluginDirectory | Out-Null
    Copy-Item -Force $pluginSource (Join-Path $pluginDirectory "ets2carplay_telemetry.dll")
    [System.Windows.Forms.MessageBox]::Show(
        "ETS2 플러그인 설치가 끝났습니다. 다음부터는 Windows 묶음의 Start-Bridge.bat을 실행하세요.",
        "설치 완료",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "플러그인을 복사하지 못했습니다. ETS2가 종료되어 있는지 확인한 뒤 다시 실행하세요.`n`n$($_.Exception.Message)",
        "플러그인 설치 실패",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
