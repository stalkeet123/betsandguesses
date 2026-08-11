-- A Classic question is considered used as soon as it is selected, not only
-- after a player submits a guess. This prevents repeats when a round times
-- out or every player skips the guess phase.
begin;

create table if not exists public.classic_question_history (
  room_id uuid not null references public.rooms(id) on delete cascade,
  question_id uuid not null references public.questions(id),
  round_number integer not null check (round_number > 0),
  selected_at timestamptz not null default statement_timestamp(),
  primary key (room_id, question_id)
);

alter table public.classic_question_history enable row level security;

-- Preserve history for a game that happens to be running during deployment.
insert into public.classic_question_history (room_id, question_id, round_number)
select
  g.room_id,
  g.question_id,
  min(g.round_number)
from public.guesses g
join public.rooms r on r.id = g.room_id
where r.game_mode = 'classic'
  and g.question_id is not null
group by g.room_id, g.question_id
on conflict (room_id, question_id) do nothing;

insert into public.classic_question_history (room_id, question_id, round_number)
select r.id, r.current_question_id, r.current_round
from public.rooms r
where r.game_mode = 'classic'
  and r.status = 'playing'
  and r.current_question_id is not null
  and r.current_round > 0
on conflict (room_id, question_id) do nothing;

create or replace function public.pick_question_id_v2(
  p_room_id uuid,
  p_category text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_room public.rooms%rowtype;
  v_question_id uuid;
begin
  -- All callers now serialize selection on the room row. The lock also makes
  -- the history insert safe if a client retries a transition request.
  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found or v_room.game_mode <> 'classic' then
    return null;
  end if;

  -- A room can host another match after reset. Its prior match should not
  -- consume the new match's entire deck.
  if v_room.status = 'waiting' and v_room.current_round = 0 then
    delete from public.classic_question_history where room_id = p_room_id;
  end if;

  select q.id
  into v_question_id
  from public.questions q
  where (
      p_category is null
      or btrim(p_category) = ''
      or lower(btrim(p_category)) = 'mixed'
      or q.category = p_category
    )
    and not exists (
      select 1
      from public.classic_question_history h
      where h.room_id = p_room_id
        and h.question_id = q.id
    )
    and not exists (
      -- Different imported ids can still contain the same user-facing text.
      select 1
      from public.classic_question_history h
      join public.questions used_question on used_question.id = h.question_id
      where h.room_id = p_room_id
        and (
          nullif(lower(btrim(used_question.text_en)), '') =
            nullif(lower(btrim(q.text_en)), '')
          or lower(btrim(used_question.text_tr)) = lower(btrim(q.text_tr))
        )
    )
  order by random()
  limit 1;

  -- Never intentionally repeat within the same match. If a filtered category
  -- has fewer questions than the requested rounds, surface that explicitly.
  if v_question_id is null then
    return null;
  end if;

  insert into public.classic_question_history (
    room_id, question_id, round_number
  ) values (
    p_room_id,
    v_question_id,
    case
      when v_room.status = 'waiting' then 1
      else v_room.current_round
    end
  )
  on conflict (room_id, question_id) do nothing;

  return v_question_id;
end;
$$;

revoke all on table public.classic_question_history from public, anon, authenticated;
revoke all on function public.pick_question_id_v2(uuid, text)
  from public, anon, authenticated;

commit;
