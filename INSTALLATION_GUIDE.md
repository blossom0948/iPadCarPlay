# 설치와 ETS2 연동 안내

이 안내는 Mac의 Xcode로 iPad Air에 앱을 설치하고, Windows에서 실행하는 ETS2와 연결하는 과정을 처음부터 설명합니다.

## 먼저 알아둘 점

- 이 앱은 **iPad에서 실행하는 CarPlay 스타일 앱**입니다. Apple CarPlay 자체가 아닙니다. Apple은 iPad에서 CarPlay를 지원하지 않으므로 이 앱은 자동차의 기본 CarPlay 화면에 나타나지 않습니다.
- Windows ETS2와 iPad 앱 사이의 텔레메트리는 **같은 Wi-Fi를 통한 로컬 네트워크**로 전달됩니다. Xcode 설치를 USB로 하더라도 주행 중에는 iPad와 Windows PC가 같은 Wi-Fi에 있어야 합니다. 현재 구현에는 USB로 iPad와 Windows 브리지를 직접 연결하는 기능이 없습니다.
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
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Visual Studio 2022 Build Tools](https://visualstudio.microsoft.com/downloads/) 또는 Visual Studio 2022에 **Desktop development with C++** 구성 요소
- [CMake](https://cmake.org/download/)
- Xcode 무선 설치 때는 Mac과 iPad가 같은 Wi-Fi에 있어야 합니다. ETS2 실행 때는 Windows PC와 iPad가 서로 통신할 수 있는 같은 Wi-Fi에 있어야 합니다.

## 1. 프로젝트를 두 컴퓨터에 받기

Mac과 Windows PC 각각에서 GitHub 저장소를 복제합니다. [GitHub Desktop](https://desktop.github.com/)을 쓴다면 **File → Clone repository**를 선택하고 `blossom0948/iPadCarPlay`를 고릅니다. 저장 위치는 찾기 쉬운 폴더로 정합니다.

명령어를 사용하는 경우 다음 주소를 복제합니다.

```text
https://github.com/blossom0948/iPadCarPlay.git
```

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

## 4. Windows 브리지와 ETS2 플러그인 만들기

Windows에서 저장소 폴더를 열고 `WindowsBridge` 폴더 안에서 PowerShell을 엽니다. GitHub Desktop으로 받은 폴더라면 파일 탐색기 주소창에 `WindowsBridge`를 입력해 폴더로 이동할 수 있습니다.

PowerShell에서 브리지를 빌드합니다.

```powershell
cd "C:\Users\내이름\Documents\GitHub\iPadCarPlay\WindowsBridge"
.\build-bridge.ps1
```

PowerShell이 스크립트 실행을 막으면, 같은 PowerShell 창에서 프로세스에 한해 허용한 뒤 빌드 스크립트를 다시 실행합니다.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\build-bridge.ps1
```

Steam에서 ETS2를 선택하고 **관리 → 로컬 파일 보기**를 눌러 실제 게임 폴더 위치를 확인합니다. ETS2를 완전히 종료한 상태에서 다음 명령을 실행합니다. 따옴표 안 경로는 본인의 게임 설치 위치로 바꿉니다.

```powershell
.\build-plugin.ps1 -GameRoot "C:\Program Files (x86)\Steam\steamapps\common\Euro Truck Simulator 2"
```

빌드된 플러그인은 게임 폴더의 `bin\win_x64\plugins\ets2carplay_telemetry.dll`에 복사됩니다. 스크립트가 Visual Studio C++ 또는 CMake를 찾지 못하면 준비물 절을 확인하고 필요한 구성 요소를 설치한 뒤 다시 실행합니다.

## 5. Windows 브리지 실행과 iPad 연결

1. PowerShell에서 Windows 브리지를 실행합니다.

   ```powershell
   .\run-bridge.ps1
   ```

2. Windows 방화벽 안내가 나타나면 **개인 네트워크**에서만 허용합니다. 공용 네트워크에서는 허용하지 않습니다.
3. 콘솔에서 **PC 주소**로 표시된 Wi-Fi의 IPv4 주소와 **iPad 페어링 코드** 6자리를 확인합니다. 주소가 여러 개면 iPad와 같은 Wi-Fi 네트워크의 주소를 고릅니다. `127.0.0.1`은 PC 내부 주소이므로 iPad에 입력하지 않습니다.
4. iPad 앱에서 **설정 → ETS2 연결**을 엽니다.
5. Windows의 IPv4 주소, 포트 `8765`, 6자리 코드를 입력하고 **연결 또는 페어링**을 누릅니다.
6. iPad에 로컬 네트워크 권한 요청이 나오면 허용합니다.
7. ETS2를 실행하고 저장된 프로필로 운행을 시작합니다. 연결 상태가 바뀌면 실제 텔레메트리가 표시됩니다.
8. 운행 중에는 Windows 브리지 콘솔 창을 닫지 않습니다.

첫 페어링이 성공하면 앱은 토큰을 iPad Keychain에 저장합니다. 이후에는 앱이 같은 PC 주소로 다시 연결하므로 매번 코드를 입력하지 않습니다. 브리지를 다시 시작하면 기존 인증 세션이 초기화되고 새 코드가 발급됩니다. 이때 앱의 **설정 → ETS2 연결 → 페어링 삭제**를 누른 뒤 새 코드로 다시 페어링합니다.

**USB 설치와 Wi-Fi 설치의 차이:** USB는 Mac에서 iPad로 앱을 설치하고 디버깅하는 연결입니다. ETS2 데이터 전송은 두 설치 방식 모두 Windows PC와 iPad 사이의 Wi-Fi를 사용합니다. 이 앱은 USB 케이블로 Windows PC에 직접 연결해 텔레메트리를 받지 않습니다.

## 6. 트럭 원격 조작 키 설정

원격 조작은 Windows 브리지가 ETS2 활성 창에 키 입력을 보내는 기능입니다. 기본 `WindowsBridge\BridgeServer\controls.json`의 모든 항목은 `NONE`이므로 사용자가 키를 지정하기 전까지 실제 조작을 보내지 않습니다.

1. ETS2에서 **옵션 → 키 및 버튼**을 열고 경적, 라이트 등 원하는 조작 키를 확인합니다.
2. `controls.json`에서 해당 값을 키 이름으로 변경합니다. 예: `"horn": "H"`, `"parkingBrake.toggle": "SPACE"`.
3. PowerShell에서 `build-bridge.ps1`을 다시 실행합니다.
4. 실행 중인 브리지를 `Ctrl+C`로 종료한 뒤 `run-bridge.ps1`로 다시 시작합니다.

ETS2 창이 활성화되어 있지 않거나 조작 키가 `NONE`이면 명령이 거부됩니다. ETS2와 브리지를 관리자 권한 여부가 서로 다르게 실행하지 마세요.

## 7. 자주 생기는 연결 문제

- **iPad가 Xcode 목록에 없음:** iPad를 잠금 해제하고 같은 Wi-Fi에 연결합니다. USB 설치라면 케이블이 데이터 전송을 지원하는지 확인하고, iPad에서 이 Mac을 신뢰했는지 확인합니다.
- **무선 페어링 항목이 없음:** Xcode 27 이상과 iPadOS 27 이상이 필요합니다. 이전 버전이면 USB로 페어링합니다.
- **앱이 서명되지 않음:** Xcode의 **Signing & Capabilities**에서 본인 Team, 자동 서명, 고유 Bundle Identifier를 확인합니다.
- **Windows PC에 연결되지 않음:** PC 주소가 올바른지, iPad와 PC가 같은 Wi-Fi인지, 포트 `8765`가 개인 네트워크 방화벽에서 허용됐는지 확인합니다. 게스트 Wi-Fi, VPN, 공유기 기기 격리가 연결을 막을 수 있습니다.
- **연결되지만 텔레메트리가 없음:** ETS2를 실행해 프로필을 불러오고 실제 운행을 시작합니다. 게임이 실행 중이어도 메뉴 화면에서는 주행 정보가 없을 수 있습니다.
- **브리지 재시작 뒤 인증 실패:** iPad 앱에서 기존 페어링을 삭제하고 콘솔에 새로 표시된 코드를 입력합니다.
- **조작 버튼이 동작하지 않음:** 기본 키 설정은 꺼져 있습니다. `controls.json`에 ETS2 키 배치를 입력하고 브리지를 다시 빌드·실행했는지 확인합니다.

## 구현 및 검증 상태

앱과 Windows 브리지의 소스는 저장소에 있지만, 이 개발 환경에는 Xcode 앱과 iOS SDK가 없어 iPad Air에서 실제 빌드·서명·설치를 확인하지 못했습니다. 또한 Windows 브리지와 ETS2 플러그인도 Windows 게임 환경에서 실행 확인이 필요합니다. 따라서 위 단계는 구성된 프로젝트를 설치하기 위한 안내이며, 현재 저장소를 “모든 기능이 기기에서 완전히 검증된 앱”이라고 부를 수는 없습니다.

실제 지도 도로 경로선은 ETS2의 SCS SDK가 제공하지 않아 표시되지 않습니다. 앱은 게임이 제공하는 목적지, 남은 거리, ETA, 제한 속도 등만 보여줍니다. 전화와 메시지는 iPadOS의 표준 작성·FaceTime 화면을 호출하며, 수신함이나 통화 기록을 앱이 읽지는 않습니다. 앱 안의 업데이트 확인도 새 릴리스 정보를 보여주는 기능입니다. iPadOS 보안상 개발용 앱을 스스로 교체 설치하지 않으며, TestFlight 또는 App Store 자동 업데이트 설정과 별도로 Xcode 개발 빌드는 Xcode에서 다시 설치해야 합니다.

## Apple 안내

- [Xcode 시스템 요구 사항](https://developer.apple.com/xcode/system-requirements/)
- [Xcode 27 릴리스 노트](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
- [Device Hub에서 기기 무선 페어링](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
- [기기에서 Developer Mode 켜기](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- [iPad의 CarPlay 지원 여부](https://support.apple.com/en-us/102521)
