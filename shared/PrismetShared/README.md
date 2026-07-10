# PrismetShared

Shared Swift package for code and metadata that must stay identical between:

- iOS: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Prismet`
- macOS: `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap`

Start small and migrate safely. The first shared layer is the feature manifest:
canonical feature IDs, platform-specific legacy IDs, display names, categories,
leaderboard policy, and launch-review visibility. This lets both apps agree on
what a feature is even when old local IDs differ.

Migration rule:

1. New cross-platform features go here first when they are not UI-framework-specific.
2. Existing duplicated code moves here only after both apps have focused tests.
3. Platform views stay in the app targets unless they can be expressed without
   SwiftUI/AppKit/UIKit assumptions.
4. Never break existing save/cloud IDs; add mappings in the shared manifest first.
