begin;

drop trigger if exists rooms_reveal_answer_deadline_v1 on public.rooms;
drop function if exists public.set_reveal_answer_deadline_v1();

commit;
