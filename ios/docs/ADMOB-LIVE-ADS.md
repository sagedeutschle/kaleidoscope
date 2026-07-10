# Prismet Live AdMob Switch

Current state: the iOS app builds with Google Mobile Ads and uses Google's test
banner ids by default. Live ads need a real AdMob account, app id, and banner ad
unit id.

## External Blocker

Safari reaches the Google AdMob sign-in flow, but the saved Sage Google account
shows "Account deleted." Firefox is blocked by uBlock on `apps.admob.com`.

Use a valid Google account at:

```
https://apps.admob.com/
```

## Create The IDs

1. Sign in to AdMob.
2. Create/open the AdMob publisher account if prompted.
3. Add app:
   - Platform: iOS
   - App name: Prismet
   - App Store listing: choose the non-listed/not-published path if the app is not live yet.
4. Copy the AdMob App ID from App settings.
   - Format: `ca-app-pub-0000000000000000~0000000000`
5. Create an ad unit:
   - Format: Banner
   - Name: `Home bottom banner`
6. Copy the banner ad unit ID.
   - Format: `ca-app-pub-0000000000000000/0000000000`

## Wire Live Ads

Edit `project.yml`:

```yaml
GADApplicationIdentifier: ca-app-pub-0000000000000000~0000000000
PrismetAdMobBannerUnitID: ca-app-pub-0000000000000000/0000000000
```

Check the launch gate:

```bash
scripts/check-admob-live.sh --require-live
```

While blocked, it exits `2` and prints the specific missing/test IDs. Once both
IDs are real, it prints `ADMOB_STATUS=LIVE_READY`.

Then regenerate and test:

```bash
xcodegen generate
xcodebuild -project Prismet.xcodeproj -scheme Prismet \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug \
  -derivedDataPath "$HOME/Library/Caches/Prismet-admob-live-dd" \
  test
```

## Guardrails

- Do not tap live ads on your own device.
- Keep Google test ids during simulator/dev testing unless the intent is a final
  live verification build.
- New ad units may not fill immediately; an empty banner right after creation
  does not necessarily mean the integration is broken.
- The bottom banner is hidden whenever `AdEntitlementStore.adsRemoved` is true.
  See `docs/REMOVE-ADS-CODES.md` for tester/family code hashes and the $4.99
  StoreKit unlock.
