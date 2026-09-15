-- Portable equivalent of the production cleanup: avoid generated UUIDs so fresh databases reconcile correctly.
update public.questions
set is_active=false
where category='Technology'
  and text_en='About how many miles of steel wire are packed into the Golden Gate Bridge’s two main cables?';

update public.questions
set is_active=false
where category='Science'
  and text_en='What is the speed of light in thousand km per second?';