-- A request arriving just after the server deadline is an expected game-state
-- race, not a PostgreSQL serialization failure. Keep successful responses
-- backward compatible while rejecting late first submissions without an ERROR.
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

  select * into v_room
  from public.rooms
  where id = p_room_id;

  select * into v_player
  from public.players
  where room_id = p_room_id
    and auth_user_id = (select auth.uid())
    and is_connected
  limit 1;

  if v_player.id is null then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;

  -- Preserve idempotency when the original request succeeded but its response
  -- arrived after the phase changed or the player tapped submit again.
  select * into v_guess
  from public.guesses
  where room_id = p_room_id
    and round_number = v_room.current_round
    and player_id = v_player.id;

  if v_guess.id is not null then
    return to_jsonb(v_guess);
  end if;

  if v_room.status <> 'playing'
     or v_room.round_phase <> 'guessing'
     or v_room.current_question_id is null
     or (v_room.phase_ends_at is not null
         and v_room.phase_ends_at < statement_timestamp()) then
    return null;
  end if;

  insert into public.guesses (
    room_id, round_number, player_id, question_id, value
  ) values (
    p_room_id, v_room.current_round, v_player.id,
    v_room.current_question_id, p_value
  )
  on conflict (room_id, round_number, player_id) do nothing
  returning * into v_guess;

  if v_guess.id is null then
    select * into v_guess
    from public.guesses
    where room_id = p_room_id
      and round_number = v_room.current_round
      and player_id = v_player.id;
  end if;

  return to_jsonb(v_guess);
end;
$$;
