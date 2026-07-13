# Prismet Apple Watch Field Deck handoff

Date: 2026-07-13

Branch: `codex/watch-field-deck-20260713`

## Outcome

Prismet now embeds a modern SwiftUI Apple Watch companion called **Field Deck**. It is designed for
an away-from-laptop day: the Watch keeps the last useful project snapshot locally, exposes a manual
phone refresh, and includes three deterministic offline games.

The implementation is complete and verified. A later same-day retry delivered the signed companion
bundle to three reachable iPhones. Physical Watch launch is the only open boundary because no paired
Watch is visible to Xcode as a development destination.

## What shipped

- Eight project pulse cards: Prismet, The Long Now, Allhands, PrismCode, Proton Outlook, Minecraft
  Mesh, Media/NAS, and Mac Workflow.
- Local-first snapshot storage with clear active/tracked counts and stale/offline messaging.
- WatchConnectivity bridge for iPhone-to-Watch snapshot updates and a manual **Link** refresh action.
- Pocket 2048, a 5×5 Lights Out board, and Catan Harvest; all persist their local state.
- Rectangular, circular, and inline Field Deck complications that deep-link to today's pulse.
- Native navy-and-gold SwiftUI treatment, accessibility labels, and lightweight haptics.
- An embedded Watch app and widget extension inside the signed Prismet iPhone app.

## Verification

| Gate | Result |
| --- | --- |
| Portable Field Deck core | 10/10 tests passed |
| Full Prismet iOS suite | 322/322 tests passed |
| Generic watchOS build | Succeeded |
| Signed generic iOS build | Succeeded |
| Deep signature check | iPhone app, Watch app, and widget all valid |
| Apple Watch simulator | Installed, launched, and visually checked |
| Games visual pass | 2048 4×4, Lights Out 5×5, and Catan Harvest checked |

Latest signed local artifact:

`/Users/gtrktscrb/Library/Caches/PrismetWatchIPhone8/Build/Products/Debug-iphoneos/Prismet.app`

Visual evidence:

- `/Users/gtrktscrb/.codex/visualizations/2026/07/13/019f5cd4-3d26-7c43-829f-d5330371ed51/watch-field-deck/final-home.png`
- `/Users/gtrktscrb/.codex/visualizations/2026/07/13/019f5cd4-3d26-7c43-829f-d5330371ed51/watch-field-deck/final-harvest.png`

## Physical delivery status

The first deployment attempt found all known phones unavailable. Later, `iPhone (8)`, Benjamin's
iPhone, and Poopoohead became reachable. The original profile did not contain `iPhone (8)` and was
rejected with `0xe8008012`; a device-targeted automatic-signing build refreshed the profile and passed
deep signature verification.

| Device | Install | Launch |
| --- | --- | --- |
| `iPhone (8)` | Confirmed, Prismet 1.2 (14) | Confirmed |
| Benjamin's iPhone | Confirmed, Prismet 1.2 (14) | Blocked because phone was locked |
| Poopoohead | Confirmed, Prismet 1.2 (14) | Confirmed |

The embedded Watch app and widget are present in each installed iPhone bundle. The physical Watch is
still absent from `xctrace`, CoreDevice, and the Watch scheme's destination list. Direct development
installation therefore needs Developer Mode enabled on both the companion iPhone and the Watch, with
the Watch paired to this Mac through Xcode Device Hub. If automatic app installation is already enabled,
the embedded Field Deck may install through the companion phone; otherwise use the iPhone Watch app to
install it after the Watch becomes available.

## Scope notes

- No App Store/TestFlight submission was made and the existing Prismet marketing/build version was
  deliberately left unchanged.
- The active Claude/Fable Catan lane and macOS Catan sources were not touched.
- Watch UI and complications are platform-specific; the snapshot and game model lives in portable
  Swift under `shared/WatchFieldDeckCore`.
