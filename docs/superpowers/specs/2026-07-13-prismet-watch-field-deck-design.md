# Prismet Apple Watch Field Deck Design

**Date:** 2026-07-13
**Status:** Approved for execution by Sage's explicit "green" / use-best-judgment direction

## Outcome

Add a native Apple Watch companion to Prismet that remains useful while Sage is away from the
laptop. The Watch gets an honest, dated snapshot of the active project universe, three small
offline games, phone-to-Watch refresh, and complication surfaces. The existing iPhone app embeds
the Watch app and activates the sync bridge without changing its normal user flow.

Success means:

- the field deck opens without the phone or network and clearly labels when its snapshot was made;
- the deck covers the active Prismet, Long Now, Allhands, PrismCode, Proton Outlook, Minecraft,
  media/NAS, and Mac/iMac lanes rather than pretending one repo is the whole workspace;
- Pocket 2048, Lights Out, and Catan Harvest are fully playable and persist locally;
- valid phone snapshots replace the bundled snapshot, while malformed or older payloads do not;
- rectangular, circular, and inline complication families expose a useful project pulse;
- the existing iPhone app still passes its complete test suite and embeds a signed Watch product;
- installation is attempted through every reachable paired iPhone, with install and launch results
  reported separately from Watch-side availability.

## Approaches Considered

### 1. Embedded Prismet companion with an offline core — selected

Prismet owns a modern watchOS app, a small shared Swift package, a silent iPhone
`WatchConnectivity` bridge, and a WidgetKit complication extension. The Watch ships with a dated
snapshot, so phone sync improves freshness but is never required to open the deck or play.

This is the best fit because Prismet already has the signing team, device deployment path, game
identity, and current Catan work. Embedding also lets a normal iPhone install carry the Watch app.

### 2. Separate standalone Watch product

A separate Xcode project would isolate signing and releases, but would create another app identity,
another install path, and no natural companion link to Prismet. That is unnecessary for today's
field use.

### 3. Web dashboard opened from the Watch

A web surface would be easier to update remotely, but would be network-dependent, awkward on a
small screen, unable to deliver native complications cleanly, and weaker for offline games.

## Architecture

### Shared core

`shared/WatchFieldDeckCore` is a dependency-free local Swift package supporting iOS, watchOS, and
macOS. It owns:

- `ProjectPulse`, `FieldDeckSnapshot`, and stable project identifiers;
- the dated `FieldDeckCatalog.july13` seed snapshot;
- JSON encode/decode plus freshness validation;
- pure value models for `Pocket2048`, `PocketLightsOut`, and `CatanHarvest`;
- deterministic random input so every rules path can be tested without UI or hardware.

The package contains no credentials, file paths, backend keys, or laptop-only assumptions.

### Watch app

`ios/WatchFieldDeck` is a modern SwiftUI watchOS application with three top-level destinations:

1. **Today** — a compact list of project pulses. Each detail page shows status, the newest verified
   milestone, the next useful action, and the snapshot time.
2. **Pocket Games** — Pocket 2048, 5×5 Lights Out, and Catan Harvest. Games use large controls,
   crown-friendly scrolling, accessibility labels, and restrained success/error haptics.
3. **Link** — phone reachability, last accepted refresh, and a manual request-refresh action.

`FieldDeckStore` persists the last accepted snapshot and game saves in Watch-local defaults. A
bundled seed is always available. The Watch session delegate accepts only decodable snapshots with
the expected schema version and a generation time newer than the persisted snapshot.

### iPhone bridge

`PhoneFieldDeckBridge` is activated from `PrismetApp.init()`. It sends the current shared-core
snapshot as application context when the session activates and responds to an explicit Watch
refresh message. It has no UI, does not read Prismet credentials, and does not alter auth startup.

### Complications

`ios/WatchFieldDeckWidget` supplies accessory rectangular, circular, and inline families. The
extension renders the safe bundled pulse rather than requiring a new App Group entitlement. The
rectangular family shows the top project plus active-lane count; circular/inline variants provide a
short Prismet/project signal. Tapping opens the Watch app.

### Project generation and embedding

