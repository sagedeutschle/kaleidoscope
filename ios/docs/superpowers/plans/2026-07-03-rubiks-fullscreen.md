# Rubik Fullscreen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fullscreen Rubik cube mode to the iPhone, iPad, and macOS Kaleidoscope apps, then deploy build 10 to the requested devices.

**Architecture:** Reuse the existing Rubik model, session, persistence, move controls, and Fable's mash-safe SceneKit renderers. Add a lightweight fullscreen presentation around the same cube view and action methods, with a compact overlay for close/help/moves/undo/scramble/reset.

**Tech Stack:** Swift 5, SwiftUI, SceneKit, XcodeGen, xcodebuild, devicectl, macOS deploy script.

## Global Constraints

- Do not touch Rubik core model semantics.
- Preserve existing swipe-sticker, orbit, buttons, keyboard, persistence, and leaderboard behavior.
- Do not edit ads, entitlements, Supabase schema, or unrelated Home routing.
- Use derived data under `~/Library/Caches`.
- Run `xcodegen generate` before verification and deploy.

---

### Task 1: iOS/iPad Fullscreen Entry

**Files:**
- Modify: `Sources/Features/Games/RubiksCubeView.swift`
- Test: `Tests/RubiksControlTests.swift`

**Interfaces:**
- Consumes: `RubiksMove.mobileControlRows`, `RubiksSceneKitCubeView(cube:onDragTurn:)`, existing `perform`, `undo`, `scramble`, `reset`, `helpButton`.
- Produces: an iOS `fullScreenCover` opened from an icon button.

- [x] Add a failing test that scans `RubiksCubeView.swift` for `fullScreenCover` and `arrow.up.left.and.arrow.down.right`.
- [x] Run the focused test and confirm it fails before production edits.
- [x] Add `@State private var showFullscreenCube = false`.
- [x] Add a fullscreen icon beside Help in the header.
- [x] Add a `fullScreenCover` whose content reuses the SceneKit cube and existing actions.
- [x] Run the focused test and iOS Rubik build/test selector.

### Task 2: macOS Fullscreen Entry

**Files:**
- Modify: `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap/Sources/Views/RubiksCubeView.swift`

**Interfaces:**
- Consumes: `RubiksSceneView(cube:onDragTurn:)`, `session.turn`, `session.scramble`, `session.undo`, `session.reset`.
- Produces: a macOS fullscreen sheet opened from an icon button.

- [x] Add fullscreen presentation state.
- [x] Add a fullscreen icon in the Rubik header.
- [x] Add a native macOS fullscreen window that reuses `RubiksSceneView` and session actions.
- [x] Run macOS build verification.

### Task 3: Deploy

**Files:**
- Use: `scripts/deploy.sh`
- Use: `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap/scripts/deploy-mac.sh`

- [x] Run `xcodegen generate` in both app roots.
- [x] Run focused iOS tests/build and macOS build.
- [x] Deploy iOS Debug build to Poopoohead using active Xcode device id `00008120-001278982192201E`.
- [x] Deploy iOS Debug build to iPad using active Xcode device id `00008122-001E79A20EB9801C`.
- [x] Deploy macOS app using `scripts/deploy-mac.sh`.
