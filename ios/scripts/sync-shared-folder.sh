#!/usr/bin/env bash
# DEPRECATED. This repo now syncs through git, not an rsync mirror.
#
# Previously this script rsync-mirrored just the iOS app to
# /Volumes/homes/Kaleidescopesharedfolder/Prismet. That created a
# divergent copy that fought the real source of truth. Don't use it.
#
# The whole monorepo (ios/ + macos/ + oracle/) is a git repo whose canonical
# copy is the private GitHub repo. The NAS shared folder is itself a clone.
# To sync, from the repo root:
#     scripts/pull.sh     # git pull --rebase   (before you work)
#     scripts/push.sh "…" # commit + push        (after you work)
#     scripts/sync.sh     # pull-rebase then push
#
# See AGENTS.md §3 (sync model). Build on your LOCAL clone, never on the NAS mount.
echo "sync-shared-folder.sh is deprecated — this repo syncs through git."
echo "Use scripts/sync.sh (or pull.sh / push.sh) from the repo root. See AGENTS.md §3."
exit 1
