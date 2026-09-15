-- Food: remove nutrition-database and regulatory-label phrasing that feels like a test sheet.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Food'
  and (
    text_en ilike 'According to USDA food composition data%'
    or text_en ilike 'Under USDA%'
    or text_en ilike 'On the U.S. FDA Daily Value system%'
    or text_en ilike 'For U.S. nutrition labeling%'
  );

-- Science: remove lab-unit and obscure-moon lookup questions.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Science'
  and (
    text_en ilike '%kelvin%'
    or text_en ilike '%parts per million%'
    or text_en ilike '%Saturn''s moon%'
    or text_en ilike '%Jupiter''s moon%'
    or text_en ilike '%Uranus''s moon%'
    or text_en ilike '%Neptune''s moon%'
  );

-- Technology: remove remaining protocol/space-count leftovers that slipped through earlier sweeps.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Technology'
  and (
    text_en ilike '%IPv4%'
    or text_en ilike '%Hubble Space Telescope%'
    or text_en ilike '%International Space Station%'
  );