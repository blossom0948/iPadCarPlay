# ETS2 CarPlay for iPad

iPad에서 실행하는 ETS2 대시보드입니다. iPad Air와 iPadOS 27을 대상으로 구성했으며, 연결하면 Windows에서 실행 중인 ETS2의 SCS Telemetry SDK로부터 주행 값을 받습니다. Apple CarPlay 자체가 아니라 iPad용 CarPlay 스타일 앱입니다.

처음 설치하는 순서와 USB·Wi-Fi 연결 방법은 [초보자 설치·연동 안내](INSTALLATION_GUIDE.md)를 참고하세요.
실제 iPad CarPlay 수신기와 Apple CarPlay Simulator를 조사한 내용은 [CarPlay 참고 조사](docs/CARPLAY_REFERENCE.md)에 정리했습니다.

## 포함 기능

- ETS2 속도, RPM, 기어, 연료, 제한 속도, 남은 거리와 ETA를 실시간 표시
- 현재 연료 주행거리와 목적지 거리를 비교해 도착 가능 여부와 주유 시점을 표시
- ETS2 게임 시간 기준 다음 휴식과 배송 마감 카운트다운·조기 경보
- 목적지, 배송, 벌금, 통행료 이벤트 수신
- 연료 부족, 경로 연료 부족, 휴식·배송 마감, 제한 속도 초과, 차량 손상 알림
- Windows PC 페어링, 재연결, 상태 확인
- ETS2 창이 활성화된 동안 키 입력을 전달하는 원격 조작
- SwiftData 운행 기록, 누적 거리·연료·속도·게임 이벤트 기록, CSV 내보내기
- 실제 게임 이벤트를 읽어주는 가상 전화 화면과 알림 센터
- 연료·과속·손상·게임 이벤트의 앱 내 알림과 선택 가능한 iPad 배너/잠금 화면 알림
- iPad가 지원하면 앱 안의 메시지 작성 화면과 FaceTime 오디오 발신
- 버튼을 눌러 시작하는 한국어 음성 인식 및 음성 안내
- Apple Music 카탈로그 검색·재생과 iPad에 가져온 오디오 파일 재생, Apple Music 앱의 현재 곡 표시, 잠금 화면 제어
- 앱 실행 시 GitHub 공개 릴리스에서 새 버전과 변경 내용을 자동 확인
- 앱 안에서 YouTube와 YouTube Music 공식 웹 화면 열기
- 대시보드와 YouTube/YouTube Music을 한 화면에 두는 크기 조절 분할 보기
- 4×2 홈 화면에 한 페이지 최대 8개 아이콘, 최근·즐겨찾기 분할 조합, 한 번 탭으로 홈 이동
- 앱 배경, 개인 사진, 앱 아이콘 순서와 표시, 화면 모드, 속도 단위, 알림 기준 사용자화
- Apple SF Symbols를 사용한 화면 아이콘, ETS2 CarPlay 전용 앱 로고와 앱 아이콘
- CarPlay 화면 비율을 고려한 자체 배경 테마, 사진 보관함 배경 추가
- iPad 전체 화면 기본 배치와 참고 사진의 CarPlay 8:3 와이드 화면 선택
- iPad 화면 회전, 창 크기 조절, iPadOS 멀티태스킹에 맞춘 레이아웃
- CarPlay 스타일 설정 카테고리, 배경화면 선택, 사용자 사진 추가

