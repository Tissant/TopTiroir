#!/bin/zsh
# TopTiroir 설치: 테스트 → Release 빌드 → 예전 앱은 휴지통 → 응용 프로그램 폴더에 설치 → 실행
# 사용(Mac 터미널, TopTiroir 폴더에서):  ./Tools/install.sh
#   --skip-tests   테스트 건너뛰기
#   --keep-build   설치 뒤 build 폴더를 휴지통으로 옮기지 않기
# 파일은 지우지 않는다. 옮길 때는 모두 휴지통(/usr/bin/trash)으로.
set -euo pipefail

# ── 설정(경로는 여기 한 곳에만) ─────────────────────────────
APP_NAME="TopTiroir"
BUNDLE_ID="local.toptiroir.app"
INSTALL_DIR="/Applications"
# Xcode 위치: 환경 변수 DEVELOPER_DIR가 있으면 그대로, 없으면 아래 → 그것도 없으면 xcode-select 기본값
XCODE_APP_DEFAULT="/Applications/Dev_Tool/Xcode.app"
# ─────────────────────────────────────────────────────────

SKIP_TESTS=0
KEEP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-tests) SKIP_TESTS=1 ;;
    --keep-build) KEEP_BUILD=1 ;;
    *) echo "모르는 옵션: $arg"; exit 2 ;;
  esac
done

cd "${0:A:h}/.."   # 스크립트가 있는 폴더의 위(프로젝트 폴더)
PROJECT_DIR="$PWD"
BUILD_DIR="$PROJECT_DIR/build"
BUILT_APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"

if [[ -z "${DEVELOPER_DIR:-}" && -d "$XCODE_APP_DEFAULT" ]]; then
  export DEVELOPER_DIR="$XCODE_APP_DEFAULT/Contents/Developer"
fi

step() { printf "\n\033[38;5;208m▶ %s\033[0m\n" "$1"; }

if ! command -v trash >/dev/null; then
  echo "휴지통 명령(/usr/bin/trash)을 찾지 못했어요. macOS 15 이상이 필요해요."; exit 1
fi

step "1/6 프로젝트 파일 만들기 (xcodegen)"
if command -v xcodegen >/dev/null; then
  xcodegen generate --quiet
else
  echo "xcodegen이 없어 기존 TopTiroir.xcodeproj를 그대로 씁니다."
fi

if (( SKIP_TESTS == 0 )); then
  step "2/6 테스트"
  xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -derivedDataPath "$BUILD_DIR" -destination "platform=macOS,arch=arm64" -quiet test
else
  step "2/6 테스트 건너뜀(--skip-tests)"
fi

step "3/6 Release 빌드"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -derivedDataPath "$BUILD_DIR" -destination "generic/platform=macOS" -quiet build
codesign --verify --deep --strict "$BUILT_APP"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$BUILT_APP/Contents/Info.plist")
BUILD_NO=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$BUILT_APP/Contents/Info.plist")
echo "빌드 완료: 버전 $VERSION (빌드 $BUILD_NO), 크기 $(du -sh "$BUILT_APP" | cut -f1)"

step "4/6 실행 중인 $APP_NAME 끄기"
if pgrep -x "$APP_NAME" >/dev/null; then
  # 정상 종료 요청(저장할 메모가 있으면 앱이 저장하고 끝남)
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  for _ in {1..20}; do
    pgrep -x "$APP_NAME" >/dev/null || break
    sleep 0.5
  done
  if pgrep -x "$APP_NAME" >/dev/null; then
    echo "10초 안에 꺼지지 않았어요. 서랍에 「저장할까요?」 확인 줄이 떠 있는지 보고, 답한 뒤 다시 실행해 주세요."
    exit 1
  fi
  echo "껐어요."
else
  echo "실행 중이 아니에요."
fi

step "5/6 설치"
if [[ -e "$TARGET_APP" ]]; then
  trash "$TARGET_APP"
  echo "예전 앱을 휴지통으로 옮겼어요."
fi
ditto "$BUILT_APP" "$TARGET_APP"
# 아이콘·앱 정보를 시스템에 다시 알림(Dock·Finder 아이콘이 예전 것으로 보일 때)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$TARGET_APP" || true
echo "$TARGET_APP 에 설치했어요."

step "6/6 정리"
if (( KEEP_BUILD == 0 )); then
  trash "$BUILD_DIR"
  echo "build 폴더를 휴지통으로 옮겼어요(휴지통을 비워야 공간이 돌아와요)."
else
  echo "build 폴더를 남겨 뒀어요(--keep-build)."
fi

open "$TARGET_APP"
print "\n✅ $APP_NAME $VERSION 설치 완료. 로그인 자동 실행이 켜져 있었다면 앱이 새 위치로 다시 등록해요."
