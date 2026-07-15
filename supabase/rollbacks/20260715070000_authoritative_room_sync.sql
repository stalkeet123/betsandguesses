begin;

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
security invoker
set search_path = public
as $$
declare
  v_room public.rooms%rowtype;
  v_effective_round integer;
begin
  if p_duration_seconds is not null and p_duration_seconds < 1 then
    raise exception using errcode = '22023', message = 'Invalid duration';
  end if;

  if not (
    (p_expected_phase = 'question' and p_next_phase = 'guessing') or
    (p_expected_phase = 'guessing' and p_next_phase = 'betting') or
    (p_expected_phase = 'revealAnswer' and p_next_phase = 'question')
  ) then
    raise exception using errcode = '22023', message = 'Invalid phase transition';
  end if;

  if p_expected_phase = 'revealAnswer' and
     (p_next_round is null or p_next_round <> p_round_number + 1) then
    raise exception using errcode = '22023', message = 'Invalid next round';
  end if;

  if p_expected_phase <> 'revealAnswer' and
     p_next_round is not null and p_next_round <> p_round_number then
    raise exception using errcode = '22023', message = 'Unexpected round change';
  end if;

  v_effective_round := coalesce(p_next_round, p_round_number);

  update public.rooms
  set current_round = v_effective_round,
      round_phase = p_next_phase,
      current_question_id = coalesce(
        p_current_question_id,
        current_question_id
      ),
      phase_started_at = statement_timestamp(),
      phase_ends_at = case
        when p_duration_seconds is null then null
        else statement_timestamp() + make_interval(secs => p_duration_seconds)
      end
  where id = p_room_id
    and current_round = p_round_number
    and round_phase = p_expected_phase
    and status = 'playing'
  returning * into v_room;

  if not found then
    return null;
  end if;

  return to_jsonb(v_room);
end;
$$;

revoke all on function public.claim_game_phase_v1(
  uuid, integer, text, text, integer, integer, uuid
) from public;
grant execute on function public.claim_game_phase_v1(
  uuid, integer, text, text, integer, integer, uuid
) to anon, authenticated;

commit;
