#!/usr/bin/env bash
set -euo pipefail

# Monorepo layout: <repo>/{ios,macos}. This script lives in macos/scripts.
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
PHONE_PROJECT="${PHONE_PROJECT:-$REPO_ROOT/ios/project.yml}"
MAC_PROJECT="${MAC_PROJECT:-$REPO_ROOT/macos/project.yml}"

read_project_value() {
  local key="$1"
  awk -v key="$key" '
    $1 == key ":" {
      gsub(/"/, "", $2)
      print $2
      exit
    }
  ' "$PHONE_PROJECT"
}

MARKETING_VERSION="${1:-$(read_project_value MARKETING_VERSION)}"
CURRENT_PROJECT_VERSION="${2:-$(read_project_value CURRENT_PROJECT_VERSION)}"

if [[ -z "$MARKETING_VERSION" || -z "$CURRENT_PROJECT_VERSION" ]]; then
  echo "Usage: $0 [marketing-version current-project-version]"
  echo "Could not determine version values from $PHONE_PROJECT."
  exit 1
fi

export MARKETING_VERSION CURRENT_PROJECT_VERSION

update_project() {
  local project="$1"
  perl -0pi -e '
    s/MARKETING_VERSION: "[^"]+"/MARKETING_VERSION: "$ENV{MARKETING_VERSION}"/g;
    s/CURRENT_PROJECT_VERSION: "[^"]+"/CURRENT_PROJECT_VERSION: "$ENV{CURRENT_PROJECT_VERSION}"/g;
  ' "$project"
}

update_project "$PHONE_PROJECT"
update_project "$MAC_PROJECT"

echo "Synced Kaleidoscope versions to $MARKETING_VERSION ($CURRENT_PROJECT_VERSION)."
