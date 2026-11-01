# ETS2 CarPlay for iPad

iPad에서 실행하는 ETS2 대시보드입니다. iPad Air와 iPadOS 27을 대상으로 구성했으며, 주행 값은 데모가 아니라 Windows에서 실행 중인 ETS2의 SCS Telemetry SDK로부터 받습니다.

## 포함 기능

- ETS2 속도, RPM, 기어, 연료, 제한 속도, 남은 거리와 ETA를 실시간 표시
- 목적지, 배송, 벌금, 통행료 이벤트 수신
- 연료 부족, 제한 속도 초과, 차량 손상 알림
- Windows PC 페어링, 재연결, 상태 확인
- ETS2 창이 활성화된 동안 키 입력을 전달하는 원격 조작
- SwiftData 운행 기록, 누적 거리·연료·속도·게임 이벤트 기록, CSV 내보내기
- 실제 게임 이벤트를 읽어주는 가상 전화 화면과 알림 센터
- 버튼을 눌러 시작하는 한국어 음성 인식 및 음성 안내
- iPad에 가져온 오디오 파일 재생, 백그라운드 재생, 잠금 화면 제어, 음성 중 음량 낮추기
- 공식 YouTube 임베드 플레이어에 동영상 URL 또는 ID 입력
- 앱 배경, 개인 사진, 앱 아이콘 순서와 표시, 화면 모드, 속도 단위, 알림 기준 사용자화
- iPad 설정 앱에서 익숙한 사이드바와 기본 `Form` 구성 요소를 사용하는 설정 화면

기본 화면은 실제 ETS2 데이터가 없으면 연결 상태와 데이터 대기 상태만 보여줍니다. 임의 속도·목적지·경로를 생성하지 않습니다.

설정은 보내주신 Liquid Glass 가이드와 [Apple Human Interface Guidelines의 Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Liquid Glass 적용 안내](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)를 참고했습니다. SwiftUI `NavigationSplitView`, `List`, `Form`처럼 iPadOS 기본 요소를 사용하고, Liquid Glass는 사이드바 같은 탐색 계층에만 두었습니다. 정보 카드와 목록은 콘텐츠 계층으로 유지합니다.

## 구조

```text
ETS2 SCS Telemetry SDK plugin
       │  loopback UDP 127.0.0.1:8766
       ▼
Windows Bridge (.NET WebSocket server, port 8765)
       │  local Wi-Fi WebSocket
       ▼
iPad app (SwiftUI)
```

SCS SDK 1.16 헤더와 MIT 라이선스 전문은 `WindowsBridge/SCS_SDK`에 포함했습니다. 플러그인은 게임에서 공식 텔레메트리 값을 읽고 Windows 브리지에 로컬 UDP로 전달합니다. iPad 연결은 6자리 페어링 코드로 시작하고, 이후 발급된 토큰은 iPad Keychain에 저장합니다.

## Mac에서 iPad 앱 설치

