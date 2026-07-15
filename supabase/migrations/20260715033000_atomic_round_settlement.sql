begin;

create or replace function public.bump_room_state_version()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.state_version := coalesce(old.state_version, 0) + 1;
  return new;
end;
$$;

drop trigger if exists rooms_bump_state_version on public.rooms;
create trigger rooms_bump_state_version
before update on public.rooms
for each row
execute function public.bump_room_state_version();

create or replace function public.settle_game_round_v1(
  p_room_id uuid,
  p_round_number integer,
  p_winning_guess_id uuid,
  p_winning_slot_index integer,
  p_scores jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_room public.rooms%rowtype;
  v_scores jsonb;
  v_winning_guess_id uuid;
  v_state_version integer;
begin
  if p_round_number < 1 then
    raise exception using errcode = '22023', message = 'Invalid round number';
  end if;

  if p_winning_slot_index not between 0 and 4 then
    raise exception using errcode = '22023', message = 'Invalid winning slot';
  end if;

  if p_scores is null or jsonb_typeof(p_scores) <> 'object' then
    raise exception using errcode = '22023', message = 'Scores must be an object';
  end if;

  select *
  into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Room not found';
  end if;

  if v_room.current_round <> p_round_number then
    raise exception using errcode = '40001', message = 'Round changed';
  end if;

  if v_room.round_phase = 'revealAnswer' then
    select coalesce(jsonb_object_agg(id::text, score), '{}'::jsonb)
    into v_scores
    from public.players
    where room_id = p_room_id;

    select id
    into v_winning_guess_id
    from public.guesses
    where room_id = p_room_id
      and round_number = p_round_number
      and is_winner = true
    order by id
    limit 1;

    return jsonb_build_object(
      'status', 'already_settled',
      'state_version', v_room.state_version,
      'winning_guess_id', v_winning_guess_id,
      'winning_slot_index', p_winning_slot_index,
      'scores', v_scores
    );
  end if;

  if v_room.round_phase <> 'betting' then
    raise exception using errcode = '40001', message = 'Phase changed';
  end if;

  if p_winning_guess_id is not null and not exists (
    select 1
    from public.guesses
    where id = p_winning_guess_id
      and room_id = p_room_id
      and round_number = p_round_number
  ) then
    raise exception using errcode = '22023', message = 'Invalid winning guess';
  end if;

  if exists (
    select 1
    from jsonb_each_text(p_scores) as score_entry(player_id, score_value)
    where score_entry.score_value !~ '^-?[0-9]+$'
       or not exists (
         select 1
         from public.players
         where room_id = p_room_id
           and id::text = score_entry.player_id
       )
  ) then
    raise exception using errcode = '22023', message = 'Invalid score payload';
  end if;

  if (select count(*) from jsonb_object_keys(p_scores)) <>
     (select count(*) from public.players where room_id = p_room_id) then
    raise exception using errcode = '22023', message = 'Incomplete score payload';
  end if;

  update public.guesses
  set is_winner = (id = p_winning_guess_id)
  where room_id = p_room_id
    and round_number = p_round_number;

  update public.bets
  set won = (slot_index = p_winning_slot_index)
  where room_id = p_room_id
    and round_number = p_round_number;

  update public.players as player
  set score = greatest(15, score_entry.score_value::integer)
  from jsonb_each_text(p_scores) as score_entry(player_id, score_value)
  where player.room_id = p_room_id
    and player.id::text = score_entry.player_id;

  update public.rooms
  set round_phase = 'revealAnswer',
      phase_started_at = statement_timestamp(),
      phase_ends_at = null
  where id = p_room_id
  returning state_version into v_state_version;

  select coalesce(jsonb_object_agg(id::text, score), '{}'::jsonb)
  into v_scores
  from public.players
  where room_id = p_room_id;

  return jsonb_build_object(
    'status', 'settled',
    'state_version', v_state_version,
    'winning_guess_id', p_winning_guess_id,
    'winning_slot_index', p_winning_slot_index,
    'scores', v_scores
  );
end;
$$;

revoke all on function public.settle_game_round_v1(
  uuid,
  integer,
  uuid,
  integer,
  jsonb
) from public;

grant execute on function public.settle_game_round_v1(
  uuid,
  integer,
  uuid,
  integer,
  jsonb
) to anon, authenticated;

commit;
