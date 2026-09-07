-- Retire remaining specification-sheet technology questions.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Technology'
  and (
    text_en ilike '%3S%'
    or text_en ilike '%ASCII%'
    or text_en ilike '%RGB%'
    or text_en ilike '%Apple M1%'
    or text_en ilike '%cloud provider%'
    or text_en ilike '%IMEI%'
    or text_en ilike '%Concorde%'
    or text_en ilike '%Boeing 787%'
    or text_en ilike '%Airbus A380%'
    or text_en ilike '%Boeing 747 have%'
    or text_en ilike '%frames per second%'
    or text_en ilike '%gigahertz%'
    or text_en ilike '%hertz is a display%'
    or text_en ilike '%kilowatts are in one megawatt%'
    or text_en ilike '%megawatts are in one gigawatt%'
    or text_en ilike '%OSI networking model%'
    or text_en ilike '%nanometers%'
    or text_en ilike '%passenger decks%'
    or text_en ilike '%pins%'
    or text_en ilike '%pixels high%'
    or text_en ilike '%pixels wide%'
    or text_en ilike '%possible values%'
    or text_en ilike '%AES-192%'
    or text_en ilike '%satellites are currently orbiting%'
    or text_en ilike '%symbols are used in binary%'
    or text_en ilike '%total pixels%'
    or text_en ilike '%automotive 12-volt%'
    or text_en ilike '%lithium-ion cell%'
    or text_en ilike '%watts is one kilowatt%'
    or text_en ilike '%default port number for DNS%'
    or text_en ilike '%App Store as of its tenth anniversary%'
    or text_en ilike '%elevator cable travel%'
  );

with ranked as (
  select
    id,
    row_number() over (
      partition by lower(btrim(text_en))
      order by case when access_tier = 'starter' then 0 else 1 end, id
    ) as rn
  from public.questions
  where is_active = true
    and text_en is not null
    and btrim(text_en) <> ''
)
update public.questions q
set is_active = false
from ranked r
where q.id = r.id
  and r.rn > 1;