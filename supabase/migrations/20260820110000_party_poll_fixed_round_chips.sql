begin;

CREATE OR REPLACE FUNCTION public.get_party_poll_snapshot_v1(p_room_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_room public.rooms%rowtype;
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_me public.players%rowtype;
  v_challenge public.party_challenges%rowtype;

  v_players jsonb := '[]'::jsonb;
  v_bets jsonb := '[]'::jsonb;
  v_scores jsonb := '{}'::jsonb;
  v_winning_player_ids jsonb := '[]'::jsonb;

  v_score integer := 0;
  v_limit integer := 40;
  v_total integer := 0;
begin
  select *
  into v_room
  from public.rooms
  where id = p_room_id;

  if not found or v_room.game_mode <> 'party' then
    raise exception using
      errcode = 'P0002',
      message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  select *
  into v_me
  from public.players p
  where p.room_id = p_room_id
    and p.auth_user_id = (select auth.uid())
  order by p.joined_at desc
  limit 1;

  if v_me.id is null then
    raise exception using
      errcode = '42501',
      message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  select *
  into v_match
  from public.party_matches
  where room_id = p_room_id;

  if v_match.room_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_MATCH_NOT_STARTED';
  end if;

  select *
  into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round;

  if v_round.id is null then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_ROUND_STATE_MISMATCH';
  end if;

  if v_round.phase not in ('betting', 'reveal') then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_POLL_INVALID_PHASE';
  end if;

  select *
  into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if v_challenge.id is null
     or v_challenge.challenge_type <> 'poll' then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_POLL_CHALLENGE_REQUIRED';
  end if;

  -- Authoritative player order comes from party_matches.turn_order.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'slot_index', ordered.position - 1,
        'id', p.id,
        'name', p.name,
        'avatar_color', p.avatar_color
      )
      order by ordered.position
    ),
    '[]'::jsonb
  )
  into v_players
  from unnest(v_match.turn_order) with ordinality
    as ordered(player_id, position)
  join public.players p
    on p.id = ordered.player_id;

  -- During betting only the caller's bets are visible.
  -- During reveal all bets become visible.
  --
  -- target_player_id is authoritative.
  -- For legacy rows we can still derive the target from slot_index.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'round_number', b.round_number,
        'player_id', b.player_id,
        'target_player_id',
          coalesce(
            b.target_player_id,
            v_match.turn_order[b.slot_index + 1]
          ),
        'chips', b.chips,
        'client_action_id', b.client_action_id,
        'position_x', b.position_x,
        'position_y', b.position_y,
        'won',
          case
            when v_round.phase = 'reveal' then b.won
            else null
          end
      )
      order by b.created_at, b.id
    ) filter (
      where v_round.phase = 'reveal'
         or b.player_id = v_me.id
    ),
    '[]'::jsonb
  )
  into v_bets
  from public.party_bets b
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round;

  select coalesce(
    jsonb_object_agg(s.player_id::text, s.score),
    '{}'::jsonb
  )
  into v_scores
  from public.party_scores s
  where s.room_id = p_room_id;

  select s.score
  into v_score
  from public.party_scores s
  where s.room_id = p_room_id
    and s.player_id = v_me.id;

  v_score := coalesce(v_score, 0);

  -- Fixed round stake capacity. PROFIT never changes wager capacity.
  v_limit := 40;

  select coalesce(sum(b.chips), 0)
  into v_total
  from public.party_bets b
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round
    and b.player_id = v_me.id;

  if v_round.phase = 'reveal' then
    select coalesce(
      jsonb_agg(w.target_player_id order by w.target_player_id::text),
      '[]'::jsonb
    )
    into v_winning_player_ids
    from (
      select distinct
        coalesce(
          b.target_player_id,
          v_match.turn_order[b.slot_index + 1]
        ) as target_player_id
      from public.party_bets b
      where b.room_id = p_room_id
        and b.round_number = v_room.current_round
        and b.won is true
        and coalesce(
          b.target_player_id,
          v_match.turn_order[b.slot_index + 1]
        ) is not null
    ) w;
  end if;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'status', v_room.status,
    'state_version', v_match.state_version,

    'round', jsonb_build_object(
      'number', v_round.round_number,
      'phase', v_round.phase,
      'phase_started_at', v_round.phase_started_at,
      'phase_ends_at', v_round.phase_ends_at,

      'question', jsonb_build_object(
        'id', v_challenge.id,
        'text', v_challenge.prompt_template,
        'rules', v_challenge.rules
      ),

      'players', v_players,
      'bets', v_bets,
      'winning_player_ids', v_winning_player_ids
    ),

    'scores', v_scores,

    'me', jsonb_build_object(
      'player_id', v_me.id,
      'score', v_score,
      'bet_limit', v_limit,
      'bet_total', v_total,
      'available_chips',
        greatest(0, v_limit - v_total)
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.place_party_poll_bet_v1(
  p_room_id uuid,
  p_target_player_id uuid,
  p_chips integer,
  p_client_action_id uuid,
  p_position_x double precision DEFAULT NULL::double precision,
  p_position_y double precision DEFAULT NULL::double precision
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_room public.rooms%rowtype;
  v_match public.party_matches%rowtype;
  v_round public.party_rounds%rowtype;
  v_me public.players%rowtype;
  v_challenge public.party_challenges%rowtype;
  v_bet public.party_bets%rowtype;

  v_target_position integer;
  v_slot_index integer;

  v_score integer := 0;
  v_limit integer := 0;
  v_total integer := 0;
  v_other_target_count integer := 0;
begin
  if p_target_player_id is null
     or p_client_action_id is null
     then
    raise exception using
      errcode = '22023',
      message = 'INVALID_BET';
  end if;

  if (
    p_position_x is not null
    and p_position_x not between 0 and 1
  ) or (
    p_position_y is not null
    and p_position_y not between 0 and 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'INVALID_BET_POSITION';
  end if;

  -- Room lock serializes command mutations for this match.
  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'party' then
    raise exception using
      errcode = 'P0002',
      message = 'PARTY_ROOM_NOT_FOUND';
  end if;

  select *
  into v_me
  from public.players p
  where p.room_id = p_room_id
    and p.auth_user_id = (select auth.uid())
  order by p.joined_at desc
  limit 1;

  if v_me.id is null then
    raise exception using
      errcode = '42501',
      message = 'ROOM_MEMBERSHIP_REQUIRED';
  end if;

  select *
  into v_match
  from public.party_matches
  where room_id = p_room_id
  for update;

  if v_match.room_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_MATCH_NOT_STARTED';
  end if;

  -- Idempotency spans rounds.
  --
  -- A delayed retry from Round N must NOT become a new bet in Round N+1.
  select *
  into v_bet
  from public.party_bets b
  where b.room_id = p_room_id
    and b.player_id = v_me.id
    and b.client_action_id = p_client_action_id
  order by b.created_at desc
  limit 1;

  if v_bet.id is not null then
    return jsonb_build_object(
      'bet',
      jsonb_build_object(
        'id', v_bet.id,
        'round_number', v_bet.round_number,
        'player_id', v_bet.player_id,
        'target_player_id',
          coalesce(
            v_bet.target_player_id,
            v_match.turn_order[v_bet.slot_index + 1]
          ),
        'chips', v_bet.chips,
        'client_action_id', v_bet.client_action_id,
        'position_x', v_bet.position_x,
        'position_y', v_bet.position_y,
        'won', v_bet.won
      ),

      'snapshot',
      public.get_party_poll_snapshot_v1(p_room_id)
    );
  end if;

  if p_chips is null or p_chips not in (5, 10, 25) then
    raise exception using
      errcode = '22023',
      message = 'INVALID_PARTY_POLL_CHIP';
  end if;

  select *
  into v_round
  from public.party_rounds
  where room_id = p_room_id
    and round_number = v_room.current_round
  for update;

  if v_round.id is null then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_ROUND_STATE_MISMATCH';
  end if;

  select *
  into v_challenge
  from public.party_challenges
  where id = v_round.challenge_id;

  if v_challenge.id is null
     or v_challenge.challenge_type <> 'poll' then
    raise exception using
      errcode = 'P0001',
      message = 'PARTY_POLL_CHALLENGE_REQUIRED';
  end if;

  if v_round.phase <> 'betting' then
    raise exception using
      errcode = 'P0001',
      message = 'BETTING_WINDOW_CLOSED';
  end if;

  if v_round.phase_ends_at is null then
    raise exception using
      errcode = 'P0001',
      message = 'BETTING_DEADLINE_MISSING';
  end if;

  if statement_timestamp() >= v_round.phase_ends_at then
    raise exception using
      errcode = 'P0001',
      message = 'BETTING_WINDOW_CLOSED';
  end if;

  -- UUID is authoritative.
  -- Slot is calculated entirely by the database.
  v_target_position :=
    array_position(
      v_match.turn_order,
      p_target_player_id
    );

  if v_target_position is null then
    raise exception using
      errcode = '22023',
      message = 'INVALID_POLL_TARGET';
  end if;

  v_slot_index := v_target_position - 1;

  if v_slot_index < 0 or v_slot_index > 7 then
    raise exception using
      errcode = '22023',
      message = 'INVALID_POLL_TARGET';
  end if;

  -- Maximum two distinct people per bettor.
  select count(
    distinct coalesce(
      b.target_player_id,
      v_match.turn_order[b.slot_index + 1]
    )
  )
  into v_other_target_count
  from public.party_bets b
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round
    and b.player_id = v_me.id
    and coalesce(
      b.target_player_id,
      v_match.turn_order[b.slot_index + 1]
    ) is distinct from p_target_player_id;

  if v_other_target_count >= 2 then
    raise exception using
      errcode = '22023',
      message = 'POLL_MAX_TWO_TARGETS';
  end if;

  if exists (
    select 1
    from public.party_bets b
    where b.room_id = p_room_id
      and b.round_number = v_room.current_round
      and b.player_id = v_me.id
      and b.chips = p_chips
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'POLL_CHIP_ALREADY_USED';
  end if;

  -- Explicit zero. We do NOT rely on the legacy table default of 15.
  insert into public.party_scores (
    room_id,
    player_id,
    score
  )
  values (
    p_room_id,
    v_me.id,
    0
  )
  on conflict (room_id, player_id)
  do nothing;

  select s.score
  into v_score
  from public.party_scores s
  where s.room_id = p_room_id
    and s.player_id = v_me.id
  for update;

  v_score := coalesce(v_score, 0);

  -- Fixed round stake capacity. PROFIT never changes wager capacity.
  v_limit := 40;

  select coalesce(sum(b.chips), 0)
  into v_total
  from public.party_bets b
  where b.room_id = p_room_id
    and b.round_number = v_room.current_round
    and b.player_id = v_me.id;

  if v_total + p_chips > v_limit then
    raise exception using
      errcode = 'P0001',
      message = format(
        'INSUFFICIENT_CHIPS available=%s requested=%s',
        greatest(0, v_limit - v_total),
        p_chips
      );
  end if;

  insert into public.party_bets (
    room_id,
    round_number,
    player_id,
    slot_index,
    target_player_id,
    chips,
    client_action_id,
    position_x,
    position_y
  )
  values (
    p_room_id,
    v_room.current_round,
    v_me.id,
    v_slot_index,
    p_target_player_id,
    p_chips,
    p_client_action_id,
    p_position_x,
    p_position_y
  )
  on conflict (
    room_id,
    round_number,
    player_id,
    client_action_id
  )
  do nothing
  returning *
  into v_bet;

  -- Defensive retry path.
  if v_bet.id is null then
    select *
    into v_bet
    from public.party_bets b
    where b.room_id = p_room_id
      and b.round_number = v_room.current_round
      and b.player_id = v_me.id
      and b.client_action_id = p_client_action_id
    limit 1;
  end if;

  if v_bet.id is null then
    raise exception using
      errcode = 'P0001',
      message = 'BET_INSERT_FAILED';
  end if;

  return jsonb_build_object(
    'bet',
    jsonb_build_object(
      'id', v_bet.id,
      'round_number', v_bet.round_number,
      'player_id', v_bet.player_id,
      'target_player_id', v_bet.target_player_id,
      'chips', v_bet.chips,
      'client_action_id', v_bet.client_action_id,
      'position_x', v_bet.position_x,
      'position_y', v_bet.position_y,
      'won', v_bet.won
    ),

    'snapshot',
    public.get_party_poll_snapshot_v1(p_room_id)
  );
end;
$function$;

revoke all on function
public.get_party_poll_snapshot_v1(uuid)
from public, anon, authenticated;

grant execute on function
public.get_party_poll_snapshot_v1(uuid)
to authenticated;

revoke all on function
public.place_party_poll_bet_v1(
  uuid,
  uuid,
  integer,
  uuid,
  double precision,
  double precision
)
from public, anon, authenticated;

grant execute on function
public.place_party_poll_bet_v1(
  uuid,
  uuid,
  integer,
  uuid,
  double precision,
  double precision
)
to authenticated;

notify pgrst, 'reload schema';

commit;