#!/usr/bin/env bash
# Prismet sync: pull the latest, then push your committed work.
# Run this before you start and after you commit. It never touches the NAS mount —
# everything flows through GitHub.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd -P)"

branch="$(git rev-parse --abbrev-ref HEAD)"
echo "==> syncing branch '$branch' with origin"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "!! You have uncommitted changes. Commit them first, then re-run sync:"
  git status --short
  exit 1
fi

echo "==> pull --rebase"
git pull --rebase origin "$branch"

echo "==> push"
git push origin "$branch"

echo "==> done. $(git rev-parse --short HEAD) is now on origin/$branch."
