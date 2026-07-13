# Prismet Apple Watch Field Deck handoff

Date: 2026-07-13

Branch: `codex/watch-field-deck-20260713`

## Outcome

Prismet now embeds a modern SwiftUI Apple Watch companion called **Field Deck**. It is designed for
an away-from-laptop day: the Watch keeps the last useful project snapshot locally, exposes a manual
phone refresh, and includes three deterministic offline games.

The implementation is complete and verified. Physical delivery is the only open boundary: all three
known iPhones went out of CoreDevice range before the final install, and no paired physical Watch was
visible to Xcode. The signed app bundle is ready for the next reachable phone.

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

Signed local artifact:

`/Users/gtrktscrb/Library/Caches/PrismetWatchSigned/Build/Products/Debug-iphoneos/Prismet.app`

Visual evidence:

- `/Users/gtrktscrb/.codex/visualizations/2026/07/13/019f5cd4-3d26-7c43-829f-d5330371ed51/watch-field-deck/final-home.png`
- `/Users/gtrktscrb/.codex/visualizations/2026/07/13/019f5cd4-3d26-7c43-829f-d5330371ed51/watch-field-deck/final-harvest.png`

## Physical delivery status

At the final gate, CoreDevice reported Benjamin's iPhone, MommaPhone, and Poopoohead as unavailable.
An install was attempted against each saved device identifier; each returned `The specified device
was not found`. `xctrace`/CoreDevice exposed no physical Apple Watch, so a Watch install could not be
truthfully claimed.

When a paired iPhone is back on the laptop's reachable network, install the signed Prismet app on that
phone. The embedded Field Deck will then be eligible for normal paired-Watch installation; if automatic
app install is disabled, use the iPhone Watch app to install **Prismet Field Deck** manually.

## Scope notes

- No App Store/TestFlight submission was made and the existing Prismet marketing/build version was
  deliberately left unchanged.
- The active Claude/Fable Catan lane and macOS Catan sources were not touched.
- Watch UI and complications are platform-specific; the snapshot and game model lives in portable
  Swift under `shared/WatchFieldDeckCore`.
