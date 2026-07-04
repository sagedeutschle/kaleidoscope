# Sound + Haptics ("Feel") — Design

**Date:** 2026-07-03
**Author:** Agent-Design (Claude/Opus)
**Status:** Approved (Sage, interactive session) — first slice of "v11"

## Problem

The app is completely silent — every game plays with no audio, and the v10 audit's
completeness critic flagged it as the single biggest "feels alive" gap. Haptics
already fire in 19 game views via SwiftUI `.sensoryFeedback`, but they are ungated
(no way to turn them off) and inconsistent. There is no Settings control for either.

## Goal

Give every game audible + tactile feedback for its key moments, gated by a single
"Sound & Haptics" Settings section. Sounds are **synthesized in-app** (no audio
files, no licensing) to match the app's craft aesthetic and dodge the CC-BY asset
problem that dogged the icons.

Non-goals (YAGNI for v1): background music, per-game sound themes, a volume slider,
spatial audio, macOS parity (flagged as a follow-up, not this spec).

## Architecture

Three small, independently-testable units under `Sources/Core/Feedback/`:

### 1. `SoundCue` — the semantic vocabulary (pure)
An enum of ~9 events that covers every game, decoupled from any one game's terms:

| Cue | Used by (examples) | Sound (marimba/wood palette, pentatonic) | Haptic |
|-----|--------------------|------------------------------------------|--------|
| `.move` | piece move, tile slide, card play | soft wood tick, C5, ~60ms | `.impact(.light)` |
| `.select` | pick up piece, take aim | gentle high tick, E5, ~40ms | `.selection` |
| `.capture` | checkers jump, chess capture | low thunk, A3, ~120ms | `.impact(.medium)` |
| `.hit` | sea battle hit, mine-adjacent reveal | punchy mid, D4, ~140ms | `.impact(.heavy)` |
| `.miss` | sea battle miss | soft plip, G4, ~70ms | `.impact(.light)` |
| `.sink` | sea battle ship sunk | descending A4→E4→A3, ~300ms | `.notification(.warning)` |
| `.win` | game won / solved | rising arpeggio C5-E5-G5-C6, ~450ms | `.notification(.success)` |
| `.lose` | game lost | descending G4-E4-C4, ~400ms | `.notification(.error)` |
| `.invalid` | illegal move, mine explode | dull double low tick, ~90ms | `.notification(.error)` |

`SoundCue` exposes pure descriptors: `notes: [Double]` (frequencies), `durations`,
`waveform` (`.sine`/`.triangle`), and `haptic: HapticKind`. This is what the
synthesizer and haptics wrapper read — no audio/UIKit dependency in the enum itself.

### 2. `SoundEngine` — synthesized playback (singleton)
- Wraps one `AVAudioEngine`. At first use it **pre-renders one `AVAudioPCMBuffer`
  per cue** from the cue's descriptors (44.1 kHz mono Float32, ADSR envelope:
  ~5 ms attack, short decay, low sustain, ~40 ms release) and caches them. Playback
  then just schedules a cached buffer → instant, no per-tap synthesis, no glitches.
- A small **pool of `AVAudioPlayerNode`s** (~5) round-robin so rapid/overlapping
  cues don't cut each other off; all connect to `mainMixerNode`.
- **Audio session category `.ambient`** with `.mixWithOthers` → respects the
  physical silent switch (muted phone = no sound) and never interrupts the user's
  music. Session + engine start **lazily** on the first real play, and only when
  sound is enabled.
- Robustness: engine/session failures degrade silently (never crash a game).
  Handles `AVAudioSession` interruptions (calls) by restarting on `.ended`.
- Pure seam for tests: `static func renderBuffer(for: SoundCue, format:) -> AVAudioPCMBuffer?`
  is a pure function of the cue (testable without hardware).

### 3. `Feedback` — the gate + the SwiftUI entry point
- `FeedbackSettings`: storage-key constants + defaults, registered at launch via
  `UserDefaults.register(defaults:)` so "unset" reads as ON:
  `app.soundEnabled` (Bool, default `true`), `app.hapticsEnabled` (Bool, default `true`).
- Pure decision function (testable): `FeedbackDecision(sound: Bool, haptics: Bool) -> (playSound: Bool, playHaptic: Bool)` — trivial today but isolates the gate.
- `Haptics.fire(_ cue:)` → maps `cue.haptic` to `UIImpactFeedbackGenerator` /
  `UINotificationFeedbackGenerator` / `UISelectionFeedbackGenerator`, gated on the
  haptics flag. Generators are `prepare()`d to cut latency.
- **One view modifier** — the single integration point games use:
  ```swift
  func gameFeedback<T: Equatable>(_ cue: SoundCue, trigger: T) -> some View
  ```
  On `trigger` change it reads the two flags and fires sound and/or haptic. This
  **replaces** the scattered `.sensoryFeedback(...)` calls, so both channels share
  one gate and stay in lockstep.

## Data flow

game event → view increments an `Equatable` trigger (e.g. `moveTick += 1`) →
`.gameFeedback(.move, trigger: moveTick)` → reads flags → `SoundEngine.shared.play(.move)`
if sound on + `Haptics.fire(.move)` if haptics on.

## Settings UX

New `soundHapticsSection` in `SettingsView`, above/near Appearance:
- Toggle **"Sound Effects"** → `app.soundEnabled`.
- Toggle **"Haptics"** → `app.hapticsEnabled`.
- Flipping Sound Effects **on** plays a `.select` sample so the choice is audible.
No volume slider (system volume governs).

## Rollout

- **Phase 1** — engine + settings + modifier + wire the 5 flagship games end-to-end:
  Checkers, Sea Battle, Chess, 2048, Minesweeper (replace their `.sensoryFeedback`
  with `.gameFeedback` and add the sound-bearing cues).
- **Phase 2** — remaining games (Snake, Solitaire, Reversi, Connect Four, Gomoku,
  Sudoku, Nonogram, Lights Out, Rubik's, Spider, Crazy 8, Wordgame, Brick Bench).

## Testing

- `SoundSynthTests` — for each `SoundCue`, `SoundEngine.renderBuffer(for:format:)`
  returns a non-nil buffer with `frameLength > 0` and all samples finite in [-1, 1].
- `FeedbackGateTests` — `FeedbackDecision` truth table (on/off × on/off) and that a
  disabled channel produces no play (via the pure decision, no hardware).
- `SoundCueTests` — every cue has ≥1 note, positive durations, a defined haptic.
- Actual audio + haptic output is verified live on device during the tester loop
  (not screenshot- or CI-verifiable).

## Concurrency / coordination

Codex is active in this repo (just landed the Sea Battle AI). New files are additive
(`Sources/Core/Feedback/*`); game-view edits swap `.sensoryFeedback` → `.gameFeedback`
(visual-layer-adjacent, my lane). Post a PRISM claim before wiring the shared game
views; re-read each view before editing (files move). Do not bump the build number.

## Risks

- **Synth quality**: bad tones sound cheaper than silence. Mitigation: warm
  triangle/sine + pentatonic notes + gentle envelope; tune on-device; keep volumes low.
- **Silent-switch surprise**: `.ambient` means muted phones hear nothing — this is the
  intended, polite default and matches system UI sounds.
- **Latency**: pre-rendered buffers + `prepare()`d haptics keep it tight.
