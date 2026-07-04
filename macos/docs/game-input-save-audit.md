# Kaleidoscope Game Input + Save-State Audit

PRISM: Agent-B 2026-06-27 — input/save-state congruency sweep handoff.

## Current Coverage

| Facet | Primary input | Keyboard input | Undo | Disk-backed state |
| --- | --- | --- | --- | --- |
| Chess | board tap/click, toolbar | existing board shortcuts | yes | yes |
| Wordle | on-screen keyboard | letters, Enter, Delete | no | yes |
| Brick Bench | builder controls, scene gestures | configurable shortcuts | yes/redo | yes |
| 2048 | arrow buttons, drag/swipe | arrow keys | yes | yes |
| Lights Out | light buttons | not needed for 5x5 click grid | yes | yes |
| Minesweeper | choose/flag controls, click/right-click | mouse-first | yes | yes |
| Snake | timed board, pause/new game | arrows, WASD, Space | no | yes |
| Sudoku | cell buttons, keypad | arrows, 1-9, Delete | yes | yes |
| Sliding-15 | tile buttons | arrow keys | yes | yes |
| Nonogram | cell click-cycle | mouse-first | yes | yes |
| Reversi | legal-move buttons, pass | mouse-first | yes | yes |
| Rubik's Cube | face buttons, turn picker, SceneKit camera | camera/SceneKit default | yes | yes |

## Save-State Convention

- `ContentView` owns one `@StateObject` session per playable facet.
- Every disk-backed game writes a per-window JSON file under the existing `GamePersistenceStore` window-session directory.
- `ContentView` saves the outgoing facet and reloads the incoming facet on sidebar selection changes.
- `ContentView` saves every disk-backed game when the scene leaves active state or the view disappears.
- Active animation state is intentionally not persisted. 2048 reloads the stable board after a move/shuffle, not a half-finished slide or shuffle overlay.
- Snake does not autosave every timer tick; it saves directional/running/new-game changes, score/loss events, explicit State saves, and lifecycle/tab-switch saves.

## Next Useful Input Passes

- Add optional keyboard cursor/confirm navigation to Reversi if users want fully keyboard-playable board games.
- Add explicit mark modes to Nonogram if click-cycle becomes frustrating on larger puzzles.
- Add Rubik's face hotkeys (`U`, `D`, `L`, `R`, `F`, `B`) if the 3D facet starts getting serious use.
