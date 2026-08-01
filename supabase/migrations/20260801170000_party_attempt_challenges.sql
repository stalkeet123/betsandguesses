-- First-class attempt challenges:
--   FIRST TRY / SECOND / THIRD / 4-5 TRIES / DOESN'T LAND
-- A result of 0 means failure; 1..5 is the successful attempt number.

alter table public.party_challenges
  add column if not exists required_items text[] not null default '{}'::text[];

alter table public.party_challenges
  drop constraint if exists party_challenges_type_valid,
  drop constraint if exists party_challenges_type_direction_valid,
  drop constraint if exists party_challenges_bet_boundaries_valid,
  drop constraint if exists party_challenges_required_items_valid;

alter table public.party_challenges
  add constraint party_challenges_type_valid check (
    challenge_type in ('count', 'binary', 'attempt')
  ),
  add constraint party_challenges_type_direction_valid check (
    (challenge_type = 'binary' and result_direction = 'binary')
    or
    (challenge_type = 'attempt' and result_direction = 'lower')
    or
    (challenge_type = 'count' and result_direction in ('higher', 'lower'))
  ),
  add constraint party_challenges_bet_boundaries_valid check (
    (
      challenge_type = 'count'
      and bet_boundaries is not null
      and cardinality(bet_boundaries) = 4
      and bet_boundaries[1] >= 0
      and bet_boundaries[1] < bet_boundaries[2]
      and bet_boundaries[2] < bet_boundaries[3]
      and bet_boundaries[3] < bet_boundaries[4]
      and bet_boundaries[4] <= max_result
    )
    or
    (
      challenge_type = 'binary'
      and bet_boundaries is null
      and max_result = 1
    )
    or
    (
      challenge_type = 'attempt'
      and bet_boundaries is null
      and max_result = 5
      and result_direction = 'lower'
    )
  ),
  add constraint party_challenges_required_items_valid check (
    cardinality(required_items) <= 5
    and array_position(required_items, null) is null
  );

comment on column public.party_challenges.required_items is
  'Ordinary items shown before betting. Empty means the challenge needs no prop.';

-- Expose required items in the private snapshot while preserving the existing
-- membership and hidden-bet logic.
do $snapshot_patch$
declare
  v_definition text;
  v_rewritten text;
begin
  select pg_get_functiondef(
    'public.get_party_snapshot_v1(uuid)'::regprocedure
  ) into v_definition;

  if v_definition ilike
     '%''required_items'', v_challenge.required_items%' then
    return;
  end if;

  v_rewritten := regexp_replace(
    v_definition,
    '(''result_direction''[[:space:]]*,[[:space:]]*v_challenge[.]result_direction[[:space:]]*,)',
    E'\\1\n        ''required_items'', to_jsonb(v_challenge.required_items),',
    'i'
  );
  if v_rewritten = v_definition then
    raise exception 'Could not add required_items to get_party_snapshot_v1';
  end if;
  execute v_rewritten;
end;
$snapshot_patch$;

-- Existing bet RPCs already understand five slots. Extend only their format
-- guard and preserve all ownership, idempotency, deadline, and no-op behavior.
do $bet_rpc_patch$
declare
  v_function regprocedure;
  v_definition text;
  v_rewritten text;
begin
  foreach v_function in array array[
    'public.place_party_bet_v1(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure,
    'public.move_party_bet_v1(uuid,uuid,integer,double precision,double precision)'::regprocedure
  ]
  loop
    select pg_get_functiondef(v_function) into v_definition;

    if v_definition ilike '%(''count'', ''attempt'')%' then
      continue;
    end if;

    v_rewritten := replace(
      v_definition,
      'v_challenge.challenge_type = ''count''',
      'v_challenge.challenge_type in (''count'', ''attempt'')'
    );
    if v_rewritten = v_definition then
      raise exception 'Could not extend attempt validation in %', v_function;
    end if;
    execute v_rewritten;
  end loop;
end;
$bet_rpc_patch$;

-- The host may replace an unavailable challenge while betting is still open.
-- Existing bets are cleared because they belong to the old challenge, and the
-- full short betting window restarts for every client.
create or replace function public.reroll_party_challenge_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_host public.players%rowtype;
  v_challenge_id uuid;
  v_deadline timestamptz;
