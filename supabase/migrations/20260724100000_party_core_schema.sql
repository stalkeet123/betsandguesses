-- Party Mode owns its authoritative state. No Classic game table or RPC is
-- modified here. Clients receive Party data only through security-definer RPCs.

create table if not exists public.party_challenges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  prompt_template text not null,
  rules text not null,
  answer_unit text not null,
  max_result integer not null default 999,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  constraint party_challenges_prompt_not_blank
    check (length(btrim(prompt_template)) between 8 and 240),
  constraint party_challenges_slug_valid
    check (slug ~ '^[a-z0-9_]{3,48}$'),
  constraint party_challenges_rules_not_blank
    check (length(btrim(rules)) between 3 and 320),
  constraint party_challenges_result_range
    check (max_result between 1 and 100000)
);

create table if not exists public.party_matches (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  turn_order uuid[] not null,
  turn_index integer not null default 0,
  state_version bigint not null default 0,
  created_at timestamptz not null default now(),
  constraint party_matches_turn_order_not_empty
    check (cardinality(turn_order) >= 3),
  constraint party_matches_turn_index_valid
    check (turn_index >= 0 and turn_index < cardinality(turn_order))
);

create table if not exists public.party_rounds (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  round_number integer not null,
  performer_id uuid not null references public.players(id) on delete restrict,
  witness_id uuid references public.players(id) on delete restrict,
  challenge_id uuid not null references public.party_challenges(id) on delete restrict,
  phase text not null default 'guessing',
  proposed_result integer,
  result_submitted_by uuid references public.players(id) on delete restrict,
  result_confirmed_by uuid references public.players(id) on delete restrict,
  performer_ready_at timestamptz,
  phase_started_at timestamptz not null default now(),
  phase_ends_at timestamptz,
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  unique (room_id, round_number),
  constraint party_rounds_number_positive check (round_number > 0),
  constraint party_rounds_phase_valid check (
    phase in (
      'guessing',
      'betting',
      'ready',
      'action',
      'resultEntry',
      'resultConfirm',
      'reveal'
    )
  ),
  constraint party_rounds_result_nonnegative
    check (proposed_result is null or proposed_result >= 0),
  constraint party_rounds_settlement_shape check (
    (settled_at is null)
    or (
      phase = 'reveal'
      and proposed_result is not null
      and result_submitted_by is not null
      and result_confirmed_by is not null
    )
  )
);

create table if not exists public.party_guesses (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  round_number integer not null,
  player_id uuid not null references public.players(id) on delete cascade,
  value integer not null,
  is_performer_prediction boolean not null default false,
  created_at timestamptz not null default now(),
  unique (room_id, round_number, player_id),
  constraint party_guesses_value_nonnegative check (value >= 0)
);

create table if not exists public.party_bets (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  round_number integer not null,
  player_id uuid not null references public.players(id) on delete cascade,
  slot_index integer not null,
  chips integer not null,
  client_action_id uuid not null,
  position_x double precision,
  position_y double precision,
  won boolean,
  created_at timestamptz not null default now(),
  unique (room_id, round_number, player_id, client_action_id),
  constraint party_bets_slot_valid check (slot_index between 0 and 4),
  constraint party_bets_chips_valid check (chips between 1 and 1000),
  constraint party_bets_position_x_valid
    check (position_x is null or position_x between 0 and 1),
  constraint party_bets_position_y_valid
    check (position_y is null or position_y between 0 and 1)
);

create table if not exists public.party_scores (
  room_id uuid not null references public.rooms(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  score integer not null default 15,
  primary key (room_id, player_id),
  constraint party_scores_nonnegative check (score >= 0)
);

create index if not exists party_rounds_room_phase_idx
  on public.party_rounds(room_id, phase);
create index if not exists party_guesses_round_idx
  on public.party_guesses(room_id, round_number);
create index if not exists party_bets_round_idx
  on public.party_bets(room_id, round_number);

create or replace function public.notify_party_room_state_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
begin
  v_room_id := case when tg_op = 'DELETE' then old.room_id else new.room_id end;
  update public.rooms
  set state_version = state_version
  where id = v_room_id;
  return null;
end;
$$;

drop trigger if exists party_matches_notify_room_state
on public.party_matches;
create trigger party_matches_notify_room_state
after insert or update or delete on public.party_matches
for each row
execute function public.notify_party_room_state_v1();

alter table public.party_challenges enable row level security;
alter table public.party_matches enable row level security;
alter table public.party_rounds enable row level security;
alter table public.party_guesses enable row level security;
alter table public.party_bets enable row level security;
alter table public.party_scores enable row level security;

-- No direct client policies are intentional. Party state is exposed through
-- phase-aware RPCs so guesses, bets, and proposed results cannot leak early.

revoke all on table public.party_challenges from public, anon, authenticated;
revoke all on table public.party_matches from public, anon, authenticated;
revoke all on table public.party_rounds from public, anon, authenticated;
revoke all on table public.party_guesses from public, anon, authenticated;
revoke all on table public.party_bets from public, anon, authenticated;
revoke all on table public.party_scores from public, anon, authenticated;
