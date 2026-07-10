#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_NAME="Prismet"
SCHEME="$PROJECT_NAME"
CONFIG="${CONFIG:-Debug}"
BUNDLE_ID="com.gtrktscrb.kaleidoscope"
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Caches/Prismet-mac-build}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
LOG_FILE="$BUILD_DIR/last-build.log"

mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

echo "==> Regenerating ${PROJECT_NAME}.xcodeproj"
xcodegen generate --quiet

echo "==> Building $SCHEME for macOS"
set +e
xcodebuild \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet \
  build > "$LOG_FILE" 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "Build failed. Last 50 log lines from $LOG_FILE:"
  tail -50 "$LOG_FILE"
  exit "$status"
fi

APP_PATH="$(find "$BUILD_DIR/DerivedData/Build/Products/$CONFIG" -maxdepth 1 -name 'Prismet.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "Build completed, but Prismet.app was not found."
  exit 1
fi

DEST_APP="$INSTALL_DIR/Prismet.app"
echo "==> Closing any running $BUNDLE_ID"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
sleep 0.5

echo "==> Installing $DEST_APP"
rm -rf "$DEST_APP"
ditto "$APP_PATH" "$DEST_APP"

echo "==> Launching $BUNDLE_ID"
open -a "$DEST_APP"

echo "==> Installed and launched $DEST_APP"
