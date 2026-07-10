# Prismet Shared Package Migration

The iOS and macOS apps now have a common SwiftPM dependency:

`/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/PrismetShared`

## Rule

Any new cross-platform feature starts with a shared contract:

- stable feature ID
- platform ID mapping when old IDs differ
- leaderboard/save/cloud identity
- launch-review visibility
- non-UI model or codec when it can compile on both iOS and macOS

Platform-specific SwiftUI/AppKit/UIKit views stay inside the app targets, but
they should read shared IDs and policies from `PrismetShared`.

## Current shared layer

- `PrismetFeatureManifest`
  - canonical feature IDs
  - current iOS legacy IDs (`rubiks`, `lightsout`, `brickbench`, etc.)
  - current macOS legacy IDs (`rubiks-cube`, `lights-out`, `brick-bench`, etc.)
  - feature titles/categories
  - leaderboard metric/period
  - Wordgame launch-review visibility flag

## Migration order

1. Keep existing save/cloud IDs stable; add aliases in the shared manifest first.
2. Move small pure Swift policies next: leaderboard catalogs, daily/lifetime board
   policy, and game mode support.
3. Move pure models only after both app targets have focused tests covering the
   same behavior.
4. Leave platform views local unless they become lightweight wrappers around a
   shared model.

## Verification

Run these after changing shared code:

```
cd /Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/PrismetShared
swift test
```

Then regenerate both projects:

```
cd /Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Prismet
xcodegen generate

cd /Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap
xcodegen generate
```
