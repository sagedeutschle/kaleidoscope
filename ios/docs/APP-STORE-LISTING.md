# Prismet — App Store Connect listing kit

Everything you paste into App Store Connect for the next iOS update. Drafts —
tweak voice to taste.

## Current submission target

- **Version:** 1.1
- **Build:** 13
- **ASC status:** `WAITING_FOR_REVIEW` (submitted 2026-07-10T01:57:16Z)
- **ASC ids:** version `88c88227-ddc2-4766-a966-cb2d1d703363`, build
  `4e231958-05cc-4cc2-87d1-6d5123ccf093`, review submission
  `ba52e847-a300-415f-a111-e0e983ddc443`
- **Public baseline:** v1.0 build 12 is already live on the App Store.
- **Name strategy:** in-app/project name is Prismet. The public App Store name can
  remain `Kaleidescope` for the transition if the rename is not ready in ASC.

## App name (30 char max)

- **First choice:** `Prismet` (12)
- "Prismet" is a common word and **may be taken** on the App Store. Backups
  that keep the brand and stay unique:
  - `Prismet Games` (18)
  - `Prismet Arcade` (19)
  - `Prismet: Classics` (22)

> Check availability in App Store Connect → New App → the name field tells you if it's free.

## Subtitle (30 char max)

- `20+ classic games, one lens` (26)
- alt: `Daily puzzles and classics` (26)

## Promotional text (170 char max — editable anytime without review)

`Twenty+ timeless games in one calm app: Wordgame, Chess, 2048, Sudoku, Sea Battle, Solitaire, Snake, and more. Free to play, no account required.`

## Keywords (100 char max, comma-separated, no spaces)

`wordgame,2048,sudoku,chess,solitaire,minesweeper,snake,nonogram,seabattle,gomoku,spider,puzzle`

## Description

Kaleidescope is a calm home for classic games and daily puzzles. Open one app
and jump into Wordgame, Chess, 2048, Sudoku, Solitaire, Snake, Minesweeper, Sea
Battle, and more - each with its own hand-crafted look.

GAMES INCLUDED
• Daily Wordgame - guess the five-letter word
• 2048 - slide, merge, shuffle, and chase your best score
• Sudoku - clean number grids with helpful highlights
• Minesweeper - classic boards, custom sizes, and bold visual styles
• Snake - smooth swipe steering with a modern arcade feel
• Chess - play a built-in opponent and tune the board style
• Solitaire and Spider - classic cards on rich table surfaces
• Sea Battle, Checkers, Reversi, Connect Four, and Gomoku - play solo, pass-and-play, or with a friend where supported
• Crazy 8 - a quick classic card game
• Rubik's Cube - a real 3D cube you can spin
• Lights Out, Sliding Puzzle, and Nonogram - fast puzzle staples
• Brick Bench - build with 3D bricks
• Bonus lenses including Oracle, Debt Clock, and Steam Rewind

DESIGNED TO FEEL GOOD
• Quick sessions, clean controls, and distinctive game styles
• Sound, haptics, and smooth animation on every move
• Light, parchment, and dark reading themes
• Game Center support for friends and leaderboards
• No account required to start playing

Free to play. More games and features on the way.

## What's New (version 1.1)

`This update refreshes Kaleidescope while preserving existing saves and Game Center continuity, restores the daily Wordgame feed, and brings the latest game polish, sound, haptics, online friend rooms, and launch-day stability fixes.`

## What's New draft (version 1.2 / build 14)

`This update makes Kaleidescope easier to share with friends and family, tightens tester-device deployment, keeps online friend rooms resilient, and rolls in build/test warning cleanup across iPhone, iPad, and Mac.`

## Category

- **Primary:** Games → Board (or Games → Puzzle)
- **Secondary:** Games → Family

## Age rating answers (target: 10+)

In the App Store Connect questionnaire, answer **None / No** to everything EXCEPT:
- **Cartoon or Fantasy Violence:** *Infrequent/Mild* — (the Chess/Checkers "capture" framing + Minesweeper mines). If you prefer a clean 4+, answer None here and it'll likely rate 4+; choose based on how you want it positioned. To land on **10+**, mild fantasy violence = Infrequent/Mild is the usual lever.
- Everything else (realistic violence, sexual content, profanity, drugs, gambling, horror): **None**.
- **Unrestricted web access:** No. **Gambling:** No.

## App Privacy ("nutrition label") answers

For the current review-safe build, phone sign-in and visible ads are disabled. Do **not**
declare phone-number collection or AdMob advertising identifiers unless those features
are re-enabled before submission.

Likely current data types:
- **Name** (Game Center display name / profile display name) — App Functionality. Linked: Yes. Tracking: No.
- **User Content** (avatar/profile choice, local game/profile data) — App Functionality. Linked: Yes. Tracking: No.

When real AdMob IDs are enabled later, revisit this section and the IDFA/ATT answers before submitting that build.

## URLs

- **Privacy Policy URL:** host `docs/PRIVACY-POLICY.md` (as HTML) somewhere public — e.g.
  GitHub Pages, or a one-page site. **Required.**
- **Support URL:** a simple page or even a mailto landing page. Could be the same site.
- **Marketing URL:** optional.
- Support contact email: `artists@deutschleartistry.com`

## Screenshots (current v14 pack)

Apple accepts 1-10 `.png`, `.jpg`, or `.jpeg` screenshots per device family. The
current staged iPhone set is the highest-resolution 6.9" portrait size
(`1320x2868`), which App Store Connect can scale down for smaller iPhone displays.
Use these for the next editable App Store version; the currently submitted v1.1 is
`WAITING_FOR_REVIEW`, so screenshots may need to wait for the next version/editable
state if ASC keeps the media locked.

