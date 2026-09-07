update public.questions
set is_active = false
where is_active = true
  and category in ('Science','Sports')
  and text_en ilike 'In what year%';