# 설치와 ETS2 연동 안내

이 안내는 Mac의 Xcode로 iPad Air에 앱을 설치하고, Windows에서 실행하는 ETS2와 연결하는 과정을 처음부터 설명합니다.

## 먼저 알아둘 점

- 이 앱은 **iPad에서 실행하는 CarPlay 스타일 앱**입니다. Apple CarPlay 자체가 아닙니다. Apple은 iPad에서 CarPlay를 지원하지 않으므로 이 앱은 자동차의 기본 CarPlay 화면에 나타나지 않습니다.
- Windows ETS2와 iPad 앱 사이의 텔레메트리는 **같은 로컬 네트워크**로 전달됩니다. 인터넷은 필요하지 않습니다. PC에 Wi-Fi가 없어도 PC를 공유기에 랜선으로 연결하고 iPad를 그 공유기의 Wi-Fi에 연결하면 됩니다. USB 케이블로 iPad와 Windows 브리지를 직접 연결하는 기능은 없습니다.
- iPadOS 27.0.1을 쓰려면 이를 지원하는 **Xcode 27 이상**을 설치하세요. 프로젝트의 최소 iPadOS 버전은 17입니다.
- Xcode로 설치하는 개발용 앱은 App Store 자동 업데이트 앱이 아닙니다. 코드가 바뀌면 Xcode에서 새 빌드를 다시 실행해야 합니다. 앱 안의 업데이트 확인 기능은 GitHub 공개 릴리스의 버전과 변경 내용을 표시하며, 앱을 직접 교체 설치하지 않습니다.
- 무료 개인 Apple 계정의 개발용 프로비저닝은 7일 뒤 만료될 수 있습니다. 만료 후 앱을 계속 실행하려면 Xcode에서 다시 빌드·설치해야 합니다. [Apple 개발자 계정 안내](https://developer.apple.com/help/account/basics/about-your-developer-account/)

## 준비물

### Mac과 iPad

- macOS에서 실행되는 Xcode 27 이상
- iPad Air와 잠금 해제 암호
- Apple 계정. 무료 개인 계정으로 개발용 서명을 할 수 있습니다.
- USB-C 데이터 케이블은 USB 설치에 필요합니다. Wi-Fi 설치에는 필요하지 않습니다.

Xcode는 [Apple Developer 다운로드](https://developer.apple.com/download/)에서 받습니다. 설치 전에 [Xcode 시스템 요구 사항](https://developer.apple.com/xcode/system-requirements/)에서 Mac의 macOS 버전과 호환되는지 확인하세요. Xcode를 처음 열면 추가 구성 요소 설치가 끝날 때까지 기다립니다.

### Windows PC와 ETS2

- Windows 10 또는 11, 64비트
- Steam에서 설치한 ETS2 1.14 이상
- 준비된 Windows ZIP을 받으려면 인터넷이 되는 기기 한 대 (Windows PC일 필요는 없습니다)
- Xcode 무선 설치 때는 Mac과 iPad가 같은 Wi-Fi에 있어야 합니다. ETS2 실행 때는 Windows PC와 iPad가 같은 공유기 네트워크에 있어야 하며, PC는 Wi-Fi 대신 랜선으로 연결해도 됩니다.

Windows에서는 Visual Studio, CMake, .NET SDK를 설치하지 않아도 됩니다. GitHub가 Windows 빌드 컴퓨터에서 브리지와 ETS2 플러그인을 준비해 ZIP으로 제공합니다. Visual Studio만 설치했고 C++ 구성을 선택하지 않았어도 괜찮습니다.

**Windows PC에서 인터넷을 못 쓰는 경우:** Mac이나 인터넷이 되는 다른 기기에서 GitHub Actions의 `ETS2CarPlay-Windows` ZIP을 내려받아 USB 메모리에 복사한 다음, Windows PC에서 압축을 푸세요. 그 뒤 설치는 오프라인으로 할 수 있습니다. ETS2를 플레이할 때도 인터넷은 필요하지 않습니다. PC를 공유기에 랜선으로 연결하고 iPad를 같은 공유기의 Wi-Fi에 연결하면 됩니다.

## 1. 프로젝트를 Mac에 받기

Mac에서 GitHub 저장소를 복제합니다. [GitHub Desktop](https://desktop.github.com/)을 쓴다면 **File → Clone repository**를 선택하고 `blossom0948/iPadCarPlay`를 고릅니다. 저장 위치는 찾기 쉬운 폴더로 정합니다. Windows PC에는 소스 저장소를 복제할 필요가 없습니다. 준비된 브리지 ZIP만 받으면 됩니다.

명령어를 사용하는 경우 다음 주소를 복제합니다.

```text
https://github.com/blossom0948/iPadCarPlay.git
```

### 이후 빌드와 설치를 빠르게 하기

첫 Xcode 설정을 끝내고 USB로 iPad를 연결하거나 Wi-Fi 페어링을 완료한 다음에는 저장소 안의 **`Install-iPad.command`**를 두 번 눌러 설치할 수 있습니다. 앱을 빌드하고 연결된 iPad에 설치한 뒤 실행합니다. iPad는 잠금 해제해 두세요. Mac에서 스크립트 실행을 막으면 Finder에서 파일을 Control-클릭해 **열기**를 선택합니다.

이 빠른 설치 명령은 Xcode와 Apple 계정 서명이 이미 준비된 경우에 씁니다. 처음 서명하는 날에는 아래 Xcode 설정 절차를 한 번 완료해야 합니다. 개발자 서명 만료 뒤에도 같은 명령을 다시 실행하면 새 빌드를 설치합니다.

## 2. Xcode 서명 설정

1. Mac에서 저장소 안의 `ETS2CarPlay.xcodeproj`를 엽니다.
2. Xcode 왼쪽에서 프로젝트를 선택하고 **TARGETS → ETS2CarPlay → Signing & Capabilities**로 갑니다.
3. **Automatically manage signing**을 켭니다.
4. **Team**에서 본인 Apple 계정을 선택합니다. 계정이 목록에 없으면 **Xcode → Settings → Accounts**에서 Apple 계정으로 로그인합니다.
5. Bundle Identifier에 중복 경고가 나오면 `com.blossom0948.ets2carplay`를 개인 식별 문자열로 바꿉니다. 예: `com.내이름.ets2carplay`처럼 한글 대신 영문·숫자·마침표를 사용합니다.
6. Apple Music 카탈로그를 쓸 계획이면 개발자 계정에서 앱의 App ID에 MusicKit 서비스를 켜야 합니다. 가져온 음악 파일 재생은 이 설정 없이도 사용할 수 있습니다.

## 3A. USB 케이블로 iPad에 설치

1. iPad를 잠금 해제한 뒤 데이터 케이블로 Mac에 연결합니다.
2. iPad에 **이 컴퓨터를 신뢰하겠습니까?**가 나타나면 **신뢰**를 누르고 암호를 입력합니다.
3. Xcode에서 **Xcode → Open Developer Tool → Device Hub**를 엽니다. 또는 실행 기기 메뉴의 **Manage Devices…**를 누릅니다.
4. 왼쪽 목록에서 iPad Air를 선택하고, 안내가 나오면 **Pair**를 누릅니다. 장치가 준비 상태가 될 때까지 기다립니다.
5. iPad에서 **설정 → 개인정보 보호 및 보안 → 개발자 모드**를 켭니다. iPad가 재시동되면 잠금을 풀고 개발자 모드 사용을 확인합니다. 이 메뉴는 처음 페어링을 시작한 뒤에 나타날 수도 있습니다.
6. Xcode 도구 막대에서 실행 대상 `ETS2CarPlay`와 iPad Air를 선택한 다음 **Run ▶**을 누릅니다.
7. 앱이 설치되면 iPad에서 로컬 네트워크, 마이크, 음성 인식, 알림 권한을 요청할 때 필요한 기능에 허용합니다.

앱은 iPad 전체 화면으로 열립니다. 사진처럼 가로형 화면으로 보고 싶으면 **설정 → 디스플레이 → 화면 비율 → CarPlay 와이드(8:3)**를 선택하세요. 왼쪽 도크의 분할 보기 버튼으로 ETS2 대시보드와 YouTube/YouTube Music을 같이 열고, 가운데 손잡이를 움직여 각 화면 너비를 바꿀 수 있습니다. 다른 앱과 나란히 사용하려면 iPadOS 창 정렬 기능을 이용하세요.

미디어 화면에서 **YouTube**를 선택하면 공식 사이트가 앱 화면에 열립니다. **YouTube Music**은 화면의 **앱 안에서 YouTube Music 열기**를 누르세요. 앱을 벗어나지 않고 Apple의 보안 브라우저 시트에서 `music.youtube.com`이 열립니다. Google 계정으로 로그인한 뒤 시트의 **완료**를 누르면 앱과 분할 화면으로 돌아옵니다. Google 로그인 정보는 이 앱이 받거나 저장하지 않습니다.

대시보드 위젯에 **Music 앱**의 현재 곡을 보이게 하려면 미디어 접근 권한을 허용하세요. Apple Music 카탈로그나 앱 안에서 재생하는 파일은 바로 표시됩니다. YouTube Music 등 다른 앱의 곡 정보를 가져오는 기능은 iPadOS가 제공하지 않습니다.

이후에도 케이블을 꽂아 둔 채로 빌드·실행할 수 있습니다. iPadOS 27과 Xcode 27에서는 USB로 한 번 연결한 뒤 같은 Wi-Fi에 연결된 상태로 케이블을 빼고 무선 실행도 할 수 있습니다.

## 3B. Wi-Fi로 케이블 없이 iPad에 설치

이 방법에는 **iPadOS 27 이상과 Xcode 27 이상**이 필요합니다. Apple은 이전 iPadOS 버전에는 케이블 페어링을 안내합니다.

1. Mac과 iPad를 같은 일반 Wi-Fi에 연결합니다. 게스트 Wi-Fi, 기기 간 통신을 막는 공유기, VPN에서는 검색이나 설치가 안 될 수 있습니다.
2. iPad를 잠금 해제하고 가까운 곳에 둡니다.
3. Xcode에서 **Xcode → Open Developer Tool → Device Hub**를 엽니다.
4. Device Hub 왼쪽 위 **+ → Pair Nearby Device…**를 누릅니다.
5. iPad를 선택하고 화면의 지시를 따릅니다. iPad에 표시되는 확인 또는 PIN을 승인하고, **이 컴퓨터를 신뢰**하라는 창이 나타나면 신뢰합니다.
6. Developer Mode를 요청하면 iPad에서 **설정 → 개인정보 보호 및 보안 → 개발자 모드**를 켜고 재시동한 뒤 확인합니다.
7. Device Hub에서 iPad가 준비될 때까지 기다립니다. Xcode 도구 막대에서 `ETS2CarPlay`와 해당 iPad를 선택하고 **Run ▶**을 누릅니다.
8. 설치와 실행이 끝날 때까지 두 기기가 같은 네트워크에 연결되어 있고 iPad가 잠금 해제되어 있는지 확인합니다.

무선 페어링 메뉴가 없거나 iPad가 검색되지 않으면 Xcode와 iPadOS 버전을 확인하세요. 두 기기를 재시동하고 같은 Wi-Fi에 연결한 뒤 다시 시도합니다. 공유기의 게스트 네트워크나 VPN을 끄고, 그래도 연결되지 않으면 USB 방법으로 한 번 페어링합니다. Apple의 [Device Hub 무선 페어링 안내](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)를 참고하세요.

## 4. 준비된 Windows 브리지 받기

1. Windows PC에서 [Windows 설치 묶음 빌드 목록](https://github.com/blossom0948/iPadCarPlay/actions/workflows/build-windows-bundle.yml)을 엽니다. 가장 최근 **Build Windows install bundle** 실행을 선택합니다.
2. 빌드가 끝나면 초록색 체크 표시를 확인하고 실행 결과 페이지 아래쪽의 **Artifacts → ETS2CarPlay-Windows**를 눌러 ZIP을 받습니다. 회색 진행 표시라면 끝날 때까지 기다립니다. 빨간색 X라면 실행 화면에 나온 오류를 확인합니다.
3. ZIP 파일을 마우스 오른쪽 버튼으로 눌러 **모두 압축 풀기**를 선택합니다.
4. ETS2와 실행 중인 브리지 창을 닫고 압축을 푼 폴더의 **`Setup-ETS2CarPlay.bat`**을 두 번 누릅니다. 기본 Steam 위치에서 게임을 찾으면 확인을 누릅니다. 찾지 못하면 폴더 선택 창에서 Steam의 Euro Truck Simulator 2 폴더를 고릅니다. 이 폴더 바로 안에 `bin\win_x64`가 있어야 합니다. 이후 업데이트할 때도 실행 중인 ETS2와 브리지를 먼저 닫습니다.
5. Windows 권한 확인에서 **예**를 누릅니다. 설치가 끝나면 바탕 화면과 시작 메뉴에 브리지 바로 가기가 만들어집니다. Visual Studio, CMake, .NET SDK는 설치하지 않아도 됩니다.
6. 앞으로 ETS2를 할 때는 ETS2를 열기 전에 바탕 화면의 **ETS2 CarPlay 브리지**를 두 번 누릅니다. 검은 창을 게임 중 계속 열어 둡니다. Windows 방화벽이 표시되면 **개인 네트워크**에만 허용합니다.

첫 실행에서만 Windows 브리지 창의 IPv4 주소와 6자리 코드를 입력합니다. 주소가 여러 개면 iPad와 같은 공유기에 연결된 주소를 사용합니다. `127.0.0.1`은 Windows PC 안에서만 쓰는 주소라 iPad에 입력하지 않습니다. 이후 인증 토큰은 iPad와 Windows 사용자 폴더에 저장되어, 브리지 창을 껐다 다시 켜도 같은 iPad가 자동 재연결됩니다.

### Windows PC에 Wi-Fi가 없을 때

가장 쉬운 방법은 **랜선으로 같은 공유기에 연결하는 것**입니다. 집 인터넷이 끊겨 있어도 공유기의 전원과 내부 네트워크가 작동하면 됩니다.

1. 랜선 한쪽을 Windows PC의 네트워크 포트에 꽂고, 다른 쪽을 공유기의 `LAN` 포트에 꽂습니다. `WAN` 또는 `Internet` 포트가 아니라 `LAN`이라고 적힌 포트를 사용합니다.
2. iPad에서는 그 공유기의 일반 Wi-Fi 네트워크에 연결합니다.
3. Windows 브리지를 다시 실행합니다. 창에 표시되는 IP 주소 중 랜선 연결의 주소를 사용합니다. 포트는 `8765`입니다.

PC에 랜선 포트가 없거나 공유기까지 랜선을 연결할 수 없다면 USB Wi-Fi 어댑터를 PC에 꽂아 같은 Wi-Fi에 연결하는 방법이 있습니다. iPad가 **Wi-Fi + Cellular 모델**이고 셀룰러 데이터와 개인용 핫스팟을 쓸 수 있는 경우 iPad USB 핫스팟도 고려할 수 있습니다. Windows에는 Apple Devices 앱 또는 iTunes가 필요합니다. 다만 이 앱의 PC↔iPad 브리지 연결은 USB 핫스팟으로 검증하지 않았으므로, 안정적인 연결 방법은 같은 공유기를 통한 Wi-Fi 또는 랜선 연결입니다. [Apple의 iPad 개인용 핫스팟 안내](https://support.apple.com/en-euro/guide/ipad/ipadb2c87b68/27/ipados/27)

### 직접 빌드하고 싶은 경우 (선택 사항)

소스 코드를 직접 수정해 Windows에서 빌드할 개발자만 [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0), [Visual Studio 2022 Build Tools](https://visualstudio.microsoft.com/downloads/)의 **Desktop development with C++**, [CMake](https://cmake.org/download/)를 설치합니다. 일반 설치에는 이 과정이 필요 없습니다. 저장소를 Windows에 내려받은 후 `WindowsBridge` 폴더에서 다음 스크립트를 사용합니다.

```powershell
.\build-bridge.ps1
.\build-plugin.ps1 -GameRoot "C:\Program Files (x86)\Steam\steamapps\common\Euro Truck Simulator 2"
.\run-bridge.ps1
```

## 5. Windows 브리지 실행과 iPad 연결

1. iPad와 Windows PC를 같은 공유기 네트워크에 연결합니다. 둘 다 Wi-Fi로 연결해도 되고, Windows PC는 공유기에 랜선으로 연결해도 됩니다. 게스트 Wi-Fi는 기기끼리의 연결을 막을 수 있으므로 피합니다.
2. iPad 앱에서 **설정 → ETS2 연결**을 엽니다.
3. **Windows PC 주소** 행을 탭하고 앱 안에 나타나는 숫자판에서 브리지 창의 IPv4 주소를 숫자와 점(`.`)으로 입력한 뒤 **완료**를 누릅니다. iPad 키보드가 뜨지 않아도 이 숫자판으로 입력할 수 있습니다.
4. 포트는 `8765`로 둡니다. **6자리 페어링 코드** 행을 탭하고 Windows 브리지 창의 코드를 숫자판에 입력한 뒤 **완료**를 누릅니다. 그 다음 **연결 또는 페어링**을 누릅니다.
5. iPad에서 로컬 네트워크 권한을 요청하면 허용합니다.
6. ETS2를 열어 저장된 프로필로 운행을 시작합니다. 브리지 창은 운행 중 계속 열어 둡니다.

첫 페어링이 성공하면 앱은 인증 토큰을 iPad Keychain에, 브리지는 Windows의 `%LOCALAPPDATA%\ETS2CarPlay` 폴더에 저장합니다. 이후에는 같은 PC 주소로 다시 연결하며 브리지를 껐다 켜도 코드를 다시 입력하지 않습니다. 페어링을 새로 설정해야 하면 시작 메뉴의 **ETS2 CarPlay → ETS2 CarPlay 페어링 복구**를 실행한 후 iPad 앱에서 새 코드를 입력합니다.

**USB 설치와 네트워크 연결은 별개입니다:** Mac↔iPad USB는 Xcode 설치와 디버깅에 씁니다. ETS2 텔레메트리는 Windows PC와 iPad가 같은 공유기 네트워크에 연결되어야 합니다. Windows PC가 Wi-Fi가 아니라 랜선으로 연결되어도 됩니다. USB 케이블로 Windows PC와 iPad 앱을 직접 연결하는 기능은 없습니다.

## 6. 트럭 원격 조작 키 설정

원격 조작은 Windows 브리지가 ETS2 활성 창에 키 입력을 보내는 기능입니다. 설치된 `%LOCALAPPDATA%\ETS2CarPlay\controls.json`의 기본 키는 모두 `NONE`이므로 사용자가 키를 지정하기 전까지 실제 조작을 보내지 않습니다.

1. ETS2에서 **옵션 → 키 및 버튼**을 열고 경적, 라이트 등 원하는 조작 키를 확인합니다.
2. 메모장으로 `%LOCALAPPDATA%\ETS2CarPlay\controls.json`을 열어 원하는 키를 입력합니다. 예: `"horn": "H"`, `"parkingBrake.toggle": "SPACE"`.
3. 바탕 화면의 ETS2 CarPlay 브리지를 종료한 뒤 다시 실행합니다.

Windows 설치 프로그램은 브리지와 플러그인을 업데이트할 때 기존 `controls.json`을 보존합니다. 게임 키 변경을 직접 설정하지 않는다면 이 단계는 건너뛰세요.

ETS2 창이 활성화되어 있지 않거나 조작 키가 `NONE`이면 명령이 거부됩니다. ETS2와 브리지를 관리자 권한 여부가 서로 다르게 실행하지 마세요.

## 7. 자주 생기는 연결 문제

- **iPad가 Xcode 목록에 없음:** iPad를 잠금 해제하고 같은 Wi-Fi에 연결합니다. USB 설치라면 케이블이 데이터 전송을 지원하는지 확인하고, iPad에서 이 Mac을 신뢰했는지 확인합니다.
- **무선 페어링 항목이 없음:** Xcode 27 이상과 iPadOS 27 이상이 필요합니다. 이전 버전이면 USB로 페어링합니다.
- **앱이 서명되지 않음:** Xcode의 **Signing & Capabilities**에서 본인 Team, 자동 서명, 고유 Bundle Identifier를 확인합니다.
- **PC에 Wi-Fi가 없음:** 랜선으로 PC를 공유기의 `LAN` 단자에 연결하고 iPad는 같은 공유기의 Wi-Fi에 연결합니다. 인터넷은 필요하지 않습니다. PC와 iPad가 같은 공유기에 붙어 있어야 합니다.
- **iPad 숫자 키보드가 표시되지 않음:** 연결 설정에서 주소나 페어링 코드 행을 누르면 앱 자체 숫자판이 열립니다. 그 숫자판으로 입력하면 iPadOS 키보드 없이도 됩니다. 외부 키보드가 연결된 경우 화면 키보드가 자동으로 숨겨질 수도 있습니다.
- **Windows PC에 연결되지 않음:** PC 주소가 올바른지, iPad와 PC가 같은 공유기 네트워크인지, 포트 `8765`가 개인 네트워크 방화벽에서 허용됐는지 확인합니다. 게스트 Wi-Fi, VPN, 공유기 기기 격리가 연결을 막을 수 있습니다.
- **연결되지만 텔레메트리가 없음:** ETS2를 실행해 프로필을 불러오고 실제 운행을 시작합니다. 게임이 실행 중이어도 메뉴 화면에서는 주행 정보가 없을 수 있습니다.
- **브리지 재시작 뒤 인증 실패:** 시작 메뉴의 **ETS2 CarPlay 페어링 복구**를 실행하고, 새 코드로 iPad에서 다시 연결합니다. 이때 다른 브리지 창은 먼저 닫습니다.
- **조작 버튼이 동작하지 않음:** 기본 키 설정은 꺼져 있습니다. `controls.json`에 ETS2 키 배치를 입력하고 브리지를 다시 빌드·실행했는지 확인합니다.

## 구현 및 검증 상태

현재 앱 소스는 **1.5.0 (빌드 13)**이며, Xcode 27.2에서 iPad 시뮬레이터용 빌드가 통과했습니다. 이 Mac의 Xcode 계정/Team 서명이 준비되지 않아 새 버전을 실제 iPad에 설치하지 못했습니다. `Install-iPad.command`를 실행하기 전에 Xcode > Settings > Accounts에서 Apple 계정으로 로그인하고 Signing & Capabilities에서 본인 Team을 선택해야 합니다. 시뮬레이터 GUI가 이 환경에 없어 화면을 시각 검수하지 못했습니다. Windows 설정 묶음의 빌드 성공과 실제 ETS2 연결은 GitHub Actions 및 Windows 게임 PC에서 별도 확인해야 합니다.

실제 지도 도로 경로선은 ETS2의 SCS SDK가 제공하지 않아 표시되지 않습니다. 앱은 게임이 제공하는 목적지, 남은 거리, ETA, 제한 속도 등만 보여줍니다. 전화와 메시지는 iPadOS의 표준 작성·FaceTime 화면을 호출하며, 수신함이나 통화 기록을 앱이 읽지는 않습니다. 앱 안의 업데이트 확인도 새 릴리스 정보를 보여주는 기능입니다. iPadOS 보안상 개발용 앱을 스스로 교체 설치하지 않으며, TestFlight 또는 App Store 자동 업데이트 설정과 별도로 Xcode 개발 빌드는 Xcode에서 다시 설치해야 합니다.

## Apple 안내

- [Xcode 시스템 요구 사항](https://developer.apple.com/xcode/system-requirements/)
- [Xcode 27 릴리스 노트](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
- [Device Hub에서 기기 무선 페어링](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
- [기기에서 Developer Mode 켜기](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- [iPad의 CarPlay 지원 여부](https://support.apple.com/en-us/102521)
