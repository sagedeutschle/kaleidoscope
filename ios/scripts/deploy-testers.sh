#!/usr/bin/env bash
# Build Prismet once, then install/launch it on every paired tester phone
# that CoreDevice can reach over USB or Wi-Fi.
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_NAME="Prismet"
SCHEME="$PROJECT_NAME"
CONFIG="${CONFIG:-Debug}"
BUNDLE_ID="com.spocksclub.kaleidoscope"
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Caches/Prismet-testers-build}"
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
  "MommaPhone|FF4B1908-94F7-5DF9-8793-8E6782A8614B|00008150-000A0DA02200401C"
)

overall_rc=0
summary=()
for tester in "${TESTERS[@]}"; do
  IFS='|' read -r name primary fallback <<< "$tester"
  echo "==> Installing on $name"

  installed=0
  launched=0
  used_device=""
  for device in "$primary" "$fallback"; do
    [[ -n "$device" ]] || continue
    echo "    trying $device"
    if xcrun devicectl device install app --device "$device" "$APP_PATH"; then
      installed=1
      used_device="$device"
      echo "    launching $BUNDLE_ID on $name"
      if xcrun devicectl device process launch --device "$device" "$BUNDLE_ID"; then
        launched=1
      else
        echo "WARN: installed on $name, but launch failed. Unlock the device and rerun launch smoke."
      fi
      break
    fi
  done

  if [[ "$installed" -eq 0 ]]; then
    echo "WARN: failed to install on $name"
    summary+=("FAIL install: $name")
    overall_rc=1
  elif [[ "$launched" -eq 0 ]]; then
    summary+=("PARTIAL launch failed: $name ($used_device)")
    overall_rc=1
  else
    summary+=("OK installed+launched: $name ($used_device)")
  fi
done

echo "==> Tester deploy summary"
printf '    %s\n' "${summary[@]}"

exit "$overall_rc"
