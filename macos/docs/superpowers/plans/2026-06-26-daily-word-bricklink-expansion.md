# Daily Word And BrickLink Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add authorized daily-word source plumbing and expand Brick Bench into a richer BrickLink-compatible catalog/import/export tool.

**Architecture:** Keep puzzle scoring and LEGO document state pure and unit-testable. Add small provider/exporter/importer boundaries, then wire SwiftUI controls to those APIs without embedding credentials or scraping third-party services.

**Tech Stack:** Swift 5, SwiftUI, Foundation XMLParser, XCTest, XcodeGen.

## Global Constraints

- Do not scrape or hardcode undocumented NYT Wordle feeds.
- Support an optional authorized remote daily-word JSON endpoint plus local fallback.
- Do not embed BrickLink secrets; live API work stays behind a client boundary.
- Keep existing chess behavior untouched.

---

### Task 1: Daily Word Provider

**Files:**
- Create: `Sources/Model/DailyWordProvider.swift`
- Modify: `Sources/Views/WordPuzzleView.swift`
- Test: `Tests/DailyWordProviderTests.swift`

**Interfaces:**
- Produces: `DailyWordSource`, `DailyWord`, `DailyWordProvider`, `RemoteDailyWordPayload`
- Consumes: `WordPuzzleGame(answer:allowedWords:maxGuesses:)`

- [ ] Write failing tests for local date-based fallback and remote JSON decoding.
- [ ] Run `xcodebuild ... test` and confirm tests fail because types do not exist.
- [ ] Implement provider types and parsing.
- [ ] Wire the view to show local/remote source status.
- [ ] Run tests and smoke check Signal Five.

### Task 2: BrickLink Catalog Expansion

**Files:**
- Modify: `Sources/Model/LegoBuilderModel.swift`
- Modify: `Sources/Views/LegoBuilderView.swift`
- Test: `Tests/LegoBuilderModelTests.swift`

**Interfaces:**
- Produces: expanded `LegoBrickSize`, `LegoBrickColor`, `LegoElementKind`, `BrickLinkWantedListImporter`
- Consumes: existing `BrickLinkWantedListExporter.xml(for:)`

- [ ] Write failing tests for plate part numbers, expanded colors, and wanted-list XML import.
- [ ] Run `xcodebuild ... test` and confirm failures are missing APIs.
- [ ] Implement expanded catalog and XML importer.
- [ ] Add UI controls for XML import and expanded parts.
- [ ] Run full tests and smoke check Brick Bench.

### Task 3: Verification

**Files:**
- Verify all touched files.

- [ ] Run `xcodegen generate`.
- [ ] Run full `xcodebuild -project ChessHotSwap.xcodeproj -scheme ChessHotSwap -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test`.
- [ ] Launch app and verify Brick Bench and Signal Five basic flows.
