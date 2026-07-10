#!/usr/bin/env bash
# Check that user-visible iOS work has a macOS parity decision before deploy.
set -euo pipefail

cd "$(dirname "$0")/.."

PHONE_ROOT="$(pwd)"
# Monorepo layout: <repo>/{ios,macos,shared}. This script lives in ios/scripts,
# so PHONE_ROOT is <repo>/ios and the repo root is one level up.
REPO_ROOT="$(cd "$PHONE_ROOT/.." && pwd -P)"
MAC_ROOT="${MAC_ROOT:-$REPO_ROOT/macos}"
SHARED_ROOT="${SHARED_ROOT:-$REPO_ROOT/shared/PrismetShared}"
PARITY_DOC="$PHONE_ROOT/docs/MAC-IOS-GAME-PARITY.md"
STRICT=0
SINCE_MINUTES="${SINCE_MINUTES:-1440}"
FILES=()

usage() {
  cat <<'EOF'
Usage: scripts/check-mac-ios-parity.sh [--strict] [--since-minutes N] [changed-file ...]

Default behavior:
  - Uses explicit changed-file args when provided.
  - Otherwise uses git diff if this checkout has git metadata.
  - Otherwise falls back to source/test/resource files modified in the last day.

Strict mode exits non-zero when source changes exist but the parity matrix has not
also been updated recently. Set KALEIDOSCOPE_SKIP_PARITY=1 only for emergency
local diagnostics, not tester or review deploys.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
      shift
      ;;
    --since-minutes)
      SINCE_MINUTES="${2:-}"
      [[ "$SINCE_MINUTES" =~ ^[0-9]+$ ]] || { echo "ERROR: --since-minutes requires a number"; exit 64; }
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      FILES+=("${1#$PHONE_ROOT/}")
      shift
      ;;
  esac
done

is_relevant_file() {
  case "$1" in
    Sources/*|Tests/*|Resources/*|project.yml|Package.resolved|Package.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

collect_recent_files() {
  local now cutoff path mtime parity_mtime
  now="$(date +%s)"
  cutoff=$((now - SINCE_MINUTES * 60))
  if [[ -f "$PARITY_DOC" ]]; then
    parity_mtime="$(file_mtime "$PARITY_DOC")"
    if [[ "$parity_mtime" =~ ^[0-9]+$ ]] && (( parity_mtime > cutoff )); then
      cutoff="$parity_mtime"
    fi
  fi

  while IFS= read -r path; do
    [[ -f "$path" ]] || continue
    mtime="$(file_mtime "$path")"
    [[ "$mtime" =~ ^[0-9]+$ ]] || continue
    if (( mtime >= cutoff )); then
      printf '%s\n' "${path#$PHONE_ROOT/}"
    fi
  done < <(
    {
      find "$PHONE_ROOT/Sources" "$PHONE_ROOT/Tests" "$PHONE_ROOT/Resources" -type f 2>/dev/null || true
      for path in "$PHONE_ROOT/project.yml" "$PHONE_ROOT/Package.resolved" "$PHONE_ROOT/Package.swift"; do
        [[ -f "$path" ]] && printf '%s\n' "$path"
      done
    } | sort -u
  )
}

collect_changed_files() {
  if (( ${#FILES[@]} > 0 )); then
    printf '%s\n' "${FILES[@]}"
    return
  fi

  if git -C "$PHONE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$PHONE_ROOT" diff --name-only -- Sources Tests Resources project.yml Package.resolved Package.swift
    git -C "$PHONE_ROOT" diff --name-only --cached -- Sources Tests Resources project.yml Package.resolved Package.swift
    return
  fi

  collect_recent_files
}

suggest_mac_targets() {
  local file="$1"
  local base
  base="$(basename "$file")"

  case "$file" in
    Sources/Core/Games/*)
      printf '  - %s -> %s/Sources/Model/%s\n' "$file" "$MAC_ROOT" "$base"
      ;;
    Sources/Features/Games/*)
      printf '  - %s -> %s/Sources/Views/%s\n' "$file" "$MAC_ROOT" "$base"
      ;;
    Sources/Core/Design/*)
      printf '  - %s -> %s/Sources/Model/PrismetDesign.swift\n' "$file" "$MAC_ROOT"
      ;;
    Sources/Features/Home/*)
      printf '  - %s -> %s/Sources/App/ContentView.swift, Sources/Views/HomeLensView.swift, Sources/Model/FacetRegistry.swift\n' "$file" "$MAC_ROOT"
      ;;
    Sources/Backend/*)
      printf '  - %s -> %s/Sources/Account/* or Sources/Model/GameLeaderboard.swift\n' "$file" "$MAC_ROOT"
      ;;
    Sources/Core/Ads/*)
      printf '  - %s -> usually iOS-only; record not-applicable unless macOS gets ads/remove-ads UI\n' "$file"
      ;;
    Resources/*)
      printf '  - %s -> %s/Sources/Resources/%s\n' "$file" "$MAC_ROOT" "${file#Resources/}"
      ;;
    project.yml|Package.resolved|Package.swift)
      printf '  - %s -> %s/project.yml and dependency/version scripts\n' "$file" "$MAC_ROOT"
      ;;
    Tests/*)
      printf '  - %s -> matching macOS Tests coverage when behavior exists on both apps\n' "$file"
      ;;
    *)
      printf '  - %s -> inspect macOS counterpart manually\n' "$file"
      ;;
  esac
}

CHANGED=()
while IFS= read -r file; do
  if is_relevant_file "$file"; then
    CHANGED+=("$file")
  fi
done < <(collect_changed_files | awk 'NF && !seen[$0]++')

echo "==> macOS parity gate"
echo "    iOS: $PHONE_ROOT"
echo "    macOS: $MAC_ROOT"
echo "    shared: $SHARED_ROOT"

if [[ ! -d "$MAC_ROOT" ]]; then
  echo "ERROR: macOS app root is missing: $MAC_ROOT"
  exit 2
fi

if [[ ! -d "$SHARED_ROOT" ]]; then
  echo "ERROR: shared package root is missing: $SHARED_ROOT"
  exit 2
fi

if (( ${#CHANGED[@]} == 0 )); then
  echo "    No changed/recent iOS source files detected."
  exit 0
fi

echo "    iOS source changes needing a macOS decision:"
for file in "${CHANGED[@]}"; do
  suggest_mac_targets "$file"
done

echo
echo "Required decision before deploy:"
echo "  1. Mirror into macOS now, or"
echo "  2. record why macOS is not applicable, or"
echo "  3. update docs/MAC-IOS-GAME-PARITY.md with owner, blocker, next action."

if (( STRICT == 0 )); then
  exit 0
fi

if [[ ! -f "$PARITY_DOC" ]]; then
  echo "ERROR: missing parity doc: $PARITY_DOC"
  exit 2
fi

now="$(date +%s)"
cutoff=$((now - SINCE_MINUTES * 60))
parity_mtime="$(file_mtime "$PARITY_DOC")"

if [[ ! "$parity_mtime" =~ ^[0-9]+$ ]] || (( parity_mtime < cutoff )); then
  echo "ERROR: strict parity gate failed."
  echo "       Update docs/MAC-IOS-GAME-PARITY.md with the macOS parity decision."
  exit 2
fi

echo "    Strict gate passed: parity matrix was updated within ${SINCE_MINUTES} minutes."
