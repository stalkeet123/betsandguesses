-- Party result review uses silent consensus:
-- everyone sees the host-entered result for six seconds, any connected
-- room member may object, and no tap is required when the result is correct.
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
    raise exception using errcode = '40001', message = 'Result entry is not active';
  end if;
  if (v_challenge.challenge_type = 'binary' and p_result not between 0 and 1)
     or (v_challenge.challenge_type = 'count'
         and (p_result < 0 or p_result > v_challenge.max_result)) then
    raise exception using errcode = '22023', message = 'Invalid result';
  end if;

  update public.party_rounds
  set phase = 'resultConfirm',
      proposed_result = p_result,
      result_submitted_by = v_host.id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '6 seconds'
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyResultConfirm',
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '6 seconds'
  where id = p_room_id;
  update public.party_matches
  set state_version = state_version + 1 where room_id = p_room_id;
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
    raise exception using errcode = '40001', message = 'Result confirmation is not active';
  end if;
  if v_round.phase_ends_at is null
     or v_round.phase_ends_at > statement_timestamp() then
    raise exception using errcode = '40001', message = 'Result review is still active';
  end if;

  if v_challenge.challenge_type = 'binary' then
    v_winning_slot := v_round.proposed_result;
    v_performer_bonus := case
      when v_round.proposed_result = 1
        then v_challenge.performer_success_bonus
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
    v_performer_bonus := (array[0, 1, 2, 3, 5])[v_winning_slot + 1];
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
  set state_version = state_version + 1 where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;

create or replace function public.dispute_party_result_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_round public.party_rounds%rowtype;
  v_player public.players%rowtype;
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
  order by joined_at desc limit 1;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_round.phase = 'resultEntry' and v_round.proposed_result is null then
    return public.get_party_snapshot_v1(p_room_id);
  end if;
  if v_round.phase <> 'resultConfirm' or v_round.settled_at is not null then
    raise exception using errcode = '40001', message = 'Result cannot be disputed';
  end if;
  if v_round.phase_ends_at is null
     or v_round.phase_ends_at <= statement_timestamp() then
    raise exception using errcode = '40001', message = 'Result review is closed';
  end if;

  update public.party_rounds
  set phase = 'resultEntry',
      proposed_result = null,
      result_submitted_by = null,
      phase_started_at = statement_timestamp(),
      phase_ends_at = null
  where id = v_round.id;
  update public.rooms
  set round_phase = 'partyResultEntry',
      phase_started_at = statement_timestamp(),
      phase_ends_at = null
  where id = p_room_id;
  update public.party_matches
  set state_version = state_version + 1 where room_id = p_room_id;
  return public.get_party_snapshot_v1(p_room_id);
end;
$$;
revoke all on function public.submit_party_result_v1(uuid, integer)
from public, anon, authenticated;
revoke all on function public.confirm_party_result_v1(uuid)
from public, anon, authenticated;
revoke all on function public.dispute_party_result_v1(uuid)
from public, anon, authenticated;

grant execute on function public.submit_party_result_v1(uuid, integer)
to authenticated;
grant execute on function public.confirm_party_result_v1(uuid)
to authenticated;
grant execute on function public.dispute_party_result_v1(uuid)
to authenticated;