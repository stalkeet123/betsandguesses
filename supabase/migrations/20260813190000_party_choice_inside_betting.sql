-- Choice is resolved inside the betting scene. The performer selects one of
-- the same two visible slots while everyone else bets. Their selection remains
-- private until betting closes; no ready, action, result-entry or numpad phase
-- is created for Choice rounds.

do $snapshot_patch$
declare
  v_definition text;
  v_rewritten text;
begin
  select pg_get_functiondef(
    'public.get_party_snapshot_v1(uuid)'::regprocedure
  ) into v_definition;

  v_rewritten := replace(
    v_definition,
    $old_show$  v_show_result := v_round.phase in ('resultConfirm', 'reveal');$old_show$,
    $new_show$  v_show_result :=
    v_round.phase in ('resultConfirm', 'reveal')
    or (
      v_challenge.challenge_type = 'choice'
      and v_me.id = v_round.performer_id
      and v_round.phase = 'betting'
    );$new_show$
  );

  v_rewritten := replace(
    v_rewritten,
    $old_hide$  v_hide_choice_options :=
    v_challenge.challenge_type = 'choice'
    and v_me.id = v_round.performer_id
    and v_round.phase = 'betting';$old_hide$,
    $new_hide$  v_hide_choice_options := false;$new_hide$
  );

  if v_rewritten <> v_definition then
    execute v_rewritten;
  end if;
end;
$snapshot_patch$;

create or replace function public.begin_party_choice_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_challenge public.party_challenges%rowtype;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  select * into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if v_round.phase = 'reveal'
     and v_challenge.challenge_type = 'choice' then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_challenge.challenge_type <> 'choice' then
    raise exception using errcode = '22023', message = 'Choice challenge required';
  end if;
  if v_round.phase <> 'betting'
     or (v_round.phase_ends_at is not null
         and v_round.phase_ends_at > statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting is still active';
  end if;

  -- Stay on the betting board if the performer has not answered yet. Their
  -- eventual tap will call this function again and settle immediately.
  if v_round.proposed_result is null then
    return public.get_party_snapshot_v1(p_room_id);
  end if;

  update public.party_rounds
  set phase = 'resultConfirm',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp()
  where id = v_round.id;

  update public.rooms
  set round_phase = 'partyResultConfirm',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp()
  where id = p_room_id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  -- The zero-length internal confirmation phase is never rendered by clients.
  -- The existing authoritative settlement RPC awards the fixed Choice reward
  -- and moves the room directly into revealAnswer.
  return public.confirm_party_result_v1(p_room_id);
end;
$$;

create or replace function public.submit_party_choice_v1(
  p_room_id uuid,
  p_choice integer
)
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
  v_betting_closed boolean;
begin
  if p_choice not between 0 and 1 then
    raise exception using errcode = '22023', message = 'Invalid choice';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  select * into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  order by joined_at desc
  limit 1;

  select * into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if v_player.id is null or v_player.id <> v_round.performer_id then
    raise exception using errcode = '42501', message = 'Performer access required';
  end if;
  if v_challenge.challenge_type <> 'choice' then
    raise exception using errcode = '22023', message = 'Choice challenge required';
  end if;
  if v_round.phase = 'reveal'
     and v_round.proposed_result = p_choice then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'betting' then
    raise exception using errcode = '40001',
      message = 'Choice selection is not active';
  end if;

  v_betting_closed :=
    v_round.phase_ends_at is not null
    and v_round.phase_ends_at <= statement_timestamp();

  update public.party_rounds
  set proposed_result = p_choice,
      result_submitted_by = v_player.id
  where id = v_round.id;

  update public.party_matches
  set state_version = state_version + 1
  where room_id = p_room_id;

  if v_betting_closed then
    return public.begin_party_choice_v1(p_room_id);
  end if;

  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

revoke all on function public.begin_party_choice_v1(uuid)
from public, anon, authenticated;
grant execute on function public.begin_party_choice_v1(uuid)
to authenticated;

revoke all on function public.submit_party_choice_v1(uuid, integer)
from public, anon, authenticated;
grant execute on function public.submit_party_choice_v1(uuid, integer)
to authenticated;

do $verification$
declare
  v_snapshot text;
  v_begin text;
  v_submit text;
begin
  select pg_get_functiondef(
    'public.get_party_snapshot_v1(uuid)'::regprocedure
  ) into v_snapshot;
  select pg_get_functiondef(
    'public.begin_party_choice_v1(uuid)'::regprocedure
  ) into v_begin;
  select pg_get_functiondef(
    'public.submit_party_choice_v1(uuid,integer)'::regprocedure
  ) into v_submit;

  if position('v_hide_choice_options := false' in v_snapshot) = 0
     or position(
       'and v_me.id = v_round.performer_id' in v_snapshot
     ) = 0 then
    raise exception 'Choice snapshot privacy update is incomplete';
  end if;
  if position(
    'return public.confirm_party_result_v1(p_room_id)' in v_begin
  ) = 0 or position(
    'if v_round.proposed_result is null' in v_begin
  ) = 0 then
    raise exception 'Choice does not settle directly from betting';
  end if;
  if position('v_round.phase <> ''betting''' in v_submit) = 0
     or position('set proposed_result = p_choice' in v_submit) = 0 then
    raise exception 'Performer Choice is not stored during betting';
  end if;
  if pg_get_functiondef(
    'public.confirm_party_result_v1(uuid)'::regprocedure
  ) not ilike '%v_performer_bonus := 30%' then
    raise exception 'Choice performer reward is not 30';
  end if;
end;
$verification$;

notify pgrst, 'reload schema';
