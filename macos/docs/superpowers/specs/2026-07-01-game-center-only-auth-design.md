# Game Center Only Auth Design

Date: 2026-07-01
Scope: iOS Kaleidoscope and macOS Kaleidoscope

## Goal

Make Game Center the only visible account/sign-in system in both apps. Remove phone
number, SMS code, OTP, and Twilio-dependent paths from the user-facing app surface.
Rename the user-facing Wordle game label to `Wordgame`.

Also fix the iOS Remove Ads button for the `$4.99` StoreKit purchase path.

## Current State

iOS already has `GameCenterIdentity`, which can authenticate `GKLocalPlayer`, derive
a deterministic account UUID from `teamPlayerID`, and expose a display name. The
iOS root gate still uses `AuthManager` with Supabase phone OTP, and the sign-in
screen asks for phone and SMS code.

macOS already has a Game Center toolbar status controller for leaderboards. It also
has a separate Supabase phone OTP account panel that mirrors the old mobile login.

## Chosen Approach

Use Game Center as the only player identity across both apps.

For this pass, do not build a full Game Center-to-Supabase custom auth backend.
Instead, remove SMS/Twilio surfaces now and route app identity through Game Center
where the app needs a local account id. Existing Supabase storage/leaderboard code
may remain as backend plumbing, but it must not expose phone sign-in or depend on
Twilio/SMS for the user path.

## iOS Behavior

On launch, iOS starts Game Center authentication. If Game Center authenticates, the
app derives the existing deterministic account UUID and loads or creates the profile
for that UUID. If Game Center needs Apple sign-in UI, the app presents Apple's Game
Center sheet. If Game Center is unavailable or declined, gameplay remains reachable
where practical, but cloud/account features should show a Game Center unavailable
state instead of a phone login.

Remove `PhoneSignInView` from the root route. `AuthManager` should no longer send or
verify SMS codes. Profile setup should seed display name from Game Center when
available.

## macOS Behavior

The toolbar Game Center control remains the only account/sign-in surface. The
phone-based account panel should be removed or converted into a Game Center status
panel. No phone number, SMS code, or Supabase OTP controls should remain visible.

Local play remains usable. Game Center-backed leaderboards keep their current
fallback behavior: local results still save even if Game Center submission fails.

## Wordgame Naming

The visible game name changes from Wordle/Daily Wordle to `Wordgame`/`Daily
Wordgame`, depending on context. Practice mode behavior stays unchanged. Internal
type names may stay as-is during this pass if that avoids risky broad renames, but
tests should guard that user-visible labels no longer use Wordle.

## Data And Privacy

Phone numbers are no longer collected. No Twilio setup is required for sign-in.
Profiles should not display phone fields. Any legacy `phone` column in Supabase can
remain for backward compatibility, but new app UI should write `nil` and never ask
for it.

## Remove Ads $4.99 Purchase Button

Root cause: the iOS `Remove Ads` sheet calls StoreKit for
`com.spocksclub.kaleidoscope.removeads`, but the real App Store Connect IAP is not
created/available yet, and the repo has no local `.storekit` configuration for
development purchase testing. The local entitlement and banner hiding path already
work after a purchase is granted; product discovery is the failing boundary.

For this pass, the primary button should:

- Use StoreKit purchase for the `$4.99` non-consumable product when the product is
  available.
- Add a local StoreKit configuration for Debug/simulator testing of
  `com.spocksclub.kaleidoscope.removeads` at `$4.99`, so the button can be verified
  before App Store Connect is finished.
- Show an explicit setup blocker when StoreKit cannot load the product, instead of
  making the button feel dead.
- Continue to support restore and private tester codes.
- Avoid changing ad placement or AdMob configuration.

Important limitation: a real App Store/TestFlight `$4.99` purchase still requires
the App Store Connect non-consumable product, Paid Applications Agreement, and
banking/tax setup. Code can make the app handle StoreKit correctly; it cannot create
or approve the Apple-side product from inside the app.

## Testing

Add or update focused tests to cover:

- Game Center-derived identity/state replaces phone auth routing.
- Phone normalization, send-code, and verify-code user paths are removed.
- Profile creation can work with a Game Center-derived account UUID.
- Visible Wordgame naming replaces visible Wordle naming.
- Existing Game Center leaderboard tests still pass.
- Remove Ads StoreKit product loading and purchase outcome handling are testable.
- When StoreKit grants the remove-ads purchase, `adsRemoved == true` and the banner
  path hides immediately.
- When StoreKit cannot load the product, the UI reports the Apple/setup blocker.

Run focused tests first, then run the normal iOS and macOS build/test gates for the
files touched.
