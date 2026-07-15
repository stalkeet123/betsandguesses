begin;

alter table public.bets replica identity default;

alter table public.bets
  drop column if exists position_y,
  drop column if exists position_x;

-- Publication membership is intentionally retained because it may have
-- existed before this migration and is harmless without active listeners.

commit;
