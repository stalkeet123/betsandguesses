-- Administrator-only contract test against the already-installed migration.
-- Every fixture and mutation stays inside this rollback-only transaction.
begin;
set local statement_timeout = '15s';

do $check$
declare
  v_party_room uuid := gen_random_uuid();
  v_classic_room uuid := gen_random_uuid();
  v_players uuid[] := array[gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];
  v_classic_player uuid := gen_random_uuid();
  v_challenge uuid := gen_random_uuid();
  v_bet uuid := gen_random_uuid();
  v_classic_bet uuid := gen_random_uuid();
  v_version bigint;
  v_updated_at timestamptz;
  v_classic_before jsonb;
  v_operation text;
begin
  insert into public.rooms(id, code, host_id, game_mode, current_round)
  values
    (v_party_room, upper(left(replace(v_party_room::text, '-', ''), 6)),
     'party-sync-contract', 'party', 1),
    (v_classic_room, upper(left(replace(v_classic_room::text, '-', ''), 6)),
     'classic-sync-contract', 'classic', 1);

  insert into public.players(id, room_id, name, device_id)
  select id, v_party_room, 'Party sync fixture', id::text from unnest(v_players) id;
  insert into public.players(id, room_id, name, device_id)
  values (v_classic_player, v_classic_room, 'Classic sync fixture', v_classic_player::text);

  insert into public.party_matches(room_id, turn_order, state_version)
  values (v_party_room, v_players, 10);
  insert into public.party_challenges(
    id, slug, prompt_template, rules, answer_unit, challenge_type, category,
    max_result, duration_seconds, bet_boundaries
  ) values (
    v_challenge, 'sync_' || replace(v_challenge::text, '-', ''),
    'Who is the synthetic test winner?', 'Synthetic fixture only', 'player',
    'poll', 'poll', 7, 30, null
  );
  insert into public.party_rounds(
    room_id, round_number, performer_id, challenge_id, phase, phase_ends_at
  ) values (
    v_party_room, 1, v_players[1], v_challenge, 'betting',
    clock_timestamp() + interval '30 seconds'
  );

  select to_jsonb(r) into strict v_classic_before
  from public.rooms r where id = v_classic_room;

  -- Test each listed UPDATE column independently, plus a multi-column move.
  foreach v_operation in array array[
    'insert', 'target_player_id', 'slot_index', 'position_x', 'position_y',
    'chips', 'combined_move', 'delete'
  ] loop
    select state_version into strict v_version
    from public.party_matches where room_id = v_party_room;
    select updated_at into strict v_updated_at
    from public.rooms where id = v_party_room;

    case v_operation
      when 'insert' then
        insert into public.party_bets(
          id, room_id, round_number, player_id, target_player_id,
          slot_index, chips, client_action_id, position_x, position_y
        ) values (
          v_bet, v_party_room, 1, v_players[1], v_players[2],
          1, 5, gen_random_uuid(), 0.2, 0.3
        );
      when 'target_player_id' then
        update public.party_bets set target_player_id = v_players[3] where id = v_bet;
      when 'slot_index' then
        update public.party_bets set slot_index = 2 where id = v_bet;
      when 'position_x' then
        update public.party_bets set position_x = 0.4 where id = v_bet;
      when 'position_y' then
        update public.party_bets set position_y = 0.5 where id = v_bet;
      when 'chips' then
        update public.party_bets set chips = 10 where id = v_bet;
      when 'combined_move' then
        update public.party_bets
        set target_player_id = v_players[2], slot_index = 1,
            position_x = 0.6, position_y = 0.7
        where id = v_bet;
      when 'delete' then
        delete from public.party_bets where id = v_bet;
    end case;

    if (select state_version from public.party_matches where room_id = v_party_room)
       is distinct from v_version + 1 then
      raise exception '% must increment Party state_version exactly once', v_operation;
    end if;
    if (select updated_at from public.rooms where id = v_party_room)
       is not distinct from v_updated_at then
      raise exception '% must change Party rooms.updated_at', v_operation;
    end if;
    if (select to_jsonb(r) from public.rooms r where id = v_classic_room)
       is distinct from v_classic_before then
      raise exception '% changed an unrelated Classic room', v_operation;
    end if;

    if v_operation = 'insert' then
      select state_version into strict v_version
      from public.party_matches where room_id = v_party_room;
      select updated_at into strict v_updated_at
      from public.rooms where id = v_party_room;
      -- won is nullable settlement metadata, outside the trigger column list.
      update public.party_bets set won = false where id = v_bet;
      if (select state_version from public.party_matches where room_id = v_party_room)
         is distinct from v_version
         or (select updated_at from public.rooms where id = v_party_room)
         is distinct from v_updated_at then
        raise exception 'Unrelated won update spuriously invalidated Party state';
      end if;
    end if;
  end loop;

  select state_version into strict v_version
  from public.party_matches where room_id = v_party_room;
  select updated_at into strict v_updated_at
  from public.rooms where id = v_party_room;

  -- Exercise normal Classic bet mutations: the Party trigger must not attach
  -- to public.bets, update Classic rooms, or change an unrelated Party match.
  foreach v_operation in array array['insert', 'update', 'delete'] loop
    case v_operation
      when 'insert' then
        insert into public.bets(
          id, room_id, round_number, player_id, slot_index, chips, payout_multiplier
        ) values (v_classic_bet, v_classic_room, 1, v_classic_player, 1, 5, 2);
      when 'update' then
        update public.bets set slot_index = 2, position_x = 0.4 where id = v_classic_bet;
      when 'delete' then
        delete from public.bets where id = v_classic_bet;
    end case;
    if (select to_jsonb(r) from public.rooms r where id = v_classic_room)
       is distinct from v_classic_before
       or (select state_version from public.party_matches where room_id = v_party_room)
       is distinct from v_version
       or (select updated_at from public.rooms where id = v_party_room)
       is distinct from v_updated_at then
      raise exception 'Classic % unexpectedly changed room/Party sync state', v_operation;
    end if;
  end loop;

  -- Explicitly cover the game_mode guard even with a synthetic Party bet
  -- referencing a Classic room (no Party match exists for this room).
  insert into public.party_bets(
    id, room_id, round_number, player_id, target_player_id,
    slot_index, chips, client_action_id
  ) values (
    v_classic_bet, v_classic_room, 1, v_classic_player, v_classic_player,
    0, 5, gen_random_uuid()
  );
  if (select to_jsonb(r) from public.rooms r where id = v_classic_room)
     is distinct from v_classic_before then
    raise exception 'Party trigger touched Classic room on insert';
  end if;
  update public.party_bets set chips = 10 where id = v_classic_bet;
  if (select to_jsonb(r) from public.rooms r where id = v_classic_room)
     is distinct from v_classic_before then
    raise exception 'Party trigger touched Classic room on update';
  end if;
  delete from public.party_bets where id = v_classic_bet;
  if (select to_jsonb(r) from public.rooms r where id = v_classic_room)
     is distinct from v_classic_before then
    raise exception 'Party trigger touched Classic room on delete';
  end if;
end;
$check$;

rollback;
select 'PASS: Party bet invalidation versions once, touches the room, and preserves Classic' as result;
