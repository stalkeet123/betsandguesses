-- One MVCC read snapshot for Classic recovery. No game mutation, quota use,
-- phase advance, or new answer access. Existing table RLS remains authoritative.
begin;
set local lock_timeout = '5s';

create or replace function public.get_classic_snapshot_v1(p_room_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_room public.rooms%rowtype;
begin
  if not public.is_room_member_v2(p_room_id) then
    raise exception using errcode = '42501', message = 'Room membership required';
  end if;
  select * into v_room from public.rooms where id = p_room_id;
  if not found or coalesce(v_room.game_mode, 'classic') <> 'classic' then
    raise exception using errcode = '22023', message = 'Classic room required';
  end if;
  return jsonb_build_object(
    'room', to_jsonb(v_room),
    'server_now', statement_timestamp(),
    'question', public.get_current_question_v2(p_room_id),
    'players', coalesce((select jsonb_agg(to_jsonb(p) order by p.joined_at, p.id)
      from (select id, room_id, device_id, name, avatar_color, score, bank_score,
                   is_host, is_ready, is_connected, last_seen, joined_at
            from public.players where room_id = p_room_id) p), '[]'::jsonb),
    'guesses', coalesce((select jsonb_agg(to_jsonb(g) order by g.value, g.id)
      from (select id, room_id, round_number, player_id, question_id, value, is_winner
            from public.guesses where room_id = p_room_id
              and round_number = v_room.current_round) g), '[]'::jsonb),
    'bets', coalesce((select jsonb_agg(to_jsonb(b) order by b.id)
      from (select id, room_id, round_number, player_id, target_guess_id,
                   slot_index, chips, payout_multiplier, won, position_x, position_y
            from public.bets where room_id = p_room_id
              and round_number = v_room.current_round) b), '[]'::jsonb)
  );
end;
$function$;
revoke all on function public.get_classic_snapshot_v1(uuid) from public, anon;
grant execute on function public.get_classic_snapshot_v1(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
