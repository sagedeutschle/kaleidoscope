#!/usr/bin/env bash
# Build Kaleidoscope once, then install/launch it on every paired tester phone
# that CoreDevice can reach over USB or Wi-Fi.
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_NAME="Kaleidoscope"
SCHEME="$PROJECT_NAME"
CONFIG="${CONFIG:-Debug}"
BUNDLE_ID="com.spocksclub.kaleidoscope"
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Caches/Kaleidoscope-testers-build}"
LOG_FILE="$BUILD_DIR/last-build.log"
APP_PATH="${APP_PATH:-}"

mkdir -p "$BUILD_DIR"

if [[ "${KALEIDOSCOPE_SKIP_PARITY:-0}" != "1" && -x scripts/check-mac-ios-parity.sh ]]; then
  echo "==> Checking macOS parity gate"
  scripts/check-mac-ios-parity.sh --strict
fi

if [[ -z "$APP_PATH" ]]; then
  echo "==> Regenerating ${PROJECT_NAME}.xcodeproj"
  xcodegen generate --quiet

  echo "==> Building $SCHEME once for iOS devices (log: $LOG_FILE)"
  xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "${BUILD_DESTINATION:-generic/platform=iOS}" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -allowProvisioningUpdates \
    -quiet \
    ${DEVELOPMENT_TEAM:+DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM} \
    build > "$LOG_FILE" 2>&1 || {
      echo "BUILD FAILED. Last 60 lines:"
      tail -60 "$LOG_FILE"
      exit 1
    }

  APP_PATH="$(find "$BUILD_DIR/DerivedData/Build/Products/$CONFIG-iphoneos" -maxdepth 1 -name "*.app" 2>/dev/null | head -1)"
fi

[[ -d "$APP_PATH" ]] || { echo "ERROR: no .app found at $APP_PATH"; exit 1; }

echo "==> Using app: $APP_PATH"
echo "==> Reachable devices:"
xcrun devicectl list devices

# Format: display name | primary id | fallback id
# The primary/fallback order is empirical: CoreDevice ID is more reliable for
# Poopoohead; hardware UDID is more reliable for Benjamin's phone.
TESTERS=(
  "Poopoohead|B2081DF4-7D29-5F35-8CC4-18227227036B|00008120-001278982192201E"
  "Benjamin's iPhone|00008150-000874440EF0401C|593AADAC-1388-5369-98C4-AB7C4003F374"
)

overall_rc=0
for tester in "${TESTERS[@]}"; do
  IFS='|' read -r name primary fallback <<< "$tester"
  echo "==> Installing on $name"

  installed=0
  for device in "$primary" "$fallback"; do
    [[ -n "$device" ]] || continue
    echo "    trying $device"
    if xcrun devicectl device install app --device "$device" "$APP_PATH"; then
      echo "    launching $BUNDLE_ID on $name"
      xcrun devicectl device process launch --device "$device" "$BUNDLE_ID" || true
      installed=1
      break
    fi
  done

  if [[ "$installed" -eq 0 ]]; then
    echo "WARN: failed to install on $name"
    overall_rc=1
  fi
done

exit "$overall_rc"
