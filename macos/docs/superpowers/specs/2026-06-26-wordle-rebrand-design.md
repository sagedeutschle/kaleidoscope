# Wordle Rebrand Design

Date: 2026-06-26

## Scope

Rename the `Signal Five` workspace to `Wordle` and reshape the puzzle view so it reads as a familiar Wordle-style game screen. Keep the existing scoring logic, NYT Daily fetch, Random mode, and Local Daily fallback.

## UI Direction

Use a restrained Wordle-like interface: white page, centered title, square tiles, green/yellow/gray feedback colors, and an on-screen keyboard. The puzzle should be the main visual object; source controls can remain available but should not dominate the first impression.

## Behavior

Typing and clicking the on-screen keyboard both update the current guess. Enter submits, Backspace deletes, and input stops after win or loss. The NYT Daily flow remains intact; if it fails, the existing local daily fallback remains the recovery path.

## Verification

Add a unit test for the user-visible workspace name. Run the Wordle model/provider tests and the app test target after implementation.