Apple의 현재 Xcode 호환 표에서 Xcode 27은 iPadOS 27 기기를 지원합니다. [Apple Xcode 시스템 요구 사항](https://developer.apple.com/xcode/system-requirements/)을 확인하고, macOS에 맞는 Xcode 27 이상을 설치하세요.

1. GitHub 저장소를 Mac에 복제하거나 내려받습니다.
2. `ETS2CarPlay.xcodeproj`를 Xcode에서 엽니다.
3. Xcode에서 **ETS2CarPlay** 앱 대상을 선택하고 **Signing & Capabilities**에서 **Automatically manage signing**을 켭니다.
4. 본인의 Apple 계정을 Team으로 선택합니다. Bundle Identifier가 이미 사용 중이면 `com.blossom0948.ets2carplay`를 본인만 사용하는 값으로 바꿉니다.
5. iPad Air를 USB로 연결하고 iPad에서 이 Mac을 신뢰합니다. iPadOS의 **설정 → 개인정보 보호 및 보안 → 개발자 모드**를 켜고 재시동합니다.
6. Xcode 상단의 실행 기기에서 iPad Air를 선택하고 **Run**을 누릅니다.
7. 처음 사용하는 기능에서 로컬 네트워크, 마이크, 음성 인식 권한을 허용합니다. 권한을 거부해도 텔레메트리, 음악 파일 재생 등 나머지 기능은 계속 사용할 수 있습니다.

프로젝트의 최소 배포 버전은 iPadOS 17입니다. 사용자의 iPadOS 27.0.1도 대상 범위에 포함됩니다. 이 저장소를 작성한 환경에는 Xcode 앱과 iOS SDK가 설치되어 있지 않아, 실제 기기 서명 및 설치는 아직 실행하지 못했습니다.

## Windows PC와 ETS2 연결

### 필요한 도구

- Windows 10/11 x64
- .NET 8 SDK (브리지 빌드용)
- CMake와 Visual Studio의 **Desktop development with C++** 구성 요소 (SCS 플러그인 빌드용)
- ETS2 1.14 이상. SCS SDK 1.16 기준 ETS2 버전은 현재/이후 마이너 버전과 호환됩니다.

### 브리지와 플러그인 빌드

1. 저장소를 Windows PC에 복제합니다.
2. PowerShell을 열고 저장소의 `WindowsBridge` 폴더로 이동합니다.
3. 다음 명령을 실행해 Windows 브리지를 빌드합니다.

   ```powershell
   .\build-bridge.ps1
   ```

   실행 파일은 `WindowsBridge\dist\BridgeServer\BridgeServer.exe`에 생성됩니다. 이 파일은 .NET 런타임을 포함하므로 실행 PC에 .NET을 따로 설치할 필요가 없습니다.

4. Steam에서 ETS2의 **관리 → 로컬 파일 보기**를 눌러 게임 설치 폴더를 엽니다. 플러그인을 빌드하고 설치할 때 이 폴더를 전달합니다.

   ```powershell
   .\build-plugin.ps1 -GameRoot "C:\Program Files (x86)\Steam\steamapps\common\Euro Truck Simulator 2"
   ```

   경로는 본인의 ETS2 설치 위치로 바꾸세요. 플러그인은 게임 폴더의 `bin\win_x64\plugins`에 복사됩니다. ETS2를 완전히 종료한 상태에서 설치하고, 설치 후 게임을 다시 실행합니다.

5. Windows 브리지를 실행합니다.

   ```powershell
   .\run-bridge.ps1
   ```

   Windows 방화벽이 묻는 경우 **개인 네트워크**에서만 허용합니다. 콘솔에 표시된 PC IPv4 주소와 6자리 페어링 코드를 준비합니다.

### 게임 조작 키 설정

원격 제어는 ETS2 텔레메트리 채널에 쓰지 않고, Windows가 ETS2 활성 창에 키 입력을 보냅니다. 사용자의 ETS2 키 배치가 다를 수 있으므로 `WindowsBridge\BridgeServer\controls.json`은 기본으로 모든 조작을 `NONE`으로 둡니다.

1. ETS2의 **옵션 → 키 및 버튼**에서 각 조작에 배정된 키를 확인합니다.
2. `controls.json`에서 해당 조작 값을 키 이름으로 바꿉니다. 예: `"horn": "H"`, `"parkingBrake.toggle": "SPACE"`.
3. 지원 표기: `A-Z`, `0-9`, `SPACE`, `ENTER`, `ESC`, `TAB`, 방향키 이름, `F1`–`F12`.
4. `build-bridge.ps1`을 다시 실행하고, 생성된 브리지 프로그램을 재시작합니다.

키 설정이 비어 있거나 ETS2 창이 앞에 있지 않으면 브리지는 명령을 거부합니다. 게임이 실제 주행 중일 때만 조작을 보냅니다. 게임 창에 키를 전달할 때 ETS2와 브리지가 서로 다른 권한 수준으로 실행되면 Windows가 입력을 막을 수 있으므로, 둘 다 일반 권한으로 실행하세요.

### iPad 페어링

1. iPad와 Windows PC를 같은 신뢰할 수 있는 Wi-Fi에 연결합니다.
2. 앱에서 **설정 → ETS2 연결**을 엽니다.
3. Windows 콘솔의 PC IPv4 주소와 포트 `8765`, 페어링 코드를 입력하고 연결합니다.
4. ETS2를 실행하고 운행을 시작하면 대시보드의 상태가 실시간 연결로 바뀝니다.

한 번 페어링하면 iPad가 토큰을 Keychain에 저장하므로 다음부터는 PC 주소로 다시 연결할 수 있습니다. Windows 브리지를 재시작하면 새 페어링 코드가 생기고 이전 토큰은 만료됩니다. iPad 설정에서 페어링을 삭제한 뒤 새 코드를 입력하세요.

## 실제 데이터와 기능 범위

- **내비게이션:** SCS SDK가 주는 남은 거리, ETA, 제한 속도와 게임 월드 좌표를 표시합니다. SDK 좌표는 GPS 위도·경도가 아니고 도로 경로선도 제공하지 않으므로 지도 위에 가짜 도로나 회전 안내선을 그리지 않습니다.
- **가상 전화와 메시지:** 휴대전화 통화망, iMessage 또는 SMS에 연결하지 않습니다. 배송·벌금·통행료와 실제 텔레메트리 경보를 앱 안의 알림으로 보여주고, 원하면 음성으로 읽습니다.
- **음악:** 사용자가 파일 앱에서 가져온 오디오 파일을 재생합니다. Apple Music 카탈로그 스트리밍은 Apple Music 권한·구독 설정이 필요해 이 버전에 포함하지 않았습니다.
- **YouTube:** YouTube가 제공하는 임베드 플레이어를 사용합니다. URL 또는 ID를 입력해 재생하며 YouTube 컨트롤과 광고를 유지합니다. 플레이어 화면을 가리거나 오디오를 추출하지 않습니다. [YouTube 공식 임베드 플레이어 지침](https://developers.google.com/youtube/terms/required-minimum-functionality)
- **배경화면:** 앱에 포함된 여섯 가지 원본 색상 디자인과 사용자의 사진을 선택할 수 있습니다. Apple OS에서 제공하는 독점 시스템 배경 이미지 파일은 포함하지 않습니다.
- **CarPlay:** Apple CarPlay 시스템 앱이나 자동차 디스플레이 연결 기능이 아닙니다. iPad 단독 실행용 CarPlay 스타일 인터페이스입니다.

## 개인정보와 네트워크

브리지는 iPad 연결을 인증하지만 이 초기 버전의 WebSocket 연결은 일반 로컬 네트워크(`ws://`)를 사용합니다. 신뢰하는 집 Wi-Fi에서만 실행하고, 라우터에서 포트 `8765`를 인터넷에 공개하지 마세요. 게임 텔레메트리의 UDP 구간은 Windows PC 내부의 loopback에만 열립니다.

## 프로젝트 구성

- `ETS2CarPlay/` — SwiftUI iPad 앱
- `WindowsBridge/BridgeServer/` — .NET 페어링·WebSocket 서버와 키 입력 제어
- `WindowsBridge/TelemetryPlugin/` — SCS SDK 텔레메트리 DLL 소스
- `WindowsBridge/SCS_SDK/` — SCS 공식 SDK 헤더와 MIT 라이선스
