# Kaleidoscope Social + Leaderboards Design

Date: 2026-06-28
Status: Design written - pending final review

## Vision

Kaleidoscope should feel like a personal puzzle cabinet first. Social features
should arrive as opt-in table invitations and score slips, not as an
account-first dashboard. The app already has a strong parchment shell, a facet
registry, and per-window game persistence. The next layer makes games easier to
resume, finish, compare, and share.

The approved direction is a staged hybrid:

1. macOS adds a shared scoring/result layer and Apple-native Game Center
   leaderboards.
2. The existing iOS companion continues the Supabase phone/profile path and adds
   friend codes/friend requests.
3. Shared models can move into a Swift package later, after the product loop is
   proven on both surfaces.

## Existing Surfaces

### macOS puzzle cabinet

Path: `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap`

The macOS app is the full puzzle cabinet. It has ready facets for Chess, Brick
Bench, Wordle, Oracle, Rubik's Cube, 2048, Lights Out, Minesweeper, Snake,
Sudoku, Sliding-15, Nonogram, and Reversi. `ContentView` owns one session object
per playable facet and wires persistence through `GamePersistenceStore`.

This surface should lead with Game Center because it is Apple-native, low
backend liability, and appropriate for standard leaderboards.

### iOS social companion

Path: `/Users/gtrktscrb/Desktop/GtrktscrBAPPDEV/mobile-development/Kaleidoscope`

The iOS app already has Supabase Swift, phone OTP sign-in, profiles, an auth
gate, a home grid, and playable 2048. Its handoff calls the next project
"friends by phone number," but the safer first social primitive should be friend
codes. Phone OTP can remain the auth mechanism without becoming contact
discovery.

This surface should lead with Supabase because custom friend codes, friend
requests, and app-specific profiles are not provided by Game Center.

## Goals

- Make the macOS app visibly more user-friendly through resume states, result
  summaries, and consistent game-end actions.
- Normalize score/result extraction across score-bearing facets.
- Add a service boundary that can support local mock results, Game Center, and
  Supabase without coupling game views to backend details.
- Add Game Center leaderboards on macOS as the first live leaderboard path.
- Add Supabase friend codes and friend requests on iOS as the first custom
  social path.
- Keep all social features optional; local play and local persistence continue
  without account setup.

## Non-Goals

- No phone contact discovery in the first implementation slice.
- No chat, direct messages, reactions, comments, groups, clans, or seasons.
- No achievement economy, streak pressure, battle pass, or analytics dashboard.
- No cross-device save sync in this spec.
- No immediate shared Swift package extraction.
- No anti-cheat system beyond idempotent score event submission and conservative
  score timing.
- No forced account gate for playing local games.

## Product Shape

### Home / Cabinet lens

Home grows toward showing what the app already remembers:

- in-progress games
- daily/featured facets
- personal bests
- recent finishes
- lightweight friend activity when social is enabled

This is implemented incrementally. The first pass adds result state and
leaderboard affordances without rebuilding Home.

### Game view standard loop

Each score-bearing facet should converge on this loop:

1. Play or resume.
2. Finish, solve, lose, or reach game over.
3. Show a result summary.
4. Offer Play again, Review board, Leaderboard, and Change game where relevant.

Do not interrupt the board immediately on completion. Result UI should be a
sheet or side slip that lets the player dismiss and review the final state.

### Friends / Hall lens

The social surface is named `Hall`, not `Friends`, so it feels like part of the
puzzle cabinet rather than a generic contacts panel. It should contain:

- display name
- my friend code
- add friend by code
- pending invitations
- friend list
- recent friend results

The copy should use invitation language: "Exchange codes" and "Add to table,"
not "sync contacts."

## Architecture

### Shared score types

Create value types in the macOS app first under `Sources/Model`:

```swift
struct GameResult: Codable, Hashable, Identifiable {
    var id: UUID
    var facetID: String
    var mode: String
    var outcome: GameOutcome
    var score: Int64?
    var durationSeconds: Int?
    var moveCount: Int?
    var completedAt: Date
    var metadata: [String: String]
}

enum GameOutcome: String, Codable, Hashable {
    case won
    case lost
    case solved
    case completed
    case abandoned
}

struct LeaderboardEntry: Codable, Hashable, Identifiable {
    var id: String
    var rank: Int
    var displayName: String
    var score: Int64
    var detail: String?
    var submittedAt: Date
    var scope: LeaderboardScope
}

enum LeaderboardScope: String, Codable, Hashable, CaseIterable {
    case local
    case friends
    case global
}
```