Final App Store-ready PNGs:
1. `ios/docs/appstore-screenshots-v14/final/01_home.png`
2. `ios/docs/appstore-screenshots-v14/final/02_wordgame.png`
3. `ios/docs/appstore-screenshots-v14/final/03_chess.png`
4. `ios/docs/appstore-screenshots-v14/final/04_seabattle.png`
5. `ios/docs/appstore-screenshots-v14/final/05_2048.png`
6. `ios/docs/appstore-screenshots-v14/final/06_solitaire.png`
7. `ios/docs/appstore-screenshots-v14/final/07_sudoku.png`

Raw simulator captures live beside them in `ios/docs/appstore-screenshots-v14/`.
Regenerate the final framed set with:

```sh
python3 ios/scripts/generate-appstore-screenshots.py
```

The older `ios/docs/appstore-screenshots-1.0.1/` pack is historical only.

## In-app purchase — Remove Ads (future, disabled for v1)

The Remove Ads surface is hidden in the current v1 review build because no App Store
Connect IAP product is live yet. Re-enable this section when the IAP is ready:

- **Paid Applications Agreement** must be accepted in App Store Connect → Agreements,
  Tax, and Banking. Only the **Account Holder (Sage's dad)** can accept it.
- **Banking + tax info** must be completed there too (bank account for payouts, W-9/tax).
- **Create the IAP product** in App Store Connect → your app → In-App Purchases:
  - Type: **Non-Consumable**
  - Product ID: **`com.spocksclub.kaleidoscope.removeads`** (must match `project.yml`)
  - Price: **$4.99** (Tier 5), display name "Remove Ads", a short description + a review screenshot
  - The IAP is reviewed **with** the build, so submit it alongside v1.
- **Tester/family codes** grant the unlock for free (hashed in `PrismetAdUnlockCodeHashes`).
  App-Store-safe: you're giving the product away, not selling unlocks outside Apple's IAP.
- **App Privacy:** no new data types from the IAP itself; purchase is handled by Apple.

## Build / submission checklist

- [ ] App record created under SpocksClub (you're Admin) — confirm no pending Apple agreement (else Ben/account-holder must accept)
- [ ] **Paid Applications Agreement accepted + banking/tax filled** (Account Holder) — required before enabling the Remove Ads IAP
- [ ] **Remove Ads IAP product created** (`com.spocksclub.kaleidoscope.removeads`, non-consumable, $4.99) before re-enabling Remove Ads
- [ ] Archive a Release build, upload via Xcode Organizer / `xcodebuild archive`
- [ ] Real AdMob app id + banner unit id swapped in only when enabling ads (current review build is ads-off)
- [ ] Game Center capability confirmed in App Store Connect
- [ ] Privacy policy + support URLs live
- [ ] Screenshots uploaded
- [ ] Age rating + App Privacy answered
- [ ] Submit for review (with the IAP) — then it's Apple's 1–3 day clock

---

## ★ HISTORICAL BUILD 11 METADATA — 2026-07-04 (Agent-Design)

Retained only as a record that build 11 had a separate metadata pass. Do not
paste the old build-11 copy into App Store Connect; it used the Prismet public
name and an older game count. Use the current v14 listing sections above.

**Historical screenshots (6.9in, 1320x2868, staged):** checkers (red/black), sea battle, chess study table, 2048 walnut, snake neon, sudoku newspaper, solitaire baize - superseded by `ios/docs/appstore-screenshots-v14/final/`.

---

## ★ HISTORICAL 1.0.1 SHIP RUNBOOK — pre-launch fork, do not use for v1.1
Chosen historical path: **ride build 8, ship build 11 as 1.0.1.** This is retained
only as a record of the pre-launch fork; current state is v1.0 live, v1.1
submitted, and v1.2/build 14 in source. Assets staged at the time: retired
build-11 metadata + 7 screenshots in
`docs/appstore-screenshots-1.0.1/` (6.9in 1320x2868). ASC helper:
`docs/asc-helper.py` (openssl-ES256 JWT; `import` it and call `api(method,path,body)`).
Ids: app 6785993194, build 11 id `82554947-3f20-469b-a8db-7f0b1b44ce54`, en-US loc
template.

STEPS (once v1.0 is Ready for Sale / Pending Developer Release, or Rejected):
1. Create version: `POST /v1/appStoreVersions` {attributes:{platform:IOS, versionString:"1.0.1"}, relationships:{app:6785993194}} → new version id.
2. Attach build 11: `PATCH /v1/appStoreVersions/{newId}/relationships/build` {data:{type:builds, id:"82554947-3f20-469b-a8db-7f0b1b44ce54"}}.
3. Metadata: `PATCH /v1/appStoreVersionLocalizations/{en-US loc id of new ver}` {attributes:{description, keywords, promotionalText, whatsNew}} from the then-current retired build-11 metadata.
4. Screenshots (6.9in APP_IPHONE_67 set): reserve `POST /v1/appScreenshots` (fileName,fileSize,appScreenshotSet rel) → PUT bytes to returned uploadOperations url(s) → `PATCH /v1/appScreenshots/{id}` {uploaded:true, sourceFileChecksum:<md5>}. (Delete old shots first.) NOTE: this multi-step upload is UNTESTED — verify interactively.
5. App Privacy: publish in ASC UI (human step, can't API).
6. Submit: `POST /v1/reviewSubmissions` + items → PATCH submitted:true.