begin
  select * into v_room
  from public.rooms where id = p_room_id for update;

  select * into v_host
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_host
    and is_connected
  order by joined_at
  limit 1;
  if v_host.id is null then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;

  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at <= statement_timestamp()) then
    raise exception using errcode = '40001',
      message = 'Challenge can only be changed during betting';
  end if;

  select challenge.id into v_challenge_id
  from public.party_challenges challenge
  where challenge.enabled
    and challenge.id <> v_round.challenge_id
    and not exists (
      select 1
      from public.party_rounds previous_round
      where previous_round.room_id = p_room_id
        and previous_round.challenge_id = challenge.id
    )
  order by random()
  limit 1;

  if v_challenge_id is null then
    select challenge.id into v_challenge_id
    from public.party_challenges challenge
    where challenge.enabled
      and challenge.id <> v_round.challenge_id
    order by random()
    limit 1;
  end if;

  if v_challenge_id is null then
    raise exception using errcode = 'P0002',
      message = 'No replacement Party challenge available';
  end if;

  delete from public.party_bets
  where room_id = p_room_id
    and round_number = v_room.current_round;

  v_deadline := statement_timestamp() + interval '20 seconds';

  update public.party_rounds
  set challenge_id = v_challenge_id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = v_deadline
  where id = v_round.id;

  update public.rooms
  set phase_started_at = statement_timestamp(),
      phase_ends_at = v_deadline
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.reroll_party_challenge_v1(uuid)
from public, anon, authenticated;
grant execute on function public.reroll_party_challenge_v1(uuid)
to authenticated;
-- Attempt challenges may finish as soon as they land or exhaust five tries.
-- Other formats still require the authoritative timer to expire.
create or replace function public.open_party_result_entry_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
begin
  select * into v_room
  from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc
  limit 1;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase = 'resultEntry' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'action' then
    raise exception using errcode = '40001',
      message = 'Challenge action is not active';
  end if;
  if v_round.phase_ends_at > statement_timestamp()
     and (
       v_challenge.challenge_type <> 'attempt'
       or not v_player.is_host
     ) then
    raise exception using errcode = '40001',
      message = 'Challenge is still active';
  end if;

  update public.party_rounds
  set phase = 'resultEntry',
      phase_started_at = statement_timestamp(),
      phase_ends_at = null
  where id = v_round.id;

  update public.rooms
  set round_phase = 'partyResultEntry',
      phase_started_at = statement_timestamp(),
      phase_ends_at = null
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.open_party_result_entry_v1(uuid)
from public, anon, authenticated;
grant execute on function public.open_party_result_entry_v1(uuid)
to authenticated;
create or replace function public.submit_party_result_v1(
  p_room_id uuid,
  p_result integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_host public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_host
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_host and is_connected
  limit 1;
  if v_host.id is null then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_round.phase = 'resultConfirm' and v_round.proposed_result = p_result then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultEntry' then
    raise exception using errcode = '40001',
      message = 'Result entry is not active';
  end if;
  if (v_challenge.challenge_type = 'binary' and p_result not between 0 and 1)
     or (v_challenge.challenge_type = 'attempt'
         and p_result not between 0 and 5)
     or (v_challenge.challenge_type = 'count'
         and (p_result < 0 or p_result > v_challenge.max_result)) then
    raise exception using errcode = '22023', message = 'Invalid result';
  end if;

  update public.party_rounds
  set phase = 'resultConfirm',
      proposed_result = p_result,
      result_submitted_by = v_host.id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '5 seconds'
  where id = v_round.id;

  update public.rooms
  set round_phase = 'partyResultConfirm',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '5 seconds'
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.confirm_party_result_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_boundaries bigint[];
  v_winning_slot integer;
  v_performer_bonus integer;
begin
  select * into v_room from public.rooms where id = p_room_id for update;
  select * into v_round
  from public.party_rounds
  where room_id = p_room_id and round_number = v_room.current_round
  for update;
  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc limit 1;
  select * into v_challenge
  from public.party_challenges where id = v_round.challenge_id;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase = 'reveal' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultConfirm' or v_round.proposed_result is null then
    raise exception using errcode = '40001',
      message = 'Result confirmation is not active';
  end if;
  if v_round.phase_ends_at is null
     or v_round.phase_ends_at > statement_timestamp() then
    raise exception using errcode = '40001',
      message = 'Result review is still active';
  end if;

  if v_challenge.challenge_type = 'binary' then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := case
      when v_round.proposed_result = 1
        then v_challenge.performer_success_bonus
      else 0
    end;
  elsif v_challenge.challenge_type = 'attempt' then
    v_winning_slot := case v_round.proposed_result
      when 1 then 0
      when 2 then 1
      when 3 then 2
      when 4 then 3
      when 5 then 3
      else 4
    end;
    v_performer_bonus := case v_round.proposed_result
      when 1 then 5
      when 2 then 3
      when 3 then 2
      when 4 then 1
      when 5 then 1
      else 0
    end;
  else
    v_boundaries := public.party_board_boundaries_v1(
      p_room_id, v_room.current_round
    );
    v_winning_slot := case
      when v_round.proposed_result < v_boundaries[1] then 0
      when v_round.proposed_result < v_boundaries[2] then 1
      when v_round.proposed_result <= v_boundaries[3] then 2
      when v_round.proposed_result <= v_boundaries[4] then 3
      else 4
    end;
    v_performer_bonus := case
      when v_challenge.result_direction = 'lower'
        then (array[5, 3, 2, 1, 0])[v_winning_slot + 1]
      else (array[0, 1, 2, 3, 5])[v_winning_slot + 1]
    end;
  end if;

  update public.party_bets
  set won = slot_index = v_winning_slot
  where room_id = p_room_id and round_number = v_room.current_round;

  update public.party_scores score
  set score = greatest(
    15,
    score.score
      - coalesce((
          select sum(bet.chips)
          from public.party_bets bet
          where bet.room_id = p_room_id
            and bet.round_number = v_room.current_round
            and bet.player_id = score.player_id
        ), 0)
      + coalesce((
          select sum(
            bet.chips * case
              when v_challenge.challenge_type = 'binary' then 2
              else (array[4, 3, 2, 3, 4])[bet.slot_index + 1]
            end
          )
          from public.party_bets bet
          where bet.room_id = p_room_id
            and bet.round_number = v_room.current_round
            and bet.player_id = score.player_id
            and bet.slot_index = v_winning_slot
        ), 0)
  )
  where score.room_id = p_room_id
    and score.player_id <> v_round.performer_id;

  update public.party_scores
  set score = score + v_performer_bonus
  where room_id = p_room_id and player_id = v_round.performer_id;

  update public.party_rounds
  set phase = 'reveal',
      performer_bonus = v_performer_bonus,
      result_confirmed_by = v_player.id,
      settled_at = statement_timestamp(),
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '7 seconds'
  where id = v_round.id and settled_at is null;

  update public.rooms
  set round_phase = 'revealAnswer',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '7 seconds'
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.submit_party_result_v1(uuid, integer)
from public, anon, authenticated;
revoke all on function public.confirm_party_result_v1(uuid)
from public, anon, authenticated;
grant execute on function public.submit_party_result_v1(uuid, integer)
to authenticated;
grant execute on function public.confirm_party_result_v1(uuid)
to authenticated;

do $verification$
declare
  v_function regprocedure;
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'party_challenges'
      and column_name = 'required_items'
  ) then
    raise exception 'Party attempt migration is missing required_items';
  end if;

  if pg_get_functiondef(
    'public.get_party_snapshot_v1(uuid)'::regprocedure
  ) not ilike '%required_items%' then
    raise exception 'Party snapshot does not expose required_items';
  end if;

  foreach v_function in array array[
    'public.place_party_bet_v1(uuid,integer,integer,uuid,double precision,double precision)'::regprocedure,
    'public.move_party_bet_v1(uuid,uuid,integer,double precision,double precision)'::regprocedure
  ]
  loop
    if pg_get_functiondef(v_function) not ilike '%''attempt''%' then
      raise exception 'Party bet RPC % does not accept attempt slots', v_function;
    end if;
  end loop;
end;
$verification$;