앱은 가로와 세로 iPad 화면을 모두 채우며, 기본 비율은 iPad 전체 화면입니다. 홈 화면은 화면 가장자리까지 이어지고 한 페이지에 앱 아이콘 8개를 4×2로 표시합니다. 아이콘 크기는 **설정 → 디스플레이**에서 슬라이더로 조절할 수 있습니다. 설정, 대시보드 등 앱 안의 창과 글에는 별도 간격을 둡니다. 최근 또는 즐겨찾기 분할 조합을 홈 아래에서 다시 열 수 있고, 왼쪽 도크의 홈 버튼은 분할 화면에서도 한 번 눌러 홈으로 돌아갑니다. 앱 화면 아이콘은 Apple SF Symbols 시스템 심볼을 사용하며, Apple 앱의 상표 아이콘을 복제하지 않습니다. 설정에서 CarPlay 8:3 와이드 화면 비율을 선택할 수 있습니다. 왼쪽 도크의 분할 보기 버튼을 누르면 대시보드와 YouTube 또는 YouTube Music을 나란히 표시하고 가운데 손잡이를 끌어 너비를 조절합니다. 화면 재질과 전환은 보내주신 Liquid Glass 안내와 iPad의 동작 줄이기 설정을 참고합니다. 배경화면 메뉴에는 CarPlay용 자체 테마와 사진 보관함 선택이 있습니다. 실제 차량에 내장된 공식 CarPlay 배경은 차량의 CarPlay 설정에서 고르는 항목이며, 이 앱에서 불러올 수 있는 이미지 파일이나 공개 API는 Apple이 제공하지 않습니다. 운행 화면은 실제 ETS2 데이터가 없으면 연결 및 대기 상태만 보여주며, 임의 속도·목적지·경로를 만들지 않습니다. 와이드 선택은 [Apple CarPlay 디자인 가이드](https://developer.apple.com/design/human-interface-guidelines/carplay)의 화면 비율을 참고합니다.

설정 첫 화면은 CarPlay식 큰 터치 메뉴이며, 배경화면 선택은 별도 화면으로 열립니다. 연결 정보는 앱 안의 숫자판으로 입력할 수 있어 iPadOS 키보드가 표시되지 않는 상황에서도 페어링할 수 있습니다. 화면 재질과 전환은 보내주신 Liquid Glass 가이드와 [Apple Human Interface Guidelines의 Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Liquid Glass 적용 안내](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)를 참고했습니다.

## 구조

```text
ETS2 SCS Telemetry SDK plugin
       │  loopback UDP 127.0.0.1:8766
       ▼
Windows Bridge (.NET WebSocket server, port 8765)
       │  local-network WebSocket (Wi-Fi or Ethernet)
       ▼
iPad app (SwiftUI)
```

SCS SDK 1.16 헤더와 MIT 라이선스 전문은 `WindowsBridge/SCS_SDK`에 포함했습니다. 플러그인은 게임에서 공식 텔레메트리 값을 읽고 Windows 브리지에 로컬 UDP로 전달합니다. iPad 첫 연결은 6자리 코드로 페어링합니다. 이후 토큰은 iPad Keychain과 Windows의 사용자 앱 데이터 폴더에 저장되어 브리지를 껐다 켜도 자동으로 재연결됩니다.

## Mac에서 iPad 앱 설치

- **USB:** 케이블로 iPad를 연결하고 Xcode Device Hub에서 신뢰·페어링한 뒤 실행합니다. 처음 페어링이 끝난 뒤에는 케이블을 빼고 Wi-Fi로 실행할 수도 있습니다.
- **Wi-Fi:** iPadOS 27과 Xcode 27은 같은 Wi-Fi에 있는 iPad를 케이블 없이 Device Hub에서 페어링할 수 있습니다.

두 방법의 단계별 안내, Apple 계정 서명, Developer Mode, Windows 브리지 설치는 [초보자 설치·연동 안내](INSTALLATION_GUIDE.md)에 정리했습니다. 프로젝트의 최소 배포 버전은 iPadOS 17입니다. Apple은 Xcode 27에서 iPadOS 27 이상 기기의 무선 페어링을 지원합니다. [Xcode 27 릴리스 노트](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes) · [Device Hub 페어링 안내](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)

Mac에 저장소를 받은 뒤에는 `Install-iPad.command`를 두 번 눌러 빌드와 연결된 iPad 설치를 한 번에 할 수 있습니다. 스크립트는 연결된 기기와 Mac에 저장된 유효한 서명 프로필을 찾아 자동으로 사용합니다. 맞는 프로필이 없다면 Xcode에서 Apple 계정에 로그인하고 Team 서명을 한 번 설정해야 합니다. 설치할 때 iPad는 잠금 해제해 둡니다. iPad 단독으로 임의의 개발용 앱을 설치할 수는 없으며 Apple의 코드 서명 절차가 필요합니다.

### 이번 화면 개편 빌드 확인

Xcode 27.2의 iPad 시뮬레이터 빌드가 통과했고, 실제 **iPad Air (4세대, iPadOS 27.0.1)**에 **1.5.0 (빌드 13)**을 설치하고 실행했습니다. Device Hub에서 버전을 확인하고 실제 홈 화면도 캡처해 확인했습니다. 이 버전에는 목적지 전 연료 판단, 게임 시간 기준 휴식·배송 마감 정보, 애니메이션 상태 피드백과 Mac 원클릭 설치 명령이 포함됩니다. Xcode는 App Intents 메타데이터 생성을 건너뛰었다는 비치명 경고를 남겼습니다(앱은 App Intents를 사용하지 않습니다). ETS2 실시간 운행 연동은 Windows 게임 PC에서 확인해야 합니다. Windows 설치 묶음은 GitHub Actions 빌드에서 생성됩니다.

## 앱 업데이트

앱은 실행할 때 GitHub Releases API를 직접 확인하고, 새 버전 번호와 변경 내용을 **설정 → 일반 → 소프트웨어 업데이트**에 표시합니다. 브라우저나 웹 페이지를 열지 않습니다. 공개 릴리스가 아직 없으면 앱에서 그렇게 표시합니다.

iPadOS는 실행 중인 앱이 자기 앱을 교체 설치하는 것을 허용하지 않습니다. 현재처럼 Xcode로 설치한 개발 빌드는 새 코드를 받을 때 Xcode에서 다시 실행해야 합니다. 이 반복을 없애려면 App Store나 TestFlight로 배포해야 합니다. App Store 앱은 기본적으로 자동 업데이트되며, 설정은 **설정 → 앱 → App Store → 앱 업데이트**에서 확인할 수 있습니다. TestFlight는 앱 상세 화면의 **App Information → Automatic Updates**를 켜면 새 베타 빌드를 자동 설치합니다. 정식 이용을 위해서는 App Store 배포가 필요합니다. 두 방식 모두 Apple Developer Program 가입과 App Store Connect 등록이 필요하며, 정식 배포는 심사도 통과해야 합니다. 이 계정과 등록은 아직 설정되지 않았습니다. [Apple의 배포 방법](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases) · [iPad 자동 업데이트 설정](https://support.apple.com/en-us/102629) · [TestFlight 자동 업데이트](https://testflight.apple.com/)

## Windows PC와 ETS2 연결

### Windows PC에 Wi-Fi가 없어도 연결할 수 있습니다

이 앱의 ETS2 연결은 인터넷을 거치지 않고 **같은 공유기 안의 로컬 네트워크**에서 동작합니다. 따라서 Windows PC에 Wi-Fi가 없어도 괜찮습니다.

1. 랜선 한쪽을 PC의 네트워크 단자에, 다른 쪽을 공유기의 `LAN`이라고 표시된 단자에 꽂습니다. 공유기 `WAN`/`Internet` 단자에는 꽂지 않습니다.
2. iPad를 같은 공유기의 일반 Wi-Fi에 연결합니다. PC는 랜선, iPad는 Wi-Fi여도 같은 공유기를 쓰면 통신할 수 있습니다.
3. 인터넷 연결은 필요하지 않습니다. 공유기 전원과 PC↔iPad의 같은 내부 네트워크 연결이 필요합니다.

PC에 랜선 단자가 없으면 USB Wi-Fi 어댑터를 사용해 같은 Wi-Fi에 연결하는 방법이 가장 간단합니다. Wi-Fi + Cellular iPad의 USB 개인용 핫스팟도 가능할 수 있지만, Windows에는 Apple Devices 앱 또는 iTunes가 필요하고 이 앱의 브리지 통신은 그 방식으로 검증하지 않았습니다. [Apple의 iPad 핫스팟 안내](https://support.apple.com/en-euro/guide/ipad/ipadb2c87b68/27/ipados/27)

### 가장 간단한 방법: 준비된 Windows 묶음 내려받기

- Windows 10/11 x64
- ETS2 1.14 이상. SCS SDK 1.16 기준 ETS2 버전은 현재/이후 마이너 버전과 호환됩니다.
- 같은 공유기 네트워크에 연결된 iPad와 Windows PC (Windows는 Wi-Fi 또는 랜선 연결)

Visual Studio C++ 구성 요소, CMake, .NET SDK를 Windows에 설치할 필요가 없습니다. GitHub가 Windows 가상 컴퓨터에서 브리지와 ETS2 플러그인을 미리 빌드합니다.

Windows PC에서 인터넷을 쓸 수 없다면 Mac이나 인터넷이 되는 다른 기기에서 아래 Windows ZIP을 내려받아 USB 메모리로 옮기면 됩니다. PC에서는 압축을 풀고 설치만 하면 됩니다. ETS2를 실행할 때의 연결은 인터넷을 쓰지 않습니다. Windows PC를 공유기에 랜선으로 연결하고 iPad를 같은 공유기의 Wi-Fi에 연결하면 됩니다.

1. [저장소의 Actions 빌드 목록](https://github.com/blossom0948/iPadCarPlay/actions/workflows/build-windows-bundle.yml)을 엽니다.
2. 가장 최근의 **Build Windows install bundle** 실행을 누르고, 완료 표시(초록색 체크)가 있는지 확인합니다.
3. 해당 실행 화면 아래 **Artifacts**에서 `ETS2CarPlay-Windows`를 내려받아 압축을 풉니다. 압축 안의 `README-FIRST.txt`도 참고할 수 있습니다.
4. ETS2와 실행 중인 브리지 창을 닫고 `Setup-ETS2CarPlay.bat`을 두 번 누릅니다. 기본 Steam 위치에서 ETS2를 찾으면 확인만 누르고, 다른 폴더에 설치했다면 게임 폴더를 선택합니다. Windows 권한 확인에서 **예**를 누릅니다. 설치가 끝나면 바탕 화면에 **ETS2 CarPlay 브리지** 바로 가기가 생깁니다. 업데이트할 때도 먼저 ETS2와 브리지 창을 닫습니다.
5. 매번 ETS2를 할 때 바탕 화면의 **ETS2 CarPlay 브리지**를 두 번 누르고 검은 창을 열어 둡니다. Windows 방화벽이 묻는 경우 **개인 네트워크에서만 허용**합니다. 첫 실행에만 표시되는 코드를 iPad에 입력하면 이후 브리지 재시작은 자동 재연결됩니다.
6. iPad와 Windows PC가 같은 공유기 네트워크에 있는지 확인합니다. 앱에서 **설정 → ETS2 연결**을 열고 **Windows PC 주소** 행을 눌러 앱 안 숫자판에 브리지 창의 IPv4 주소를 입력합니다. 포트는 `8765` 그대로 둡니다. **6자리 페어링 코드** 행을 눌러 코드를 입력하고 **연결 또는 페어링**을 누릅니다. iPad 키보드가 표시되지 않아도 앱 안 숫자판으로 입력할 수 있습니다. `127.0.0.1`은 입력하지 않습니다.
7. ETS2를 실행하고 저장된 프로필을 불러와 운행을 시작합니다. 브리지 창은 운행 중 계속 열어 둡니다.

연결을 처음부터 다시 설정해야 하면 Windows 시작 메뉴의 **ETS2 CarPlay 페어링 복구**를 실행하고, 새 코드로 iPad에서 다시 연결하세요. PC와 iPad는 같은 공유기 네트워크에 있어야 합니다. Windows가 인터넷에 연결되지 않아도 PC를 공유기에 랜선으로 연결하면 됩니다.

### 직접 빌드하는 방법 (선택 사항)

개발자가 Windows PC에서 소스 코드를 직접 빌드하려는 경우에만 .NET 8 SDK, CMake, Visual Studio 2022의 **Desktop development with C++**를 설치합니다. `WindowsBridge\build-bridge.ps1`, `WindowsBridge\build-plugin.ps1`, `WindowsBridge\run-bridge.ps1`을 사용합니다. 이 방법은 일반 연결에 필요하지 않습니다.


### 게임 조작 키 설정

원격 제어는 ETS2 텔레메트리 채널에 쓰지 않고, Windows가 ETS2 활성 창에 키 입력을 보냅니다. 기본 키 배치는 모든 조작을 `NONE`으로 둡니다.

1. ETS2의 **옵션 → 키 및 버튼**에서 각 조작에 배정된 키를 확인합니다.
2. Windows에서 `%LOCALAPPDATA%\ETS2CarPlay\controls.json`을 메모장으로 열고 원하는 키로 바꿉니다. 예: `"horn": "H"`, `"parkingBrake.toggle": "SPACE"`.
3. 지원 표기: `A-Z`, `0-9`, `SPACE`, `ENTER`, `ESC`, `TAB`, 방향키 이름, `F1`–`F12`.
4. 바탕 화면의 ETS2 CarPlay 브리지 창을 닫고 다시 시작합니다.

키 설정이 비어 있거나 ETS2 창이 앞에 있지 않으면 브리지는 명령을 거부합니다. 게임이 실제 주행 중일 때만 조작을 보냅니다. 게임 창에 키를 전달할 때 ETS2와 브리지가 서로 다른 권한 수준으로 실행되면 Windows가 입력을 막을 수 있으므로, 둘 다 일반 권한으로 실행하세요.

### iPad 페어링

1. iPad와 Windows PC를 같은 신뢰할 수 있는 공유기 네트워크에 연결합니다. Windows PC는 랜선으로 공유기에 연결해도 됩니다.
2. 앱에서 **설정 → ETS2 연결**을 엽니다.
3. Windows PC 주소와 6자리 페어링 코드 행을 각각 눌러 앱 안 숫자판으로 입력하고 연결합니다. 포트는 `8765`입니다.
4. ETS2를 실행하고 운행을 시작하면 대시보드의 상태가 실시간 연결로 바뀝니다.

한 번 페어링하면 iPad가 토큰을 Keychain에, Windows 브리지가 인증 토큰을 사용자 앱 데이터 폴더에 저장하므로 브리지를 재시작하거나 업데이트해도 자동으로 다시 연결됩니다. 인증을 새로 설정해야 하는 경우에만 Windows 시작 메뉴의 **ETS2 CarPlay 페어링 복구**를 실행하고 iPad에서 새 코드를 입력하세요.

## 실제 데이터와 기능 범위

- **내비게이션:** SCS SDK가 주는 남은 거리, ETA, 제한 속도와 게임 월드 좌표를 표시합니다. SDK 좌표는 GPS 위도·경도가 아니고 도로 경로선도 제공하지 않으므로 지도 위에 가짜 도로나 회전 안내선을 그리지 않습니다.
- **전화와 메시지:** FaceTime 오디오 발신은 iPad의 FaceTime 앱을 사용합니다. 문자는 iPadOS의 표준 작성 화면에서 수신자와 내용을 확인한 뒤 전송합니다. 수신 메시지함이나 통화 기록을 읽지 않습니다. 배송·벌금·통행료와 텔레메트리 경보는 앱 안의 알림 센터에 쌓이며, 알림 권한을 허용하면 iPad 배너와 잠금 화면에도 표시됩니다. [FaceTime iPad 안내](https://support.apple.com/guide/ipad/make-facetime-calls-ipad6b71e29e/27/ipados) · [Message UI 문서](https://developer.apple.com/documentation/messageui)
- **음악:** Apple Music 탭은 MusicKit으로 카탈로그를 검색·재생하고, 가져온 파일 탭은 로컬 오디오를 재생합니다. 디스플레이 위젯은 권한을 허용하면 Apple Music 앱의 현재 곡도 표시합니다. YouTube와 다른 앱의 재생 정보를 읽는 공개 iPadOS API는 제공되지 않으므로, 그 앱들의 곡명·앨범 표지는 가져올 수 없습니다. Apple Music 카탈로그 재생은 활성 구독을 요구합니다. [Apple MusicKit 문서](https://developer.apple.com/documentation/musickit) · [Apple 시스템 음악 플레이어](https://developer.apple.com/documentation/mediaplayer/mpmusicplayercontroller/systemmusicplayer) · [Now Playing 정보 API](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)
- **YouTube / YouTube Music:** YouTube는 앱 안의 `WKWebView`에서 공식 사이트로 열립니다. YouTube Music은 Google 로그인 보안을 지키기 위해 Apple의 `SFSafariViewController`를 앱 안의 시트로 엽니다. YouTube Music 화면을 닫으면 앱과 이전 분할 보기로 돌아갑니다. 로그인 정보는 이 앱이 받거나 저장하지 않습니다. [Google OAuth 정책](https://developers.google.com/identity/protocols/oauth2/policies) · [YouTube Music 지원 브라우저](https://support.google.com/youtubemusic/answer/6313540?hl=en) · [Apple SFSafariViewController](https://developer.apple.com/documentation/safariservices/sfsafariviewcontroller)
- **배경화면:** 앱의 기본 선택지는 Apple 정식 배경이 아닌 CarPlay 스타일의 자체 테마입니다. Apple 안내는 연결된 차량의 CarPlay 설정에서 배경을 선택하도록 설명하며, iPad 앱이 해당 시스템 배경을 가져오는 공개 API는 없습니다. 사용자가 직접 사진을 추가할 수 있습니다. [CarPlay 설정과 배경화면](https://support.apple.com/en-ca/guide/iphone/-iph6ade13329/ios)
- **CarPlay:** Apple CarPlay 시스템 앱이나 자동차 디스플레이 연결 기능이 아닙니다. iPad 단독 실행용 CarPlay 스타일 인터페이스입니다.

Apple은 iPad에서 CarPlay를 지원하지 않으며, 실제 차량 화면의 앱 UI는 CarPlay 프레임워크의 시스템 템플릿으로 표시됩니다. 이 프로젝트는 iPad에서 비슷한 탐색 구조와 시각 스타일을 구현하는 SwiftUI 앱입니다. 따라서 자동차의 CarPlay 화면에 나타나지는 않습니다. [Apple 지원: iPad와 CarPlay](https://support.apple.com/en-us/102521) · [Apple CarPlay 디자인 가이드](https://developer.apple.com/design/human-interface-guidelines/carplay)

## 개인정보와 네트워크

브리지는 iPad 연결을 인증하지만 이 초기 버전의 WebSocket 연결은 일반 로컬 네트워크(`ws://`)를 사용합니다. 신뢰하는 집 Wi-Fi에서만 실행하고, 라우터에서 포트 `8765`를 인터넷에 공개하지 마세요. 게임 텔레메트리의 UDP 구간은 Windows PC 내부의 loopback에만 열립니다.

## 프로젝트 구성

- `ETS2CarPlay/` — SwiftUI iPad 앱
- `WindowsBridge/BridgeServer/` — .NET 페어링·WebSocket 서버와 키 입력 제어
- `WindowsBridge/TelemetryPlugin/` — SCS SDK 텔레메트리 DLL 소스
- `WindowsBridge/SCS_SDK/` — SCS 공식 SDK 헤더와 MIT 라이선스
