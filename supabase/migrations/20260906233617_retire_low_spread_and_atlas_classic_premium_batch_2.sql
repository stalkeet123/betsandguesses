-- Geography: remove the mass-produced country-area template and tiny border/count recall questions.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Geography'
  and (
    text_en ilike 'According to standard international area data%'
    or answer <= 10
  );

-- General: remove obvious one-answer-known-by-everyone questions that create almost no guess spread.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'General'
  and coalesce(difficulty, 3) = 1
  and answer <= 10;

-- Sports: remove basic rulebook facts with tiny answers; they reward recall and collapse the betting board.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Sports'
  and coalesce(difficulty, 3) = 1
  and answer <= 10;