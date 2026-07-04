#!/usr/bin/env bash
set -euo pipefail

require_live=false
if [[ "${1:-}" == "--require-live" ]]; then
  require_live=true
  shift
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="${1:-"$ROOT/project.yml"}"

TEST_APP_ID="ca-app-pub-3940256099942544~1458002511"
TEST_BANNER_ID="ca-app-pub-3940256099942544/2934735716"

extract_value() {
  local key="$1"
  awk -v key="$key" '
    $1 == key ":" {
      sub(/^[^:]+:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      found = 1
      exit
    }
    END { if (!found) exit 1 }
  ' "$PROJECT_YML" 2>/dev/null || true
}

valid_app_id() {
  [[ "$1" =~ ^ca-app-pub-[0-9]{16}~[0-9]{10}$ ]]
}

valid_banner_id() {
  [[ "$1" =~ ^ca-app-pub-[0-9]{16}/[0-9]{10}$ ]]
}

APP_ID="$(extract_value "GADApplicationIdentifier")"
BANNER_ID="$(extract_value "KaleidoscopeAdMobBannerUnitID")"
blockers=()

if [[ -z "$APP_ID" ]]; then
  blockers+=("AdMob app id is missing")
elif [[ "$APP_ID" == "$TEST_APP_ID" ]]; then
  blockers+=("AdMob app id is still Google's sample/test id")
elif ! valid_app_id "$APP_ID"; then
  blockers+=("AdMob app id is malformed")
fi

if [[ -z "$BANNER_ID" ]]; then
  blockers+=("AdMob banner unit id is missing")
elif [[ "$BANNER_ID" == "$TEST_BANNER_ID" ]]; then
  blockers+=("AdMob banner unit id is still Google's sample/test id")
elif ! valid_banner_id "$BANNER_ID"; then
  blockers+=("AdMob banner unit id is malformed")
fi

if [[ "${#blockers[@]}" -eq 0 ]]; then
  echo "ADMOB_STATUS=LIVE_READY"
  echo "GADApplicationIdentifier=$APP_ID"
  echo "KaleidoscopeAdMobBannerUnitID=$BANNER_ID"
  exit 0
fi

echo "ADMOB_STATUS=TEST_ONLY"
for blocker in "${blockers[@]}"; do
  echo "BLOCKER: $blocker"
done

if [[ "$require_live" == true ]]; then
  exit 2
fi