`ios/project.yml` adds a separate `platform: watchOS` application target and WidgetKit extension,
using XcodeGen 2.45.4's native Watch embedding behavior. The existing iOS target depends on the
Watch app; the Watch app depends on the widget and shared core. Bundle identifiers extend the
frozen iPhone identifier without changing it:

- Watch app: `com.spocksclub.kaleidoscope.watchkitapp`
- Widget: `com.spocksclub.kaleidoscope.watchkitapp.fielddeck-widget`

The watchOS floor is 11.0. Marketing/build versions stay aligned with Prismet 1.2 (14); no App
Store submission is part of this task.

## Seed Project Pulse

The initial snapshot is explicitly labeled **Captured July 13, 2026** and contains:

- **Prismet:** Catan is playable on the active research branch; the pre-Watch iPhone suite is
  315/315 green; Catan macOS/App Store work remains in the separate Claude/Fable lane.
- **The Long Now:** ambient spectate is committed for Catan, Poker, Chess, and Reversi with the
  recorded 1589/1589 suite; today's wizard-token, guest-economy, Rune Slots, and Cicero slices are
  active uncommitted lanes and must not be presented as merged.
- **Allhands:** the always-visible Opus Ultracode panel is hardened and authenticated-smoke
  verified with its pinned Opus/xhigh identity.
- **PrismCode:** Quick Open and workspace search are merged locally; GUI acceptance, packaging,
  and notarization remain the honest next gates.
- **Proton Outlook Mod:** the VS Code tab now opens the shared command helm; packaging and tab
  tear-off remain later architecture work.
- **Minecraft Mesh:** player routing/control-plane work remains an operations lane with the iMac
  sleep boundary preserved.
- **Media/NAS:** Plex/Audiobookshelf work remains staging-first and one-writer-at-a-time.
- **Mac/iMac Workflow:** remote workflow restoration is non-destructive; the laptop remains home
  and unchanged while the field deck runs from phone/Watch.

## Game Rules

### Pocket 2048

A standard 4×4 board with deterministic tile spawns, four large directional controls, score and
best-score persistence, win detection at 2048, and restart confirmation after a terminal state.

### Pocket Lights Out

A 5×5 board using the Prismet cross-toggle rule. Seeded legal presses generate every puzzle, so a
solution always exists. The Watch tracks move count, solved state, and a new-puzzle action.

### Catan Harvest

Each turn rolls two six-sided dice. Productive totals score the standard Catan pip count (2/12 = 1
through 6/8 = 5); 7 triggers the robber and halves the unbanked harvest. The player may bank after
any productive roll, and reaches victory at 25 banked harvest. This is a deliberately small Catan-
flavored push-your-luck game, not a replacement for full Catan.

## Error Handling and Safety

- No network or phone: show the persisted or bundled snapshot and keep all games available.
- Invalid/unknown payload: ignore it, retain the last good snapshot, and show a non-blocking link
  status message.
- Older payload: ignore it to prevent accidental rollback.
- Watch not paired, unavailable, or not developer-enabled: preserve the signed embedded Watch
  product, report the exact blocker, and do not call a phone-only install a Watch install.
- Phone locked: install and launch are reported independently; retry another reachable registered
  phone rather than weakening signing or security.
- Secrets never cross WatchConnectivity and never enter the shared package or widget.

## Verification

1. Shared core tests run red then green for snapshot validation and each game rule boundary.
2. XcodeGen output is inspected for an Embed Watch Content phase and embedded widget dependency.
3. Generic watchOS and watchOS Simulator builds compile the app and widget.
4. Focused iOS bridge tests and the full existing iOS test suite pass.
5. A signed device build embeds `Prismet Watch App.app` inside the iPhone product.
6. The iPhone build is installed and launched on reachable devices. Watch-side presence/launch is
   verified only if Xcode/CoreDevice exposes the paired Watch; otherwise the exact pairing or
   Developer Mode step is left as the sole device-side handoff.

## Out of Scope

- App Store submission, build-number changes, or edits to Claude/Fable's Catan release lane.
- Remote laptop control, secrets, terminal access, email sending, or destructive project actions.
- Live project polling from the Watch. Phone snapshots are explicit, small, and user-installed.
- macOS UI parity; Watch UI and complication behavior are platform-specific by definition.
