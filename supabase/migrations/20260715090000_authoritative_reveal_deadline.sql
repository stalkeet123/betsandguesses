begin;

create or replace function public.set_reveal_answer_deadline_v1()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.round_phase = 'revealAnswer'
     and old.round_phase is distinct from new.round_phase then
    new.phase_started_at = coalesce(new.phase_started_at, statement_timestamp());
    new.phase_ends_at = coalesce(
      new.phase_ends_at,
      statement_timestamp() + interval '7 seconds'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists rooms_reveal_answer_deadline_v1 on public.rooms;
create trigger rooms_reveal_answer_deadline_v1
before update of round_phase on public.rooms
for each row
execute function public.set_reveal_answer_deadline_v1();

commit;
