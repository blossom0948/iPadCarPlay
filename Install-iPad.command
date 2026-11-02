#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/ETS2CarPlay.xcodeproj"
SCHEME="ETS2CarPlay"
BUNDLE_ID="com.blossom0948.ets2carplay"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/ETS2CarPlay-OneClick"
BUILD_LOG="${TMPDIR:-/tmp}/ets2carplay-xcodebuild.log"

fail() {
    printf "\n실패: %s\n" "$1"
    if [ -f "$BUILD_LOG" ]; then printf "자세한 Xcode 기록: %s\n" "$BUILD_LOG"; fi
    read -r -p "Enter를 누르면 닫습니다. " _
    exit 1
}

if ! command -v xcodebuild >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1; then
    fail "Xcode가 설치되지 않았거나 첫 실행 설정이 끝나지 않았습니다. Xcode를 한 번 열어 추가 구성 요소 설치를 마친 뒤 다시 실행하세요."
fi
if [ ! -d "$PROJECT" ]; then
    fail "ETS2CarPlay.xcodeproj를 찾지 못했습니다. 저장소 안의 Install-iPad.command를 실행하세요."
fi

DEVICE_OUTPUT="$(xcrun devicectl list devices 2>/dev/null || true)"
DEVICE_IDS=($(printf "%s\n" "$DEVICE_OUTPUT" | awk '/connected/ && /physical/ {print}' | grep -Eo '[0-9A-Fa-f-]{25,36}' || true))
if [ "${#DEVICE_IDS[@]}" -eq 0 ]; then
    fail "연결된 iPad를 찾지 못했습니다. iPad 잠금을 풀고 USB로 Mac에 연결하거나 같은 Wi-Fi에 페어링한 뒤 다시 실행하세요."
fi

if [ "${#DEVICE_IDS[@]}" -eq 1 ]; then
    DEVICE_ID="${DEVICE_IDS[0]}"
else
    printf "연결된 기기를 선택하세요.\n"
    for index in "${!DEVICE_IDS[@]}"; do printf "%d) %s\n" "$((index + 1))" "${DEVICE_IDS[$index]}"; done
    read -r -p "번호: " DEVICE_INDEX
    if ! [[ "$DEVICE_INDEX" =~ ^[0-9]+$ ]] || [ "$DEVICE_INDEX" -lt 1 ] || [ "$DEVICE_INDEX" -gt "${#DEVICE_IDS[@]}" ]; then
        fail "기기 번호가 올바르지 않습니다."
    fi
    DEVICE_ID="${DEVICE_IDS[$((DEVICE_INDEX - 1))]}"
fi

PROFILE_INFO="$(/usr/bin/python3 - "$DEVICE_ID" "$BUNDLE_ID" <<'PY'
import datetime, glob, hashlib, os, plistlib, re, subprocess, sys
device_id, bundle_id = sys.argv[1:]
patterns = [
    os.path.expanduser('~/Library/MobileDevice/Provisioning Profiles/*.mobileprovision'),
    os.path.expanduser('~/Library/Developer/Xcode/UserData/Provisioning Profiles/*.mobileprovision'),
]
try:
    identities = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], stderr=subprocess.DEVNULL, text=True)
    available = set(re.findall(r'\b[0-9A-F]{40}\b', identities))
except Exception:
    available = set()
for pattern in patterns:
    for path in glob.glob(pattern):
        try:
            decoded = subprocess.check_output(['security', 'cms', '-D', '-i', path], stderr=subprocess.DEVNULL)
            profile = plistlib.loads(decoded)
            app_id = profile.get('Entitlements', {}).get('application-identifier', '')
            if not app_id.endswith('.' + bundle_id) or device_id not in profile.get('ProvisionedDevices', []):
                continue
            expiration = profile.get('ExpirationDate')
            if expiration is None or expiration.replace(tzinfo=None) <= datetime.datetime.now():
                continue
            profile_certificates = {hashlib.sha1(certificate).hexdigest().upper() for certificate in profile.get('DeveloperCertificates', [])}
            if not available.intersection(profile_certificates):
                continue
            teams = profile.get('TeamIdentifier', [])
            profile_uuid = profile.get('UUID')
            if teams and profile_uuid:
                print(teams[0] + '|' + profile_uuid)
                raise SystemExit(0)
        except Exception:
            continue
PY
)"
IFS='|' read -r PROFILE_TEAM PROFILE_UUID <<< "$PROFILE_INFO"
IDENTITY_TEAM="$(security find-identity -v -p codesigning 2>/dev/null | sed -nE 's/.*Apple Development:.*\(([A-Z0-9]{10})\).*/\1/p' | head -n 1)"
TEAM_ID="${ETS2_CARPLAY_TEAM_ID:-${PROFILE_TEAM:-$IDENTITY_TEAM}}"
if [ -z "$TEAM_ID" ]; then
    open -a Xcode "$PROJECT"
    fail "Apple 개발 서명 계정을 찾지 못했습니다. Xcode > Settings > Accounts에서 Apple 계정으로 로그인하고 프로젝트의 Signing & Capabilities에서 Team을 한 번 선택한 뒤 다시 실행하세요."
fi

printf "iPad를 빌드하고 설치합니다. 기기 화면 잠금을 풀어 두세요.\n"
printf "Xcode Team: %s\n기기: %s\n\n" "$TEAM_ID" "$DEVICE_ID"
if [ -n "${PROFILE_UUID:-}" ] && [ "$TEAM_ID" = "$PROFILE_TEAM" ]; then
    printf "이 iPad에 맞는 저장된 프로필을 확인했습니다. Xcode 자동 서명으로 빌드합니다.\n"
    PROVISIONING_ARGS=("CODE_SIGN_STYLE=Automatic")
else
    printf "Xcode 자동 서명으로 빌드합니다.\n"
    PROVISIONING_ARGS=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration "CODE_SIGN_STYLE=Automatic")
fi
set +e
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA" \
    "${PROVISIONING_ARGS[@]}" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    build >"$BUILD_LOG" 2>&1
BUILD_RESULT=$?
set -e
if [ "$BUILD_RESULT" -ne 0 ]; then
    tail -n 35 "$BUILD_LOG"
    open -a Xcode "$PROJECT" || true
    if [ -n "${PROFILE_UUID:-}" ] && [ "$TEAM_ID" = "$PROFILE_TEAM" ]; then
        fail "저장된 Xcode 프로필로 서명하지 못했습니다. Xcode > Settings > Accounts에 Apple 계정으로 로그인하고 Team 서명을 새로 고친 뒤 다시 실행하세요."
    else
        fail "Xcode 서명 빌드가 끝나지 않았습니다. Xcode > Settings > Accounts에서 Apple 계정에 로그인하고, 프로젝트의 Signing & Capabilities에서 본인 Team과 Bundle Identifier를 확인한 뒤 다시 실행하세요."
    fi
fi

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/ETS2CarPlay.app"
if [ ! -d "$APP_PATH" ]; then fail "빌드 결과 앱을 찾지 못했습니다."; fi
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" || fail "iPad에 설치하지 못했습니다. iPad 잠금을 풀고 이 Mac을 신뢰했는지 확인하세요."
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" || fail "설치는 됐지만 앱을 시작하지 못했습니다. iPad를 잠금 해제하고 앱을 직접 여세요."
printf "\n설치와 실행이 끝났습니다. 연결 설정은 iPad 앱의 설정 > ETS2 연결에서 진행하세요.\n"
read -r -p "Enter를 누르면 닫습니다. " _ || true
