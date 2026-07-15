begin;

alter table public.rooms
  add column if not exists created_by uuid references auth.users(id);

alter table public.players
  add column if not exists auth_user_id uuid references auth.users(id);

create unique index if not exists players_room_auth_user_unique
  on public.players(room_id, auth_user_id)
  where auth_user_id is not null;

create index if not exists players_auth_user_room_idx
  on public.players(auth_user_id, room_id);

create index if not exists rooms_created_by_created_at_idx
  on public.rooms(created_by, created_at desc);

create or replace function public.is_room_member_v2(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.players p
      where p.room_id = p_room_id
        and p.auth_user_id = (select auth.uid())
        and p.is_connected = true
    );
$$;

create or replace function public.can_access_room_topic_v2(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.players p
      join public.rooms r on r.id = p.room_id
      where p.auth_user_id = (select auth.uid())
        and p.is_connected = true
        and p_topic = 'room:' || r.code
    );
$$;

create or replace function public.public_question_json_v2(
  p_question_id uuid,
  p_include_answer boolean default false
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when q.id is null then null
    else jsonb_strip_nulls(jsonb_build_object(
      'id', q.id,
      'text_tr', q.text_tr,
      'text_en', q.text_en,
      'answer', case when p_include_answer then q.answer else null end,
      'answer_unit', q.answer_unit,
      'category', q.category,
      'difficulty', q.difficulty,
      'source', q.source
    ))
  end
  from public.questions q
  where q.id = p_question_id;
$$;

create or replace function public.pick_question_id_v2(
  p_room_id uuid,
  p_category text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_question_id uuid;
begin
  select q.id
  into v_question_id
  from public.questions q
  where (
      p_category is null
      or btrim(p_category) = ''
      or lower(btrim(p_category)) = 'mixed'
      or q.category = p_category
    )
    and not exists (
      select 1
      from public.guesses g
      where g.room_id = p_room_id
        and g.question_id = q.id
    )
  order by random()
  limit 1;

  if v_question_id is null then
    select q.id
    into v_question_id
    from public.questions q
    where (
      p_category is null
      or btrim(p_category) = ''
      or lower(btrim(p_category)) = 'mixed'
      or q.category = p_category
    )
    order by random()
    limit 1;
  end if;

  return v_question_id;
end;
$$;

create or replace function public.create_room_v2(
  p_code text,
  p_max_rounds integer,
  p_max_players integer,
  p_category text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.rooms%rowtype;
begin
  if v_uid is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  if upper(p_code) !~ '^[A-Z0-9]{6}$' then
    raise exception using errcode = '22023', message = 'Invalid room code';
  end if;
  if p_max_rounds not between 5 and 12 then
    raise exception using errcode = '22023', message = 'Invalid round count';
  end if;
  if p_max_players not between 2 and 10 then
    raise exception using errcode = '22023', message = 'Invalid player limit';
  end if;
  if (
    select count(*)
    from public.rooms r
    where r.created_by = v_uid
      and r.created_at > statement_timestamp() - interval '1 minute'
  ) >= 5 then
    raise exception using errcode = 'P0001', message = 'Room creation rate exceeded';
  end if;

  insert into public.rooms (
    code, host_id, status, current_round, max_rounds, max_players,
    category, round_phase, created_by
  ) values (
    upper(p_code), v_uid::text, 'waiting', 0, p_max_rounds, p_max_players,
    nullif(btrim(p_category), ''), 'idle', v_uid
  )
  returning * into v_room;

  return to_jsonb(v_room);
end;
$$;

create or replace function public.find_room_by_code_v2(p_code text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(r)
  from public.rooms r
  where r.code = upper(btrim(p_code))
    and r.status = 'waiting'
  order by r.created_at desc
  limit 1;
$$;

create or replace function public.join_room_v2(
  p_room_id uuid,
  p_device_id text,
  p_name text,
  p_avatar_color text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.rooms%rowtype;
  v_player public.players%rowtype;
  v_is_host boolean;
begin
  if v_uid is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;
  if p_device_id is null or length(btrim(p_device_id)) < 8 then
    raise exception using errcode = '22023', message = 'Invalid device id';
  end if;
  if length(btrim(p_name)) not between 1 and 24 then
    raise exception using errcode = '22023', message = 'Invalid player name';
  end if;
  if p_avatar_color !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception using errcode = '22023', message = 'Invalid avatar color';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;
  if v_room.status <> 'waiting' then
    raise exception using errcode = 'P0001', message = 'Room is already playing';
  end if;

  select * into v_player
  from public.players p
  where p.room_id = p_room_id
    and (
      p.auth_user_id = v_uid
      or (p.auth_user_id is null and p.device_id = p_device_id)
    )
  order by (p.auth_user_id = v_uid) desc, p.joined_at desc
  limit 1
  for update;

  if v_player.id is null and (
    select count(*) from public.players p
    where p.room_id = p_room_id and p.is_connected = true
  ) >= v_room.max_players then
    raise exception using errcode = 'P0001', message = 'Room is full';
  end if;

  if exists (
    select 1 from public.players p
    where p.room_id = p_room_id
      and p.is_connected = true
      and lower(btrim(p.name)) = lower(btrim(p_name))
      and (v_player.id is null or p.id <> v_player.id)
  ) then
    raise exception using errcode = '23505', message = 'Player name is already taken';
  end if;

  v_is_host := v_room.created_by = v_uid
    or (v_player.id is not null and v_player.is_host = true);

  if v_player.id is null then
    insert into public.players (
      room_id, device_id, auth_user_id, name, avatar_color, score,
      is_host, is_ready, is_connected, last_seen
    ) values (
      p_room_id, p_device_id, v_uid, btrim(p_name), upper(p_avatar_color), 15,
      v_is_host, v_is_host, true, statement_timestamp()
    )
    returning * into v_player;
  else
    update public.players
    set auth_user_id = v_uid,
        device_id = p_device_id,
        name = btrim(p_name),
        avatar_color = coalesce(nullif(avatar_color, ''), upper(p_avatar_color)),
        is_host = is_host or v_is_host,
        is_ready = case when is_host or v_is_host then true else is_ready end,
        is_connected = true,
        last_seen = statement_timestamp()
    where id = v_player.id
    returning * into v_player;
  end if;

  if v_player.is_host then
    update public.rooms set host_id = v_player.id::text where id = p_room_id;
  end if;

  return to_jsonb(v_player);
end;
$$;

create or replace function public.set_player_ready_v2(
  p_player_id uuid,
  p_is_ready boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_player public.players%rowtype;
begin
  update public.players p
  set is_ready = case when p.is_host then true else p_is_ready end,
      last_seen = statement_timestamp()
  where p.id = p_player_id
    and p.auth_user_id = (select auth.uid())
    and p.is_connected = true
  returning * into v_player;

  if not found then
    raise exception using errcode = '42501', message = 'Player access denied';
  end if;
  return to_jsonb(v_player);
end;
$$;

create or replace function public.set_player_connected_v2(
  p_player_id uuid,
  p_connected boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.players%rowtype;
  v_actor public.players%rowtype;
begin
  select * into v_target from public.players where id = p_player_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'Player not found';
  end if;

  select * into v_actor
  from public.players
  where room_id = v_target.room_id
    and auth_user_id = (select auth.uid())
    and is_connected = true
  limit 1;

  if v_actor.id is null or (v_actor.id <> v_target.id and not v_actor.is_host) then
    raise exception using errcode = '42501', message = 'Player access denied';
  end if;
  if v_target.is_host and v_actor.id <> v_target.id then
    raise exception using errcode = '42501', message = 'Host cannot be removed';
  end if;

  update public.players
  set is_connected = p_connected,
      last_seen = statement_timestamp()
  where id = p_player_id
  returning * into v_target;
  return to_jsonb(v_target);
end;
$$;

create or replace function public.get_question_categories_v2()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(category order by lower(category)), '[]'::jsonb)
  from (
    select distinct btrim(q.category) as category
    from public.questions q
    where q.category is not null and btrim(q.category) <> ''
  ) categories;
$$;

create or replace function public.get_current_question_v2(p_room_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_room from public.rooms where id = p_room_id;
  if v_room.current_question_id is null then return null; end if;
  return public.public_question_json_v2(
    v_room.current_question_id,
    v_room.round_phase in ('revealAnswer', 'scoring') or v_room.status = 'finished'
  );
end;
$$;

create or replace function public.start_game_v2(
  p_room_id uuid,
  p_duration_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
  v_scores jsonb;
begin
  if p_duration_seconds not between 5 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;
  if not exists (
    select 1 from public.players p
    where p.room_id = p_room_id
      and p.auth_user_id = (select auth.uid())
      and p.is_host = true
      and p.is_connected = true
  ) then
    raise exception using errcode = '42501', message = 'Host access required';
  end if;
  if v_room.status <> 'waiting' then
    raise exception using errcode = '40001', message = 'Room is not waiting';
  end if;
  if (select count(*) from public.players p where p.room_id = p_room_id and p.is_connected) < 2 then
    raise exception using errcode = 'P0001', message = 'At least two players required';
  end if;
  if exists (
    select 1 from public.players p
    where p.room_id = p_room_id and p.is_connected and not p.is_host and not p.is_ready
  ) then
    raise exception using errcode = 'P0001', message = 'All players must be ready';
  end if;

  v_question_id := public.pick_question_id_v2(p_room_id, v_room.category);
  if v_question_id is null then
    raise exception using errcode = 'P0002', message = 'No question available';
  end if;

  update public.players set score = 15 where room_id = p_room_id and is_connected;
  update public.rooms
  set status = 'playing', current_round = 1, round_phase = 'question',
      current_question_id = v_question_id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + interval '3 seconds'
  where id = p_room_id
  returning * into v_room;

  select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
  into v_scores from public.players p where p.room_id = p_room_id and p.is_connected;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'question', public.public_question_json_v2(v_question_id, false),
    'scores', v_scores
  );
end;
$$;

create or replace function public.claim_next_question_v2(
  p_room_id uuid,
  p_round_number integer,
  p_duration_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if p_duration_seconds not between 5 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.status <> 'playing' or v_room.current_round <> p_round_number
     or v_room.round_phase <> 'question' then
    return null;
  end if;
  if v_room.phase_ends_at is not null and v_room.phase_ends_at > statement_timestamp() then
    return null;
  end if;

  v_question_id := v_room.current_question_id;
  if v_question_id is null then
    v_question_id := public.pick_question_id_v2(p_room_id, v_room.category);
  end if;
  if v_question_id is null then
    raise exception using errcode = 'P0002', message = 'No question available';
  end if;

  update public.rooms
  set round_phase = 'guessing', current_question_id = v_question_id,
      phase_started_at = statement_timestamp(),
      phase_ends_at = statement_timestamp() + make_interval(secs => p_duration_seconds)
  where id = p_room_id
  returning * into v_room;

  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'question', public.public_question_json_v2(v_question_id, false)
  );
end;
$$;

create or replace function public.submit_guess_v2(
  p_room_id uuid,
  p_value bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_player public.players%rowtype;
  v_guess public.guesses%rowtype;
begin
  if p_value < 0 then
    raise exception using errcode = '22023', message = 'Invalid guess';
  end if;
  select * into v_room from public.rooms where id = p_room_id;
  select * into v_player from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid()) and is_connected
  limit 1;
  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_room.status <> 'playing' or v_room.round_phase <> 'guessing'
     or v_room.current_question_id is null
     or (v_room.phase_ends_at is not null and v_room.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Guessing phase is closed';
  end if;

  insert into public.guesses (
    room_id, round_number, player_id, question_id, value
  ) values (
    p_room_id, v_room.current_round, v_player.id, v_room.current_question_id, p_value
  )
  on conflict (room_id, round_number, player_id) do nothing
  returning * into v_guess;

  if v_guess.id is null then
    select * into v_guess from public.guesses
    where room_id = p_room_id and round_number = v_room.current_round
      and player_id = v_player.id;
  end if;
  return to_jsonb(v_guess);
end;
$$;

create or replace function public.place_bet_v2(
  p_room_id uuid,
  p_slot_index integer,
  p_chips integer,
  p_client_action_id uuid,
  p_position_x double precision default null,
  p_position_y double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_player public.players%rowtype;
  v_bet public.bets%rowtype;
  v_total integer;
  v_multiplier integer;
begin
  if p_slot_index not between 0 and 4 or p_chips not between 1 and 1000 then
    raise exception using errcode = '22023', message = 'Invalid bet';
  end if;
  select * into v_room from public.rooms where id = p_room_id;
  select * into v_player from public.players
  where room_id = p_room_id and auth_user_id = (select auth.uid()) and is_connected
  limit 1;
  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if v_room.status <> 'playing' or v_room.round_phase <> 'betting'
     or (v_room.phase_ends_at is not null and v_room.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
  end if;

  select * into v_bet from public.bets
  where client_action_id = p_client_action_id::text and player_id = v_player.id;
  if v_bet.id is not null then return to_jsonb(v_bet); end if;

  select coalesce(sum(chips), 0) into v_total
  from public.bets
  where room_id = p_room_id and round_number = v_room.current_round
    and player_id = v_player.id;
  if v_total + p_chips > v_player.score then
    raise exception using errcode = '22003', message = 'Insufficient score';
  end if;

  v_multiplier := (array[4, 3, 2, 3, 4])[p_slot_index + 1];
  insert into public.bets (
    room_id, round_number, player_id, target_guess_id, slot_index,
    chips, payout_multiplier, client_action_id, position_x, position_y
  ) values (
    p_room_id, v_room.current_round, v_player.id, null, p_slot_index,
    p_chips, v_multiplier, p_client_action_id::text,
    case when p_position_x between -1000 and 2000 then p_position_x else null end,
    case when p_position_y between -1000 and 2000 then p_position_y else null end
  )
  returning * into v_bet;
  return to_jsonb(v_bet);
end;
$$;

create or replace function public.move_bet_v2(
  p_bet_id uuid,
  p_slot_index integer,
  p_position_x double precision default null,
  p_position_y double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bet public.bets%rowtype;
  v_room public.rooms%rowtype;
begin
  if p_slot_index not between 0 and 4 then
    raise exception using errcode = '22023', message = 'Invalid slot';
  end if;
  select b.* into v_bet
  from public.bets b join public.players p on p.id = b.player_id
  where b.id = p_bet_id and p.auth_user_id = (select auth.uid())
  for update of b;
  if not found then
    raise exception using errcode = '42501', message = 'Bet access denied';
  end if;
  select * into v_room from public.rooms where id = v_bet.room_id;
  if v_room.round_phase <> 'betting' or v_room.current_round <> v_bet.round_number
     or (v_room.phase_ends_at is not null and v_room.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
  end if;
  update public.bets
  set target_guess_id = null,
      slot_index = p_slot_index,
      payout_multiplier = (array[4, 3, 2, 3, 4])[p_slot_index + 1],
      position_x = case when p_position_x between -1000 and 2000 then p_position_x else null end,
      position_y = case when p_position_y between -1000 and 2000 then p_position_y else null end
  where id = p_bet_id
  returning * into v_bet;
  return to_jsonb(v_bet);
end;
$$;

create or replace function public.remove_bet_v2(p_bet_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bet public.bets%rowtype;
  v_room public.rooms%rowtype;
begin
  select b.* into v_bet
  from public.bets b join public.players p on p.id = b.player_id
  where b.id = p_bet_id and p.auth_user_id = (select auth.uid())
  for update of b;
  if not found then
    raise exception using errcode = '42501', message = 'Bet access denied';
  end if;
  select * into v_room from public.rooms where id = v_bet.room_id;
  if v_room.round_phase <> 'betting' or v_room.current_round <> v_bet.round_number
     or (v_room.phase_ends_at is not null and v_room.phase_ends_at < statement_timestamp()) then
    raise exception using errcode = '40001', message = 'Betting phase is closed';
  end if;
  delete from public.bets where id = p_bet_id;
  return to_jsonb(v_bet);
end;
$$;

create or replace function public.game_nice_step_v2(p_range bigint)
returns bigint
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_magnitude bigint;
  v_multiplier integer;
begin
  if p_range <= 12 then return 1; end if;
  v_magnitude := power(10::numeric, greatest(0, length(p_range::text) - 2))::bigint;
  foreach v_multiplier in array array[1, 2, 5, 10] loop
    if p_range::numeric / (v_magnitude * v_multiplier) <= 8 then
      return v_magnitude * v_multiplier;
    end if;
  end loop;
  return v_magnitude * 10;
end;
$$;

create or replace function public.game_fallback_boundaries_v2(p_values bigint[])
returns bigint[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_low bigint := p_values[1];
  v_high bigint := p_values[array_length(p_values, 1)];
  v_step bigint;
  v_result bigint[];
  i integer;
begin
  if array_length(p_values, 1) = 1 then
    v_step := public.game_nice_step_v2(greatest(10, abs(v_low)));
    return array[v_low, v_low + v_step, v_low + v_step * 2, v_low + v_step * 3];
  end if;
  if v_high - v_low < 3 then
    return array[v_low, v_low + 1, v_low + 2, v_low + 3];
  end if;
  v_step := greatest(1, round((v_high - v_low)::numeric / 3)::bigint);
  v_result := array[v_low, v_low + v_step, v_low + v_step * 2, v_high];
  for i in 2..4 loop
    if v_result[i] <= v_result[i - 1] then v_result[i] := v_result[i - 1] + 1; end if;
  end loop;
  return v_result;
end;
$$;

create or replace function public.game_board_boundaries_v2(
  p_room_id uuid,
  p_round_number integer
)
returns bigint[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_values bigint[];
  v_candidates bigint[];
  v_result bigint[];
  v_count integer;
  v_index integer;
  v_widest_index integer;
  v_widest_gap bigint;
  v_gap bigint;
  v_step bigint;
  v_generated bigint;
  v_target numeric;
  v_candidate bigint;
begin
  select array_agg(value order by value) into v_values
  from (select distinct g.value from public.guesses g
        where g.room_id = p_room_id and g.round_number = p_round_number) values_query;
  v_count := coalesce(array_length(v_values, 1), 0);
  if v_count = 0 then return array[25, 50, 75, 100]::bigint[]; end if;
  if v_count = 1 then return public.game_fallback_boundaries_v2(v_values); end if;

  if v_count > 4 then
    v_result := array[v_values[1]];
    v_candidates := v_values[2:v_count - 1];
    for v_index in 1..2 loop
      v_target := v_values[1] + ((v_values[v_count] - v_values[1])::numeric / 3) * v_index;
      select c into v_candidate from unnest(v_candidates) c
      order by abs(c::numeric - v_target), c limit 1;
      v_result := array_append(v_result, v_candidate);
      v_candidates := array_remove(v_candidates, v_candidate);
    end loop;
    v_result := array_append(v_result, v_values[v_count]);
    select array_agg(v order by v) into v_result from unnest(v_result) v;
    return v_result;
  end if;

  v_result := v_values;
  while array_length(v_result, 1) < 4 loop
    v_widest_index := 1;
    v_widest_gap := v_result[2] - v_result[1];
    if array_length(v_result, 1) > 2 then
      for v_index in 2..array_length(v_result, 1) - 1 loop
        v_gap := v_result[v_index + 1] - v_result[v_index];
        if v_gap > v_widest_gap then
          v_widest_gap := v_gap;
          v_widest_index := v_index;
        end if;
      end loop;
    end if;
    v_step := public.game_nice_step_v2(abs(v_widest_gap));
    v_generated := round(
      (((v_result[v_widest_index] + v_result[v_widest_index + 1])::numeric / 2) / v_step)
    )::bigint * v_step;
    if v_generated = any(v_result) then return public.game_fallback_boundaries_v2(v_values); end if;
    v_result := array_append(v_result, v_generated);
    select array_agg(v order by v) into v_result from unnest(v_result) v;
  end loop;
  return v_result;
end;
$$;

create or replace function public.settle_game_round_v2(
  p_room_id uuid,
  p_round_number integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_answer bigint;
  v_boundaries bigint[];
  v_winning_slot integer;
  v_winning_guess_id uuid;
  v_scores jsonb;
  v_payouts jsonb;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found or v_room.current_round <> p_round_number then
    raise exception using errcode = '40001', message = 'Round changed';
  end if;
  if v_room.round_phase not in ('betting', 'revealAnswer') then
    raise exception using errcode = '40001', message = 'Betting phase is not active';
  end if;
  if v_room.round_phase = 'betting' and v_room.phase_ends_at is not null
     and v_room.phase_ends_at > statement_timestamp() then
    raise exception using errcode = '40001', message = 'Betting deadline not reached';
  end if;

  select q.answer into v_answer from public.questions q where q.id = v_room.current_question_id;
  if v_answer is null then
    raise exception using errcode = 'P0002', message = 'Question answer not found';
  end if;
  v_boundaries := public.game_board_boundaries_v2(p_room_id, p_round_number);
  v_winning_slot := case
    when v_answer < v_boundaries[1] then 0
    when v_answer < v_boundaries[2] then 1
    when v_answer <= v_boundaries[3] then 2
    when v_answer <= v_boundaries[4] then 3
    else 4
  end;
  select g.id into v_winning_guess_id
  from public.guesses g
  where g.room_id = p_room_id and g.round_number = p_round_number and g.value <= v_answer
  order by g.value desc, g.id
  limit 1;

  if v_room.round_phase = 'betting' then
    update public.guesses
    set is_winner = (id = v_winning_guess_id)
    where room_id = p_room_id and round_number = p_round_number;
    update public.bets
    set won = (slot_index = v_winning_slot)
    where room_id = p_room_id and round_number = p_round_number;
    update public.players p
    set score = greatest(
      15,
      p.score
      - coalesce((select sum(b.chips) from public.bets b
                  where b.room_id = p_room_id and b.round_number = p_round_number
                    and b.player_id = p.id), 0)
      + coalesce((select sum(b.chips * (array[4, 3, 2, 3, 4])[b.slot_index + 1])
                  from public.bets b
                  where b.room_id = p_room_id and b.round_number = p_round_number
                    and b.player_id = p.id and b.slot_index = v_winning_slot), 0)
    )
    where p.room_id = p_room_id and p.is_connected;
    update public.rooms
    set round_phase = 'revealAnswer', phase_started_at = statement_timestamp(),
        phase_ends_at = null
    where id = p_room_id
    returning * into v_room;
  end if;

  select coalesce(jsonb_object_agg(p.id::text, p.score), '{}'::jsonb)
  into v_scores from public.players p where p.room_id = p_room_id and p.is_connected;
  select coalesce(jsonb_object_agg(x.player_id::text, x.payout), '{}'::jsonb)
  into v_payouts
  from (
    select b.player_id,
      sum(b.chips * (array[4, 3, 2, 3, 4])[b.slot_index + 1])::integer as payout
    from public.bets b
    where b.room_id = p_room_id and b.round_number = p_round_number
      and b.slot_index = v_winning_slot
    group by b.player_id
  ) x;

  return jsonb_build_object(
    'status', case when v_room.round_phase = 'revealAnswer' then 'settled' else 'already_settled' end,
    'state_version', v_room.state_version,
    'answer', v_answer,
    'winning_guess_id', v_winning_guess_id,
    'winning_slot_index', v_winning_slot,
    'scores', v_scores,
    'payouts', v_payouts,
    'phase_ends_at', v_room.phase_ends_at
  );
end;
$$;

create or replace function public.finish_game_v2(
  p_room_id uuid,
  p_round_number integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  update public.rooms
  set status = 'finished', round_phase = 'idle', phase_ends_at = null
  where id = p_room_id and current_round = p_round_number
    and round_phase = 'revealAnswer'
    and (phase_ends_at is null or phase_ends_at <= statement_timestamp());
  return found;
end;
$$;

create or replace function public.claim_game_phase_v1(
  p_room_id uuid,
  p_round_number integer,
  p_expected_phase text,
  p_next_phase text,
  p_duration_seconds integer default null,
  p_next_round integer default null,
  p_current_question_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_effective_round integer;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  if p_duration_seconds is not null and p_duration_seconds not between 1 and 300 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;
  if not (
    (p_expected_phase = 'guessing' and p_next_phase = 'betting') or
    (p_expected_phase = 'revealAnswer' and p_next_phase = 'question')
  ) then
    raise exception using errcode = '22023', message = 'Invalid phase transition';
  end if;
  if p_current_question_id is not null then
    raise exception using errcode = '22023', message = 'Client question selection is disabled';
  end if;
  if p_expected_phase = 'revealAnswer'
     and (p_next_round is null or p_next_round <> p_round_number + 1) then
    raise exception using errcode = '22023', message = 'Invalid next round';
  end if;
  v_effective_round := coalesce(p_next_round, p_round_number);

  update public.rooms
  set current_round = v_effective_round,
      round_phase = p_next_phase,
      current_question_id = case when p_next_phase = 'question' then null else current_question_id end,
      phase_started_at = statement_timestamp(),
      phase_ends_at = case when p_duration_seconds is null then null
        else statement_timestamp() + make_interval(secs => p_duration_seconds) end
  where id = p_room_id and current_round = p_round_number
    and round_phase = p_expected_phase and status = 'playing'
    and (phase_ends_at is null or phase_ends_at <= statement_timestamp())
  returning * into v_room;
  if not found then return null; end if;
  return to_jsonb(v_room);
end;
$$;

create or replace function public.reset_room_to_lobby_v1(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_room from public.rooms where id = p_room_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;
  if v_room.status <> 'finished' then
    raise exception using errcode = '40001', message = 'Game is not finished';
  end if;
  delete from public.bets where room_id = p_room_id;
  delete from public.guesses where room_id = p_room_id;
  update public.players set score = 15, is_ready = is_host where room_id = p_room_id;
  update public.rooms
  set status = 'waiting', current_round = 0, round_phase = 'idle',
      current_question_id = null, phase_started_at = null, phase_ends_at = null
  where id = p_room_id
  returning * into v_room;
  return to_jsonb(v_room);
end;
$$;

do $$
declare
  v_policy record;
begin
  for v_policy in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('rooms', 'players', 'guesses', 'bets', 'questions', 'question_ratings')
  loop
    execute format('drop policy if exists %I on %I.%I',
      v_policy.policyname, v_policy.schemaname, v_policy.tablename);
  end loop;
end $$;

alter table public.rooms enable row level security;
alter table public.players enable row level security;
alter table public.guesses enable row level security;
alter table public.bets enable row level security;
alter table public.questions enable row level security;
alter table public.question_ratings enable row level security;

create policy rooms_member_read_v2 on public.rooms
for select to authenticated using (public.is_room_member_v2(id));

create policy players_member_read_v2 on public.players
for select to authenticated using (public.is_room_member_v2(room_id));

create policy guesses_phase_read_v2 on public.guesses
for select to authenticated using (
  public.is_room_member_v2(room_id)
  and (
    exists (select 1 from public.players p
            where p.id = player_id and p.auth_user_id = (select auth.uid()))
    or exists (select 1 from public.rooms r
               where r.id = room_id and r.round_phase <> 'guessing')
  )
);

create policy bets_member_read_v2 on public.bets
for select to authenticated using (public.is_room_member_v2(room_id));

drop policy if exists game_room_messages_read_v2 on realtime.messages;
drop policy if exists game_room_messages_send_v2 on realtime.messages;
alter table realtime.messages enable row level security;
create policy game_room_messages_read_v2 on realtime.messages
for select to authenticated using (
  realtime.messages.extension in ('broadcast', 'presence')
  and public.can_access_room_topic_v2((select realtime.topic()))
);
create policy game_room_messages_send_v2 on realtime.messages
for insert to authenticated with check (
  realtime.messages.extension in ('broadcast', 'presence')
  and public.can_access_room_topic_v2((select realtime.topic()))
);

revoke all on public.rooms, public.players, public.guesses, public.bets,
  public.questions, public.question_ratings from anon;
revoke all on public.rooms, public.players, public.guesses, public.bets,
  public.questions, public.question_ratings from authenticated;
grant select on public.rooms, public.players, public.guesses, public.bets to authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.game_server_time() to authenticated;
grant execute on function public.is_room_member_v2(uuid) to authenticated;
grant execute on function public.can_access_room_topic_v2(text) to authenticated;
grant execute on function public.create_room_v2(text, integer, integer, text) to authenticated;
grant execute on function public.find_room_by_code_v2(text) to authenticated;
grant execute on function public.join_room_v2(uuid, text, text, text) to authenticated;
grant execute on function public.set_player_ready_v2(uuid, boolean) to authenticated;
grant execute on function public.set_player_connected_v2(uuid, boolean) to authenticated;
grant execute on function public.get_question_categories_v2() to authenticated;
grant execute on function public.get_current_question_v2(uuid) to authenticated;
grant execute on function public.start_game_v2(uuid, integer) to authenticated;
grant execute on function public.claim_next_question_v2(uuid, integer, integer) to authenticated;
grant execute on function public.submit_guess_v2(uuid, bigint) to authenticated;
grant execute on function public.place_bet_v2(uuid, integer, integer, uuid, double precision, double precision) to authenticated;
grant execute on function public.move_bet_v2(uuid, integer, double precision, double precision) to authenticated;
grant execute on function public.remove_bet_v2(uuid) to authenticated;
grant execute on function public.settle_game_round_v2(uuid, integer) to authenticated;
grant execute on function public.finish_game_v2(uuid, integer) to authenticated;
grant execute on function public.claim_game_phase_v1(uuid, integer, text, text, integer, integer, uuid) to authenticated;
grant execute on function public.reset_room_to_lobby_v1(uuid) to authenticated;

alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

commit;
