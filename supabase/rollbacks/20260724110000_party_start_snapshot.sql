drop function if exists public.start_party_game_v1(uuid, integer);
drop function if exists public.get_party_snapshot_v1(uuid);

delete from public.party_challenges
where slug in (
  'push_ups',
  'squats',
  'jumping_jacks',
  'countries',
  'movie_titles',
  'paper_cup',
  'coin_catches',
  'tongue_twister',
  'toe_touches',
  'knee_raises',
  'animals',
  'count_by_threes'
);
