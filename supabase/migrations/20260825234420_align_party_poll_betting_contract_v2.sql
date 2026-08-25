do $migration$
declare
  v_place_oid regprocedure := 'public.place_party_poll_bet_v1(uuid,uuid,integer,uuid,double precision,double precision)'::regprocedure;
  v_move_oid regprocedure := 'public.move_party_poll_bet_v1(uuid,uuid,uuid,double precision,double precision)'::regprocedure;
  v_snapshot_oid regprocedure := 'public.get_party_poll_snapshot_v1(uuid)'::regprocedure;
  v_def text;
  v_next text;
begin
  select pg_get_functiondef(v_place_oid) into v_def;
  v_next := replace(v_def, 'if p_chips is null or p_chips not in (5, 10, 25) then', 'if p_chips is null or p_chips not in (5, 10, 20) then');
  v_next := replace(v_next, 'if v_other_target_count >= 2 then', 'if v_other_target_count >= 3 then');
  v_next := replace(v_next, 'POLL_MAX_TWO_TARGETS', 'POLL_MAX_THREE_TARGETS');
  v_next := replace(v_next, 'v_limit := 40;', 'v_limit := 35;');
  if v_next = v_def then
    raise exception 'place_party_poll_bet_v1 contract markers were not found';
  end if;
  execute v_next;

  select pg_get_functiondef(v_move_oid) into v_def;
  v_next := replace(v_def, 'if v_other_target_count >= 2 then', 'if v_other_target_count >= 3 then');
  v_next := replace(v_next, 'POLL_MAX_TWO_TARGETS', 'POLL_MAX_THREE_TARGETS');
  if v_next = v_def then
    raise exception 'move_party_poll_bet_v1 contract markers were not found';
  end if;
  execute v_next;

  select pg_get_functiondef(v_snapshot_oid) into v_def;
  v_next := replace(v_def, 'v_limit integer := 40;', 'v_limit integer := 35;');
  v_next := replace(v_next, 'v_limit := 40;', 'v_limit := 35;');
  if v_next = v_def then
    raise exception 'get_party_poll_snapshot_v1 contract markers were not found';
  end if;
  execute v_next;
end;
$migration$;
