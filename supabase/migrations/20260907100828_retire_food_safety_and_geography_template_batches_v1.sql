update public.questions
set is_active=false
where is_active=true
  and category='Food'
  and (
    text_en ilike 'According to USDA%'
    or text_en ilike 'In USDA%'
    or text_en ilike 'When the air temperature is above%'
    or source ilike 'USDA%'
    or source ilike 'U.S. FDA%'
  );

update public.questions
set is_active=false
where is_active=true
  and category='Geography'
  and access_tier='premium'
  and (
    text_en ilike 'Approximately how many kilometers long is the %'
    or text_en ilike 'Approximately how many meters is the maximum depth of %'
    or text_en='What is the approximate length of the Amazon River in km?'
    or text_en='What is the approximate population of Istanbul in millions (2024)?'
    or text_en='What is the area of Turkey in thousand km²?'
  );