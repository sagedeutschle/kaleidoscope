-- Kaleidoscope security hardening: server-side rate limits and payload caps.
-- Run in Supabase SQL Editor after reconciling the live schema with this file.
--
-- Why this exists:
-- - Mobile anon keys are public client credentials, not secrets.
-- - RLS decides who can write.
-- - These triggers slow authenticated/anonymous-auth users who spam writes.
--
-- Launch-safety rule:
-- - CHECK constraints below are added as NOT VALID so existing user rows are not
--   rewritten, deleted, or made into a migration blocker. PostgreSQL still
--   enforces NOT VALID CHECK constraints for new inserts and updates.

create table if not exists public.api_rate_limits (
    user_id      uuid not null,
    action       text not null,
    window_start timestamptz not null,
    event_count  integer not null default 1,
    primary key (user_id, action)
);

alter table public.api_rate_limits enable row level security;

drop policy if exists "rate limit rows are private" on public.api_rate_limits;
create policy "rate limit rows are private"
    on public.api_rate_limits for select
    using (false);

create or replace function public.enforce_rate_limit(
    action_name text,
    max_events integer,
    window_seconds integer
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    uid uuid := auth.uid();
    current_window timestamptz;
    current_count integer;
begin
    if uid is null then
        raise exception 'rate limit requires authenticated user';
    end if;

    if max_events < 1 or window_seconds < 1 then
        raise exception 'invalid rate limit';
    end if;

    insert into public.api_rate_limits (user_id, action, window_start, event_count)
    values (uid, action_name, now(), 1)
    on conflict (user_id, action) do update
      set
        window_start = case
            when public.api_rate_limits.window_start < now() - make_interval(secs => window_seconds)
            then now()
            else public.api_rate_limits.window_start
        end,
        event_count = case
            when public.api_rate_limits.window_start < now() - make_interval(secs => window_seconds)
            then 1
            else public.api_rate_limits.event_count + 1
        end
    returning window_start, event_count into current_window, current_count;

    if current_count > max_events then
        raise exception 'rate limit exceeded for %', action_name
            using errcode = 'P0001';
    end if;
end;
$$;

revoke all on function public.enforce_rate_limit(text, integer, integer) from public;
grant execute on function public.enforce_rate_limit(text, integer, integer) to authenticated;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

revoke all on function public.touch_updated_at() from public;

create or replace function public.guard_profile_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.enforce_rate_limit('profile_write', 4, 300);
    return new;
end;
$$;

drop trigger if exists profiles_rate_limit on public.profiles;
create trigger profiles_rate_limit
    before insert or update on public.profiles
    for each row execute function public.guard_profile_write();

create or replace function public.guard_game_save_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.enforce_rate_limit('game_save_write', 60, 60);
    return new;
end;
$$;

drop trigger if exists game_saves_rate_limit on public.game_saves;
create trigger game_saves_rate_limit
    before insert or update on public.game_saves
    for each row execute function public.guard_game_save_write();

create or replace function public.guard_multiplayer_match_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.enforce_rate_limit('multiplayer_match_write', 120, 60);
    return new;
end;
$$;

drop trigger if exists multiplayer_matches_rate_limit on public.multiplayer_matches;
create trigger multiplayer_matches_rate_limit
    before insert or update on public.multiplayer_matches
    for each row execute function public.guard_multiplayer_match_write();

drop trigger if exists game_saves_touch_updated_at on public.game_saves;
create trigger game_saves_touch_updated_at
    before update on public.game_saves
    for each row execute function public.touch_updated_at();

drop trigger if exists multiplayer_matches_touch_updated_at on public.multiplayer_matches;
create trigger multiplayer_matches_touch_updated_at
    before update on public.multiplayer_matches
    for each row execute function public.touch_updated_at();

do $$
begin
    if to_regclass('public.leaderboard_scores') is not null then
        create or replace function public.guard_leaderboard_score_write()
        returns trigger
        language plpgsql
        security definer
        set search_path = public
        as $fn$
        begin
            perform public.enforce_rate_limit('leaderboard_score_write', 20, 60);
            return new;
        end;
        $fn$;

        drop trigger if exists leaderboard_scores_rate_limit on public.leaderboard_scores;
        create trigger leaderboard_scores_rate_limit
            before insert or update on public.leaderboard_scores
            for each row execute function public.guard_leaderboard_score_write();

        if exists (
            select 1
            from information_schema.columns
            where table_schema = 'public'
              and table_name = 'leaderboard_scores'
              and column_name = 'updated_at'
        ) then
            drop trigger if exists leaderboard_scores_touch_updated_at on public.leaderboard_scores;
            create trigger leaderboard_scores_touch_updated_at
                before update on public.leaderboard_scores
                for each row execute function public.touch_updated_at();
        end if;
    end if;
end;
$$;

do $$
begin
    if not exists (
        select 1 from pg_constraint where conname = 'profiles_public_fields_shape'
    ) then
        alter table public.profiles
            add constraint profiles_public_fields_shape check (
                length(display_name) between 1 and 26
                and avatar_color ~ '^[0-9A-Fa-f]{6}$'
                and length(avatar_emoji) between 1 and 8
            ) not valid;
    end if;

    if not exists (
        select 1 from pg_constraint where conname = 'game_saves_payload_size'
    ) then
        alter table public.game_saves
            add constraint game_saves_payload_size check (
                length(state_json) <= 200000
                and length(game_id) <= 64
                and source_platform in ('ios', 'macos')
            ) not valid;
    end if;

    if not exists (
        select 1 from pg_constraint where conname = 'multiplayer_matches_payload_size'
    ) then
        alter table public.multiplayer_matches
            add constraint multiplayer_matches_payload_size check (
                length(state_json) <= 200000
                and length(game_id) <= 64
                and status in ('waiting', 'active', 'finished', 'cancelled')
            ) not valid;
    end if;

    if to_regclass('public.leaderboard_scores') is not null
       and not exists (
           select 1 from pg_constraint where conname = 'leaderboard_scores_public_fields_shape'
       ) then
        alter table public.leaderboard_scores
            add constraint leaderboard_scores_public_fields_shape check (
                length(game_id) <= 80
                and length(display_name) between 1 and 26
                and avatar_color ~ '^[0-9A-Fa-f]{6}$'
                and length(avatar_emoji) between 1 and 8
            ) not valid;
    end if;
end;
$$;

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'multiplayer_matches'
          and column_name = 'room_code'
    ) and not exists (
        select 1 from pg_constraint where conname = 'multiplayer_matches_room_code_shape'
    ) then
        execute $ddl$
            alter table public.multiplayer_matches
                add constraint multiplayer_matches_room_code_shape check (
                    room_code is null
                    or room_code ~ '^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{4,8}$'
                ) not valid
        $ddl$;
    end if;

    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'multiplayer_matches'
          and column_name = 'current_turn_user_id'
    ) and not exists (
        select 1 from pg_constraint where conname = 'multiplayer_matches_participant_turn'
    ) then
        execute $ddl$
            alter table public.multiplayer_matches
                add constraint multiplayer_matches_participant_turn check (
                    (guest_user_id is null or host_user_id <> guest_user_id)
                    and (
                        current_turn_user_id is null
                        or current_turn_user_id = host_user_id
                        or current_turn_user_id = guest_user_id
                    )
                    and (
                        winner_user_id is null
                        or winner_user_id = host_user_id
                        or winner_user_id = guest_user_id
                    )
                ) not valid
        $ddl$;
    end if;

    if to_regclass('public.leaderboard_scores') is not null
       and exists (
           select 1
           from information_schema.columns
           where table_schema = 'public'
             and table_name = 'leaderboard_scores'
             and column_name = 'score'
       ) and not exists (
           select 1 from pg_constraint where conname = 'leaderboard_scores_score_bounds'
       ) then
        execute $ddl$
            alter table public.leaderboard_scores
                add constraint leaderboard_scores_score_bounds check (
                    score >= 0 and score <= 1000000000
                ) not valid
        $ddl$;
    end if;
end;
$$;