Keep these backend-neutral. They should be portable to the iOS app or a future
Swift package.

### Result extraction

Add a `GameResultExtractor` layer that converts sessions into result events.
This keeps views and backend services from knowing each game's internal model.

Initial supported facets:

- 2048: submit best score on game over or win.
- Snake: submit score on game over.
- Minesweeper: submit fastest win, with board size and mine count in metadata.
- Lights Out: submit solved puzzle using lower press count as better.
- Rubik's Cube: submit solved time and move count.
- Sudoku: submit solved completion, later time/mistake metrics.
- Sliding-15: submit solved completion.
- Nonogram: submit solved completion.
- Reversi: submit final piece differential when game over.

Chess and Wordle should not enter generic leaderboards in the first pass. Chess
needs rating or puzzle-specific modes, and Wordle has daily-answer/content
concerns.

### Service boundary

Add protocols in `Sources/Model`:

```swift
protocol LeaderboardService {
    func submit(_ result: GameResult) async throws
    func entries(facetID: String, mode: String, scope: LeaderboardScope, limit: Int) async throws -> [LeaderboardEntry]
    func personalBest(facetID: String, mode: String) async throws -> LeaderboardEntry?
}

protocol SocialService {
    func currentProfile() async throws -> SocialProfile?
    func friendCode() async throws -> String?
    func addFriend(code: String) async throws
    func friends() async throws -> [SocialProfile]
}
```

Implement a local leaderboard first so UI and tests do not depend on Game Center
or Supabase. Then add adapters:

- `GameCenterLeaderboardService` for macOS GameKit.
- `SupabaseSocialService` for iOS friend codes and friend requests.

### Game Center adapter

Game Center is appropriate for macOS leaderboards:

- Authenticate with `GKLocalPlayer.local.authenticateHandler`.
- Submit scores with App Store Connect leaderboard IDs.
- Fetch global and friends-only leaderboard entries where supported.
- Present a Game Center access point or dashboard affordance.

Leaderboard IDs must be stable and cannot be treated as casual strings. Use a
mapping table, for example:

| Facet | Mode | Game Center leaderboard ID |
| --- | --- | --- |
| 2048 | standard | `kaleidoscope.2048.best` |
| Snake | standard | `kaleidoscope.snake.best` |
| Minesweeper | beginner | `kaleidoscope.minesweeper.beginner.time` |
| Lights Out | standard | `kaleidoscope.lightsout.presses` |
| Rubik's Cube | standard | `kaleidoscope.rubiks.time` |

For games where lower is better, either configure Game Center ordering
appropriately in App Store Connect or normalize values carefully in the adapter.

References:

- Apple GameKit overview: `https://developer.apple.com/documentation/gamekit`
- Game Center leaderboards: `https://developer.apple.com/help/app-store-connect/configure-game-center/manage-leaderboards/`
- Game Center privacy: `https://developer.apple.com/documentation/gamekit/protecting-the-player-s-privacy-using-scoped-identifiers`

### Supabase social adapter

The iOS project already uses Supabase Swift. Extend it with friend-code-first
social tables rather than phone lookup.

Minimum schema:

```sql
create extension if not exists citext;
create extension if not exists pgcrypto;

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  public_id uuid not null unique default gen_random_uuid(),
  display_name text not null check (char_length(display_name) between 1 and 32),
  avatar_seed text,
  is_discoverable boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.friend_codes (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  code citext not null unique,
  rotated_at timestamptz not null default now()
);

create type public.friendship_status as enum ('pending', 'accepted', 'blocked');

create table public.friendships (
  requester_id uuid not null references public.profiles(user_id) on delete cascade,
  addressee_id uuid not null references public.profiles(user_id) on delete cascade,
  status public.friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create table public.score_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  facet_id text not null,
  mode text not null default 'standard',
  score bigint not null,
  client_event_id uuid not null,
  played_at timestamptz not null,
  submitted_at timestamptz not null default now(),
  metadata jsonb not null default '{}',
  unique (user_id, client_event_id)
);
```

Use RPCs for code generation and friendship mutations:

- `create_or_rotate_friend_code()`
- `send_friend_request_by_code(code)`
- `accept_friend_request(requester_id)`
- `leaderboard(facet_id, mode, scope, limit, offset)`

RLS policy direction:

