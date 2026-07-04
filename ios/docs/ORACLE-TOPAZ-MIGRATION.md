# Oracle Council Topaz Migration Note

Date: 2026-07-01

## Current State

Kaleidoscope iOS Oracle is not a live data collector. The iOS route opens `OracleView`, which loads bundled decrees from `Resources/decrees.json` through `DecreeChronicle.loadBundled()`. User interaction persistence is limited to the local/cloud game-save path: selected decree, consult count, chronicle snapshot, and RNG state.

The actual Council/Oracle data system is separate from the iOS app:

- Project: `/Users/gtrktscrb/Desktop/GtrktscrB/ai-tools/wizard-kings-decree`
- Purpose: harvest matters, run model deliberation, resolve decrees, store SQLite, and publish chronicle outputs.
- Current deployment shape: Linux/systemd user timer targeting archbox via `tools/deploy_archbox.sh`.
- Older macOS Kaleidoscope can fetch published decrees from `http://archbox.lan:8790/decrees.json`; iOS does not currently have that live refresh path.

## Recommendation

Do not move iOS Oracle itself to topaz; there is no iOS Oracle backend process inside this repo to move.

If the goal is to make the Council data collector more always-on, plan a migration of `wizard-kings-decree` from archbox to topaz as a separate operations project. Topaz may be a better always-on host, but the current tooling assumes a Linux/systemd/Claude-CLI environment, while topaz is already used as a Windows/Docker home-server host.

## Migration Requirements

Before moving the Council runtime:

- Choose runtime model on topaz: Docker container, WSL service, or Windows scheduled task.
- Package Python dependencies and environment variables without exposing secrets.
- Decide how model credentials run on topaz.
- Back up and restore Council SQLite databases and chronicle outputs.
- Publish a stable LAN URL for `decrees.json`.
- Add iOS live-refresh support only after the publisher URL is stable, with bundled `decrees.json` as fallback.
- Confirm topaz load is acceptable alongside Plex/media/Minecraft duties.

## Suggested Next Slice

1. Create a topaz migration spec in `ai-tools/wizard-kings-decree`.
2. Containerize or script the daily Council run for topaz without touching the existing archbox timer.
3. Prove topaz can publish `decrees.json` on LAN.
4. Add an iOS `DecreeStore` equivalent that fetches the LAN chronicle and falls back to bundled resources.

This keeps the current iOS Oracle stable while making the always-on Council move reversible.
