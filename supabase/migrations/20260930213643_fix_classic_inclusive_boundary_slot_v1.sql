-- Production already received this hotfix. Keep migration history aligned while
-- preserving the deployed settlement function's auth, scoring, payouts, phase
-- transitions, and SQLSTATE behavior exactly as they are.
do $$
declare
  v_function_oid regprocedure := 'public.settle_game_round_v2(uuid, integer)'::regprocedure;
  v_definition text;
  v_rewritten text;
begin
  select pg_get_functiondef(v_function_oid) into v_definition;

  v_rewritten := regexp_replace(
    v_definition,
    E'v_winning_slot\\s*:=\\s*case\\s*\n\\s*when\\s+v_answer\\s*<\\s*v_boundaries\\[1\\]\\s+then\\s+0\\s*\n\\s*when\\s+v_answer\\s*<\\s*v_boundaries\\[2\\]\\s+then\\s+1\\s*\n\\s*when\\s+v_answer\\s*<=\\s*v_boundaries\\[3\\]\\s+then\\s+2\\s*\n\\s*when\\s+v_answer\\s*<=\\s*v_boundaries\\[4\\]\\s+then\\s+3\\s*\n\\s*else\\s+4\\s*\n\\s*end;',
    E'v_winning_slot := case\n      when v_answer <  v_boundaries[1] then 0\n      when v_answer <= v_boundaries[2] then 1\n      when v_answer <  v_boundaries[3] then 2\n      when v_answer <= v_boundaries[4] then 3\n      else 4\n    end;'
  );

  if v_rewritten <> v_definition then
    execute v_rewritten;
  elsif v_definition ~ E'v_winning_slot\\s*:=\\s*case\\s*\n\\s*when\\s+v_answer\\s*<\\s*v_boundaries\\[1\\]\\s+then\\s+0\\s*\n\\s*when\\s+v_answer\\s*<=\\s*v_boundaries\\[2\\]\\s+then\\s+1\\s*\n\\s*when\\s+v_answer\\s*<\\s*v_boundaries\\[3\\]\\s+then\\s+2\\s*\n\\s*when\\s+v_answer\\s*<=\\s*v_boundaries\\[4\\]\\s+then\\s+3\\s*\n\\s*else\\s+4\\s*\n\\s*end;' then
    null;
  else
    raise exception 'settle_game_round_v2 winning-slot CASE was not recognized';
  end if;
end;
$$;
