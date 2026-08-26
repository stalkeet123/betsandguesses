begin;
do $migration$
declare
  v_place_oid regprocedure := 'public.place_party_poll_bet_v1(uuid,uuid,integer,uuid,double precision,double precision)'::regprocedure;
  v_move_oid regprocedure := 'public.move_party_poll_bet_v1(uuid,uuid,uuid,double precision,double precision)'::regprocedure;
  v_def text;
  v_next text;
begin
  select pg_get_functiondef(v_place_oid) into v_def;
  v_next := replace(v_def, 'if v_slot_index < 0 or v_slot_index > 7 then', 'if v_slot_index < 0 or v_slot_index > 9 then');
  if v_next = v_def and position('v_slot_index > 9' in v_def) = 0 then
    raise exception 'place_party_poll_bet_v1 slot-bound marker not found';
  end if;
  if v_next <> v_def then execute v_next; end if;

  select pg_get_functiondef(v_move_oid) into v_def;
  v_next := replace(v_def, 'if v_slot_index not between 0 and 7 then', 'if v_slot_index not between 0 and 9 then');
  if v_next = v_def and position('v_slot_index not between 0 and 9' in v_def) = 0 then
    raise exception 'move_party_poll_bet_v1 slot-bound marker not found';
  end if;
  if v_next <> v_def then execute v_next; end if;
end;
$migration$;

do $$
declare v_place text; v_move text;
begin
  select pg_get_functiondef('public.place_party_poll_bet_v1(uuid,uuid,integer,uuid,double precision,double precision)'::regprocedure) into v_place;
  select pg_get_functiondef('public.move_party_poll_bet_v1(uuid,uuid,uuid,double precision,double precision)'::regprocedure) into v_move;
  if position('v_slot_index > 9' in v_place) = 0 then raise exception 'place slot bound not updated'; end if;
  if position('v_slot_index not between 0 and 9' in v_move) = 0 then raise exception 'move slot bound not updated'; end if;
end $$;
commit;