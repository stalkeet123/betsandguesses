begin;
update public.party_challenges
set rules = 'Use each of your 5, 10, and 20 chips at most once across up to three players. Chip value is voting weight; the highest total chip weight wins.'
where enabled = true and challenge_type = 'poll';

do $$ declare v_bad int; begin
  select count(*) into v_bad from public.party_challenges
  where enabled = true and challenge_type = 'poll'
    and rules <> 'Use each of your 5, 10, and 20 chips at most once across up to three players. Chip value is voting weight; the highest total chip weight wins.';
  if v_bad <> 0 then raise exception 'Party poll rules alignment failed: %', v_bad; end if;
end $$;
commit;