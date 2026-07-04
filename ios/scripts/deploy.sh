#!/usr/bin/env bash
# Kaleidoscope deploy: regen project → build → install → launch on Poopoohead.
# Mirrors AlarmClock's deploy.sh. Build dir lives in ~/Library/Caches (NOT iCloud Desktop)
# so the .app has no file-provider xattrs that break CodeSign.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT_NAME="Kaleidoscope"
SCHEME="$PROJECT_NAME"
CONFIG="${CONFIG:-Debug}"
BUNDLE_ID="com.spocksclub.kaleidoscope"
DEVICE_ID="${DEVICE_ID:-}"
DEVICE_NAME="${DEVICE_NAME:-Poopoohead}"
if [ -n "$DEVICE_ID" ]; then DESTINATION="platform=iOS,id=$DEVICE_ID"; else DESTINATION="platform=iOS,name=$DEVICE_NAME"; fi
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Caches/Kaleidoscope-build}"
LOG_FILE="$BUILD_DIR/last-build.log"
mkdir -p "$BUILD_DIR"

if [[ "${KALEIDOSCOPE_SKIP_PARITY:-0}" != "1" && -x scripts/check-mac-ios-parity.sh ]]; then
    echo "==> Checking macOS parity gate"
    scripts/check-mac-ios-parity.sh --strict
fi

echo "==> Regenerating ${PROJECT_NAME}.xcodeproj"
xcodegen generate --quiet

build_once() {
    set +e
    xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "$SCHEME" -configuration "$CONFIG" \
        -destination "$DESTINATION" -derivedDataPath "$BUILD_DIR/DerivedData" \
        -allowProvisioningUpdates -quiet \
        ${DEVELOPMENT_TEAM:+DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM} build > "$LOG_FILE" 2>&1
    local rc=$?; set -e; return $rc
}

echo "==> Building $SCHEME for device (log: $LOG_FILE)"
RC=0; build_once || RC=$?
if [[ $RC -ne 0 ]] && grep -q "resource fork, Finder information" "$LOG_FILE"; then
    echo "    stripping xattrs and retrying"
    PRODUCTS_DIR="$BUILD_DIR/DerivedData/Build/Products/$CONFIG-iphoneos"
    [[ -d "$PRODUCTS_DIR" ]] && { find "$PRODUCTS_DIR" -name "*.app" -prune -exec xattr -cr {} \; ; xattr -cr "$PRODUCTS_DIR" 2>/dev/null || true; }
    RC=0; build_once || RC=$?
fi
if [[ $RC -ne 0 ]]; then echo "BUILD FAILED. Last 50 lines:"; tail -50 "$LOG_FILE"; exit 1; fi

APP_PATH=$(find "$BUILD_DIR/DerivedData/Build/Products/$CONFIG-iphoneos" -maxdepth 1 -name "*.app" 2>/dev/null | head -1)
[[ -z "$APP_PATH" ]] && { echo "ERROR: no .app built"; exit 1; }
DEVICECTL_TARGET="${DEVICE_ID:-$DEVICE_NAME}"
echo "==> Installing on $DEVICECTL_TARGET"
xcrun devicectl device install app --device "$DEVICECTL_TARGET" "$APP_PATH"
echo "==> Launching $BUNDLE_ID"
xcrun devicectl device process launch --device "$DEVICECTL_TARGET" "$BUNDLE_ID"
echo "==> Done"