- Profiles are editable only by their owner.
- Friend codes are selectable only by exact code lookup.
- Friendships are visible only to participants.
- Score events are insert-only by the owner.
- Friend leaderboards are returned through RPCs, not broad client-side table
  reads.

References:

- Supabase Swift: `https://supabase.com/docs/reference/swift/installing`
- Supabase SwiftUI tutorial: `https://supabase.com/docs/guides/getting-started/tutorials/with-swift`
- Supabase RLS: `https://supabase.com/docs/guides/database/postgres/row-level-security`
- Supabase anonymous users: `https://supabase.com/docs/guides/auth/auth-anonymous`
- Supabase phone login: `https://supabase.com/docs/guides/auth/phone-login`

## UI Design

### Visual direction

Social UI should look like score slips and table cards inside the existing
parchment cabinet:

- Use `GameHeader`, `StatBadge`, `.kaleidoCard`, and `FacetBackdrop`.
- Use trophy, person-plus, and envelope icons sparingly.
- Avoid a dense admin dashboard look.
- Keep controls keyboard reachable and readable in all `KaleidoPaper` modes.

### Per-game leaderboard overlay

Add a compact trophy action to score-bearing game headers. The overlay shows:

- personal best
- current result, if opened from a result sheet
- friends tab
- global tab when Game Center is authenticated
- empty state with "Exchange codes" when no friends exist

### Result sheet

Every supported game should produce a result sheet with:

- outcome
- score/time/moves
- personal best comparison
- submission status
- Play again
- Leaderboard
- Change game

### Hall lens

Add a sidebar utility item or Home card named `Hall`. The first iOS version
ships this before macOS:

- My code
- Add code
- Pending
- Friends
- Recent results
- Privacy/social settings

## Implementation Slices

### Slice 0: Restore green baseline

Fix the stale Brick Controls test expectation. Current code intentionally maps
Tab to `lower` and Page Down to `redo`; `BrickControlsTests` still expects
Tab-to-redo.

### Slice 1: macOS local scoring and UI

- Add shared result/leaderboard value types.
- Add `LocalLeaderboardService`.
- Add result extraction tests for supported facets.
- Add a reusable leaderboard overlay.
- Add result sheets to 2048 and Snake as proof of the loop.

### Slice 2: macOS Game Center

- Add GameKit capability/project configuration.
- Add `GameCenterService` and `GameCenterLeaderboardService`.
- Authenticate optionally from app startup or first leaderboard use.
- Submit 2048 and Snake scores first.
- Fetch and render global/friends entries when available.

### Slice 3: iOS friend codes

- Extend the iOS Supabase SQL setup with friend code and friendship tables.
- Add RPC wrappers in the iOS backend layer.
- Add Friends/Hall screen.
- Add add-by-code, pending requests, accept/reject, and friend list.

### Slice 4: Shared extraction

Once both apps prove the loop, move shared game result DTOs and any shared 2048
scoring logic into a Swift package.

## Testing

macOS:

- `BrickControlsTests` for corrected defaults.
- `GameResultExtractorTests` for every supported session.
- `LocalLeaderboardServiceTests` for best score, lower-is-better modes, and
  idempotent duplicate handling.
- UI-adjacent tests where possible for supported facet IDs and leaderboard mode
  mapping.
- Full gate:

```bash
xcodegen generate
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test
```

iOS:

- Existing 2048 tests stay green.
- Add backend mapper tests where network-free.
- Add SQL/RLS review checklist in `docs/SETUP.md` or a migration doc.
- Build gate:

```bash
xcodegen generate
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Risks

- Game Center requires App Store Connect leaderboard setup before real global
  boards work.
- Game Center friend lists are not the same as Kaleidoscope friend codes.
- Supabase phone lookup is privacy-sensitive; defer contact discovery.
- Client-submitted scores are forgeable; accept this for MVP or add
  game-specific validation later.
- The current macOS app directory is untracked from the top-level git root, so
  commits/staging must be done deliberately.
- Adding a shared Swift package too early would slow the product loop.

## Implementation Defaults

- User-facing social lens name: `Hall`.
- First Game Center leaderboard IDs: `kaleidoscope.2048.best`,
  `kaleidoscope.snake.best`, `kaleidoscope.minesweeper.beginner.time`,
  `kaleidoscope.lightsout.presses`, and `kaleidoscope.rubiks.time`.
- macOS does not add Supabase sign-in in the first social release. It waits until
  after the iOS friend-code flow works.
