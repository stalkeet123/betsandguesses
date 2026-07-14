begin;

alter table public.rooms
  add column if not exists state_version bigint not null default 0,
  add column if not exists phase_started_at timestamptz,
  add column if not exists phase_ends_at timestamptz;

alter table public.bets
  add column if not exists client_action_id text;

-- A player can only own one answer in a round. Keeping this invariant in the
-- database makes retries and reconnects idempotent on every client.
delete from public.guesses older
using public.guesses newer
where older.room_id = newer.room_id
  and older.round_number = newer.round_number
  and older.player_id = newer.player_id
  and older.id::text > newer.id::text;

create unique index if not exists guesses_room_round_player_unique
  on public.guesses (room_id, round_number, player_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'bets_client_action_id_key'
  ) then
    alter table public.bets
      add constraint bets_client_action_id_key unique (client_action_id);
  end if;
end $$;

create index if not exists idx_bets_room_round
  on public.bets (room_id, round_number);

create index if not exists idx_guesses_room_round
  on public.guesses (room_id, round_number);

create index if not exists idx_players_room
  on public.players (room_id);

create or replace function public.game_server_time()
returns timestamptz
language sql
volatile
security definer
set search_path = public
as $$
  select clock_timestamp();
$$;

create or replace function public.transition_game_phase(
  p_room_id uuid,
  p_phase text,
  p_expected_version bigint default null,
  p_round integer default null,
  p_question_id uuid default null,
  p_duration_seconds integer default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_room jsonb;
begin
  update public.rooms
  set
    round_phase = p_phase,
    current_round = coalesce(p_round, current_round),
    current_question_id = coalesce(p_question_id, current_question_id),
    state_version = state_version + 1,
    phase_started_at = v_now,
    phase_ends_at = case
      when p_duration_seconds is null then null
      else v_now + make_interval(secs => p_duration_seconds)
    end
  where id = p_room_id
    and (p_expected_version is null or state_version = p_expected_version)
  returning to_jsonb(public.rooms.*) into v_room;

  if v_room is null then
    raise exception 'stale game state for room %', p_room_id
      using errcode = '40001';
  end if;

  return v_room;
end;
$$;

create or replace function public.settle_game_round(
  p_room_id uuid,
  p_expected_version bigint,
  p_round integer,
  p_winning_guess_id uuid,
  p_scores jsonb,
  p_duration_seconds integer default 6
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_room jsonb;
begin
  update public.rooms
  set
    round_phase = 'revealAnswer',
    state_version = state_version + 1,
    phase_started_at = v_now,
    phase_ends_at = v_now + make_interval(secs => p_duration_seconds)
  where id = p_room_id
    and current_round = p_round
    and round_phase = 'betting'
    and state_version = p_expected_version
  returning to_jsonb(public.rooms.*) into v_room;

  if v_room is null then
    raise exception 'stale game state for room %', p_room_id
      using errcode = '40001';
  end if;

  update public.guesses
  set is_winner = (id = p_winning_guess_id)
  where room_id = p_room_id
    and round_number = p_round;

  update public.players
  set score = (p_scores ->> id::text)::integer
  where room_id = p_room_id
    and p_scores ? id::text;

  return v_room;
end;
$$;

create or replace function public.finish_game(
  p_room_id uuid,
  p_expected_version bigint
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_room jsonb;
begin
  update public.rooms
  set
    status = 'finished',
    round_phase = 'idle',
    state_version = state_version + 1,
    phase_started_at = clock_timestamp(),
    phase_ends_at = null
  where id = p_room_id
    and state_version = p_expected_version
  returning to_jsonb(public.rooms.*) into v_room;

  if v_room is null then
    raise exception 'stale game state for room %', p_room_id
      using errcode = '40001';
  end if;

  return v_room;
end;
$$;

grant execute on function public.game_server_time() to anon, authenticated;
grant execute on function public.transition_game_phase(
  uuid,
  text,
  bigint,
  integer,
  uuid,
  integer
) to anon, authenticated;
grant execute on function public.settle_game_round(
  uuid,
  bigint,
  integer,
  uuid,
  jsonb,
  integer
) to anon, authenticated;
grant execute on function public.finish_game(uuid, bigint)
  to anon, authenticated;

commit;
