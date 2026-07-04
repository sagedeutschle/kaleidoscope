# Remove Ads Codes

Kaleidoscope now has one persisted no-ads entitlement:

- StoreKit purchase: `com.spocksclub.kaleidoscope.removeads`
- Private tester/family code redemption

The app never stores the raw tester codes. It stores SHA-256 hashes in
`KaleidoscopeAdUnlockCodeHashes`, and `AdEntitlementStore` hashes whatever the
tester types before comparing.

## Generate A Code Hash

Pick a code that only you know, then hash it:

```bash
scripts/hash-ad-unlock-code.swift "SAGE-FAMILY-2026"
```

The script prints:

```text
SAGE-FAMILY-2026 <64-character-sha256-hash>
```

Keep `SAGE-FAMILY-2026` private. Paste only the hash into `project.yml`:

```yaml
KaleidoscopeAdUnlockCodeHashes:
  - <64-character-sha256-hash>
```

Then regenerate and test:

```bash
xcodegen generate
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  test -only-testing:KaleidoscopeTests/AdEntitlementStoreTests
```

## App Store Connect Setup

Create a non-consumable In-App Purchase:

- Product ID: `com.spocksclub.kaleidoscope.removeads`
- Price: `$4.99`
- Display name: `Remove Ads`

Apple's official App Store Connect help says consumable/non-consumable IAPs are
created under the app's In-App Purchases area with a reference name and product
ID. Apple also supports offer codes for discounted or free access to IAPs after
the product is approved.

Useful Apple docs:

- https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/
- https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-offer-codes-for-in-app-purchases

## Security Note

Hashed in-app codes are enough for friends/family testing, but they are still
client-side checks. A determined attacker could reverse engineer the app. If this
ever becomes a real abuse problem, move code validation to Supabase or switch to
Apple-managed offer codes only.
