#!/usr/bin/env bash
# Pull the latest before you start working.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd -P)"
branch="$(git rev-parse --abbrev-ref HEAD)"
echo "==> pull --rebase origin/$branch"
git pull --rebase origin "$branch"
echo "==> at $(git rev-parse --short HEAD). Read docs/AGENT-COORDINATION.md for the latest lane claims."
