with ranked as (
  select
    id,
    row_number() over (
      partition by lower(btrim(text_en))
      order by id
    ) as rn
  from public.questions
  where access_tier = 'starter'
    and is_active = true
    and text_en is not null
    and btrim(text_en) <> ''
)
update public.questions q
set is_active = false
from ranked r
where q.id = r.id
  and r.rn > 1;