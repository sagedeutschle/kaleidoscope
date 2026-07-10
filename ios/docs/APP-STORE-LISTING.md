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

- `15 classic games, one lens` (26)
- alt: `Daily puzzles and classics` (26)

## Promotional text (170 char max — editable anytime without review)

`Fifteen timeless games in one beautiful app — Wordgame, 2048, Chess, Solitaire, Minesweeper and more. Free to play. New games added often.`

## Keywords (100 char max, comma-separated, no spaces)

`wordgame,2048,sudoku,chess,solitaire,minesweeper,snake,nonogram,reversi,checkers,puzzle,classic,games`

## Description

Prismet is a calm, beautiful home for the games you already love — fifteen
classics in one app, wrapped in a warm parchment design you can read in any light.

GAMES INCLUDED
• Wordgame — guess the five-letter word
• 2048 — slide and combine to the big tile
• Sudoku — with row, column, and box highlights
• Minesweeper — three looks: Modern, Classic '97, and Cyberpunk
• Snake — smooth, swipe-to-steer
• Chess — play a built-in AI opponent
• Solitaire (Klondike)
• Rubik's Cube — a real 3D cube you can spin
• Lights Out, Sliding Puzzle, Nonogram
• Reversi, Checkers, Connect Four — pass-and-play with a friend
• The Oracle — a daily decree, just for fun

DESIGNED TO FEEL GOOD
• No pop-ups, no interstitials, no paywalls
• Haptics and smooth animation on every move
• Light, parchment, and dark reading themes
• Game Center support for friends and leaderboards

Free to play. More games and features on the way.

## What's New (version 1.1)

`Prismet is here. This update refreshes the app identity while preserving existing saves and Game Center continuity, restores the daily Wordgame feed, and brings the latest game polish, sound, haptics, online friend rooms, and launch-day stability fixes.`

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

## Screenshots (required: 6.7" and 6.5" iPhone)

Capture these screens (the Home grid is the hero):
1. Home — the category grid with the iris brand mark
2. Wordgame mid-game
3. 2048 mid-game
4. Chess board with legal-move dots
5. Minesweeper in a bold skin (Classic '97 or Cyberpunk)
6. Solitaire or the Rubik's 3D cube

> I can generate these from the simulator once the Screen-Recording grant is on, or
> you can screenshot on the phone (cleanest, real device frame).

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

## ★ POLISHED FOR BUILD 11 — 2026-07-04 (Agent-Design)
Refreshed to reflect the CURRENT app (build 11): ~18 games incl. the new ones (Gomoku, Spider, Crazy 8, Sea Battle), online head-to-head, real sound + haptics, and the material-identity redesigns. Paste these when the version is editable.

**Subtitle (≤30):** `20+ classic games, one lens`

**Promotional text (≤170, editable anytime):**
`Twenty+ timeless games in one calm, beautiful app - Chess, 2048, Sudoku, Sea Battle, Gomoku, Solitaire, Minesweeper and more. Free, no ads, play a friend.`

**Keywords (≤100):** `2048,sudoku,chess,solitaire,minesweeper,snake,gomoku,checkers,connect four,battleship,word,puzzle` (97 chars)

**Description:**
Prismet is a calm, beautiful home for the games you already love - over eighteen classics in one app, each with its own hand-crafted look, plus a 3D brick builder and a daily Oracle. No ads, no pop-ups, no paywalls.

GAMES INCLUDED
- Chess - a real study board with a built-in engine, 2D or 3D
- 2048, Sudoku, Minesweeper (up to 30x30), Snake, Nonogram, Lights Out, Sliding Puzzle
- Solitaire (Klondike) and Spider
- Sea Battle (Battleship), Connect Four, Reversi, Checkers, Gomoku - play the computer, pass-and-play, or a friend online
- Crazy 8s - the classic card game
- Wordgame - guess the five-letter word each day
- Rubik's Cube - a real 3D cube you can spin
- The Oracle and a live Debt Clock, just for fun

DESIGNED TO FEEL GOOD
- Every game has a distinctive material identity - felt tables, walnut trays, neon arcades, newsprint puzzles
- Real sound effects and haptics on every move (toggle in Settings)
- Light, parchment, and dark reading themes
- Game Center sign-in, friends, and leaderboards - no account, no login wall
- Play head-to-head online with a friend by room code

Free to play. More games and features on the way.

**What's New (first release):**
`Welcome to Prismet - over eighteen beautifully crafted classic games in one calm app. Play the computer, pass-and-play, or challenge a friend online. Real sound, haptics, and three reading themes. No ads, no login wall. More games coming soon.`

**Screenshots (6.9in, 1320x2868, staged):** checkers (red/black), sea battle, chess study table, 2048 walnut, snake neon, sudoku newspaper, solitaire baize — in scratchpad/appstore/. Oracle dropped (dynamic political content).

---

## ★ HISTORICAL 1.0.1 SHIP RUNBOOK — pre-launch fork, do not use for v1.1
Chosen path: **ride build 8, ship build 11 as 1.0.1.** Apple blocks creating 1.0.1 until v1.0 is out of `WAITING_FOR_REVIEW` (approved/released or rejected). Assets staged: metadata (the "POLISHED FOR BUILD 11" section above) + 7 screenshots in `docs/appstore-screenshots-1.0.1/` (6.9in 1320x2868). ASC helper: `docs/asc-helper.py` (openssl-ES256 JWT; `import` it and call `api(method,path,body)`). Ids: app 6785993194, build 11 id `82554947-3f20-469b-a8db-7f0b1b44ce54`, en-US loc template.

STEPS (once v1.0 is Ready for Sale / Pending Developer Release, or Rejected):
1. Create version: `POST /v1/appStoreVersions` {attributes:{platform:IOS, versionString:"1.0.1"}, relationships:{app:6785993194}} → new version id.
2. Attach build 11: `PATCH /v1/appStoreVersions/{newId}/relationships/build` {data:{type:builds, id:"82554947-3f20-469b-a8db-7f0b1b44ce54"}}.
3. Metadata: `PATCH /v1/appStoreVersionLocalizations/{en-US loc id of new ver}` {attributes:{description, keywords, promotionalText, whatsNew}} from the POLISHED section.
4. Screenshots (6.9in APP_IPHONE_67 set): reserve `POST /v1/appScreenshots` (fileName,fileSize,appScreenshotSet rel) → PUT bytes to returned uploadOperations url(s) → `PATCH /v1/appScreenshots/{id}` {uploaded:true, sourceFileChecksum:<md5>}. (Delete old shots first.) NOTE: this multi-step upload is UNTESTED — verify interactively.
5. App Privacy: publish in ASC UI (human step, can't API).
6. Submit: `POST /v1/reviewSubmissions` + items → PATCH submitted:true.
