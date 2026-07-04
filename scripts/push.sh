#!/usr/bin/env bash
# Commit-and-push helper. Usage: scripts/push.sh "commit message"
# Stages everything, commits, rebases on origin, and pushes.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd -P)"
branch="$(git rev-parse --abbrev-ref HEAD)"

msg="${1:-}"
if [[ -z "$msg" ]]; then
  echo "usage: scripts/push.sh \"commit message\""
  exit 1
fi

if [[ -z "$(git status --porcelain)" ]]; then
  echo "nothing to commit; just pushing any local commits."
else
  git add -A
  git commit -m "$msg"
fi

echo "==> pull --rebase then push"
git pull --rebase origin "$branch"
git push origin "$branch"
echo "==> pushed $(git rev-parse --short HEAD) to origin/$branch."
