BEGIN;

UPDATE public.party_challenges
SET enabled = false
WHERE challenge_type = 'poll';

WITH final_prompts AS (
  SELECT prompt_template, ordinality
  FROM unnest(ARRAY[
    $q$Who would survive the longest on a deserted island?$q$,
    $q$Who would accidentally become famous?$q$,
    $q$Who would be the best person to have with you during a zombie apocalypse?$q$,
    $q$Who would spend a lottery win the fastest?$q$,
    $q$Who would keep a huge secret the longest?$q$,
    $q$Who would be most likely to talk their way out of trouble?$q$,
    $q$Who would make the best detective?$q$,
    $q$Who would get lost even with GPS?$q$,
    $q$Who would be the first to fall asleep during a movie night?$q$,
    $q$Who would be most likely to start a business that actually succeeds?$q$,
    $q$Who would survive the longest without their phone?$q$,
    $q$Who would make the best reality-show contestant?$q$,
    $q$Who would be most likely to miss a flight?$q$,
    $q$Who would win a debate without knowing anything about the topic?$q$,
    $q$Who would be the best undercover spy?$q$,
    $q$Who would be most likely to adopt a random stray animal?$q$,
    $q$Who would take the longest to get ready for a night out?$q$,
    $q$Who would make the best game-show host?$q$,
    $q$Who would be most likely to laugh at the worst possible moment?$q$,
    $q$Who would win if everyone here had to live in the wilderness for a month?$q$,
    $q$Who would be most likely to become a millionaire?$q$,
    $q$Who would be the first person to panic in an escape room?$q$,
    $q$Who would make the best villain in a movie?$q$,
    $q$Who would be most likely to forget their own birthday plans?$q$,
    $q$Who would be the best at convincing aliens that humans are worth saving?$q$,
    $q$Who would be most likely to order food for everyone without asking?$q$,
    $q$Who would win a competition based entirely on luck?$q$,
    $q$Who would be the hardest person here to surprise?$q$,
    $q$Who would make the best teacher?$q$,
    $q$Who would be most likely to accidentally send a message to the wrong person?$q$,
    $q$Who would be the best person to plan a spontaneous road trip?$q$,
    $q$Who would complain the most if the Wi-Fi disappeared for a week?$q$,
    $q$Who would make the best stand-up comedian?$q$,
    $q$Who would be most likely to become friends with a complete stranger in five minutes?$q$,
    $q$Who would survive longest in a haunted house?$q$,
    $q$Who would be most likely to buy something ridiculous at 3 a.m.?$q$,
    $q$Who would make the best leader during a crisis?$q$,
    $q$Who would be most likely to forget where they parked?$q$,
    $q$Who would win a poker game without knowing the rules?$q$,
    $q$Who would be most likely to turn a small story into a 20-minute story?$q$,
    $q$Who would make the best celebrity personal assistant?$q$,
    $q$Who would be most likely to discover a hidden talent later in life?$q$,
    $q$Who would be the first to break a “no phones” rule?$q$,
    $q$Who would make the best chef using only random leftovers?$q$,
    $q$Who would be most likely to survive an entire day with only five euros?$q$,
    $q$Who would make the best secret agent despite being terrible at keeping secrets?$q$,
    $q$Who would be most likely to start dancing when nobody else is dancing?$q$,
    $q$Who would win a challenge where nobody is allowed to laugh?$q$,
    $q$Who would be most likely to become obsessed with a new hobby overnight?$q$,
    $q$Who would make the best captain of a pirate ship?$q$,
    $q$Who would be most likely to accidentally start an argument in a group chat?$q$,
    $q$Who would be best at pretending to know a celebrity personally?$q$,
    $q$Who would be most likely to bring way too much luggage for a weekend trip?$q$,
    $q$Who would win a contest for making the best excuse?$q$,
    $q$Who would be most likely to remember a tiny detail from five years ago?$q$,
    $q$Who would make the best motivational speaker?$q$,
    $q$Who would be most likely to eat someone else’s fries without asking?$q$,
    $q$Who would survive the longest if everyone had to swap jobs for a week?$q$,
    $q$Who would be most likely to turn up to the wrong event?$q$,
    $q$Who would make the best host for a huge party?$q$,
    $q$Who would be most likely to become a conspiracy theorist about something completely harmless?$q$,
    $q$Who would win a challenge where everyone has to bluff?$q$,
    $q$Who would be most likely to spend an hour choosing what to watch and then watch nothing?$q$,
    $q$Who would make the best travel partner on a chaotic trip?$q$,
    $q$Who would be most likely to accidentally reveal a surprise party?$q$,
    $q$Who would win if everyone here had to negotiate the price of the same item?$q$,
    $q$Who would be most likely to make friends with the hotel staff on vacation?$q$,
    $q$Who would make the best lawyer in a completely ridiculous court case?$q$,
    $q$Who would be most likely to turn a five-minute errand into a two-hour adventure?$q$,
    $q$Who would survive the longest in a world where nobody could use money?$q$,
    $q$Who would be most likely to invent a nickname that everyone starts using?$q$,
    $q$Who would make the best teammate in a high-pressure competition?$q$,
    $q$Who would be most likely to recognize an actor but never remember their name?$q$,
    $q$Who would win a challenge where everyone has to improvise a speech?$q$,
    $q$Who would be most likely to convince the group to change all the plans at the last minute?$q$,
    $q$Who would make the best fictional superhero?$q$,
    $q$Who would be most likely to leave a party without saying goodbye?$q$,
    $q$Who would win if everyone had to sell a completely useless product?$q$,
    $q$Who would be most likely to become a regular at a place after visiting only twice?$q$,
    $q$Who would make the best person to call when everything has gone wrong?$q$,
    $q$Who would be most likely to accidentally go viral online?$q$,
    $q$Who would win a competition where confidence matters more than skill?$q$,
    $q$Who would be most likely to say “I know a shortcut” and make the journey longer?$q$,
    $q$Who would make the best contestant on a survival reality show?$q$,
    $q$Who would be most likely to remember everybody’s food order?$q$,
    $q$Who would win if everyone had to make strangers laugh?$q$,
    $q$Who would be most likely to start packing for a trip at the very last minute?$q$,
    $q$Who would make the best mastermind for an elaborate prank?$q$,
    $q$Who would be most likely to turn a simple board game into a serious competition?$q$,
    $q$Who would win a challenge where everyone has to stay calm under pressure?$q$,
    $q$Who would be most likely to become the unofficial leader of a group of strangers?$q$,
    $q$Who would make the best commentator for everyone else’s daily life?$q$,
    $q$Who would be most likely to find something valuable at a flea market?$q$,
    $q$Who would win if everyone had to convince a bouncer they were on the guest list?$q$,
    $q$Who would be most likely to make an ordinary story sound unbelievable?$q$,
    $q$Who would make the best partner for a completely unplanned adventure?$q$,
    $q$Who would be most likely to notice first that something in the room has changed?$q$,
    $q$Who would win if everyone had 24 hours to learn a completely new skill?$q$,
    $q$Who would be most likely to turn a disaster into a funny story later?$q$,
    $q$Who would the group trust most to make one important decision for everyone?$q$
  ]::text[]) WITH ORDINALITY AS q(prompt_template, ordinality)
)
INSERT INTO public.party_challenges (
  slug, prompt_template, rules, answer_unit, max_result, enabled,
  bet_boundaries, challenge_type, duration_seconds, performer_success_bonus,
  category, result_direction, required_items, option_a, option_b
)
SELECT
  format('poll_v2_%s', lpad(ordinality::text, 3, '0')),
  prompt_template,
  'Each chip counts at face value. Highest total chip weight wins.',
  'player',
  7,
  true,
  null,
  'poll',
  30,
  15,
  'poll',
  'higher',
  '{}'::text[],
  null,
  null
