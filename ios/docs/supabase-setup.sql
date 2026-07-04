-- Kaleidoscope — profiles table + Row-Level Security.
-- Run this in Supabase → SQL Editor (one time).

create table if not exists public.profiles (
    id            uuid primary key references auth.users (id) on delete cascade,
    phone         text unique,
    display_name  text not null,
    avatar_emoji  text not null default '🎴',
    avatar_color  text not null default 'B88A2E',
    created_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- For sub-project #1: you can read/write only your own row.
-- (Sub-project #2 will add a policy letting accepted friends read display_name/avatar.)
create policy "own profile is readable"
    on public.profiles for select
    using (auth.uid() = id);

create policy "own profile is insertable"
    on public.profiles for insert
    with check (auth.uid() = id);

create policy "own profile is updatable"
    on public.profiles for update
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- Cross-device game saves. Phone and desktop use the same row per user/game.
create table if not exists public.game_saves (
    user_id         uuid not null references auth.users (id) on delete cascade,
    game_id         text not null,
    schema_version  integer not null default 1,
    score           integer,
    state_json      text not null,
    source_platform text not null default 'ios',
    updated_at      timestamptz not null default now(),
    primary key (user_id, game_id)
);

alter table public.game_saves enable row level security;

create policy "own game saves are readable"
    on public.game_saves for select
    using (auth.uid() = user_id);

create policy "own game saves are insertable"
    on public.game_saves for insert
    with check (auth.uid() = user_id);

create policy "own game saves are updatable"
    on public.game_saves for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- Two-phone multiplayer match state. A match starts with a host, can wait for
-- a guest, then stores the same encoded snapshot format as local game saves.
create table if not exists public.multiplayer_matches (
    id                   uuid primary key default gen_random_uuid(),
    game_id              text not null,
    host_user_id         uuid not null references auth.users (id) on delete cascade,
    guest_user_id        uuid references auth.users (id) on delete set null,
    play_mode            text not null default 'onlineFriend',
    status               text not null default 'waiting',
    state_json           text not null,
    current_turn_user_id uuid references auth.users (id) on delete set null,
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now()
);

alter table public.multiplayer_matches enable row level security;

create policy "match participants can read"
    on public.multiplayer_matches for select
    using (auth.uid() = host_user_id or auth.uid() = guest_user_id);

create policy "hosts can create matches"
    on public.multiplayer_matches for insert
    with check (auth.uid() = host_user_id);

create policy "match participants can update"
    on public.multiplayer_matches for update
    using (auth.uid() = host_user_id or auth.uid() = guest_user_id)
    with check (auth.uid() = host_user_id or auth.uid() = guest_user_id);
