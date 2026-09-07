update public.questions set is_active=false
where coalesce(is_active,true) and text_en in (
  'How many fireworks are launched during a major New Year''s Eve display like Dubai''s?',
  'How many musicians perform annually at the Glastonbury music festival lineup?'
);