FROM final_prompts
ON CONFLICT (slug) DO UPDATE SET
  prompt_template = EXCLUDED.prompt_template,
  rules = EXCLUDED.rules,
  answer_unit = EXCLUDED.answer_unit,
  max_result = EXCLUDED.max_result,
  enabled = EXCLUDED.enabled,
  bet_boundaries = EXCLUDED.bet_boundaries,
  challenge_type = EXCLUDED.challenge_type,
  duration_seconds = EXCLUDED.duration_seconds,
  performer_success_bonus = EXCLUDED.performer_success_bonus,
  category = EXCLUDED.category,
  result_direction = EXCLUDED.result_direction,
  required_items = EXCLUDED.required_items,
  option_a = EXCLUDED.option_a,
  option_b = EXCLUDED.option_b;

DO $$
DECLARE
  v_enabled_poll_count integer;
  v_enabled_v2_count integer;
  v_invalid_v2_count integer;
  v_duplicate_prompt_count integer;
BEGIN
  SELECT count(*) INTO v_enabled_poll_count
  FROM public.party_challenges
  WHERE challenge_type = 'poll' AND enabled IS TRUE;
  IF v_enabled_poll_count <> 100 THEN
    RAISE EXCEPTION 'Expected exactly 100 enabled Party Poll challenges, found %', v_enabled_poll_count;
  END IF;

  SELECT count(*) INTO v_enabled_v2_count
  FROM public.party_challenges
  WHERE slug LIKE 'poll_v2_%' AND challenge_type = 'poll' AND enabled IS TRUE;
  IF v_enabled_v2_count <> 100 THEN
    RAISE EXCEPTION 'Expected exactly 100 enabled poll_v2 rows, found %', v_enabled_v2_count;
  END IF;

  SELECT count(*) INTO v_invalid_v2_count
  FROM public.party_challenges
  WHERE slug LIKE 'poll_v2_%'
    AND (
      challenge_type <> 'poll'
      OR category <> 'poll'
      OR duration_seconds <> 30
      OR enabled IS NOT TRUE
      OR answer_unit <> 'player'
      OR max_result <> 7
      OR rules <> 'Each chip counts at face value. Highest total chip weight wins.'
    );
  IF v_invalid_v2_count <> 0 THEN
    RAISE EXCEPTION 'Found % invalid poll_v2 rows', v_invalid_v2_count;
  END IF;

  SELECT count(*) INTO v_duplicate_prompt_count
  FROM (
    SELECT prompt_template
    FROM public.party_challenges
    WHERE slug LIKE 'poll_v2_%'
      AND challenge_type = 'poll'
      AND enabled IS TRUE
    GROUP BY prompt_template
    HAVING count(*) > 1
  ) d;
  IF v_duplicate_prompt_count <> 0 THEN
    RAISE EXCEPTION 'Found % duplicate enabled poll_v2 prompts', v_duplicate_prompt_count;
  END IF;
END
$$;

COMMIT;
