update public.questions
set access_tier='starter'
where is_active=true
  and access_tier='premium'
  and text_en in (
    'How many studio albums did Queen release?',
    'How many musicians perform annually at the Glastonbury music festival lineup?',
    'How many pipes does a large cathedral organ typically have?',
    'About how many minutes did Queen''s famous Live Aid set at Wembley last?',
    'How many studio albums has ABBA released through Voyage?',
    'How many tracks are on the original edition of Pink Floyd''s The Wall?',
    'About how many minutes long is Oppenheimer?',
    'About how many minutes long is Titanic?',
    'About how many minutes long is Jurassic Park?',
    'About how many minutes long is Home Alone?',
    'How many competitive Academy Awards did The Lord of the Rings: The Return of the King win?',
    'About how many million US dollars has The Super Mario Bros. Movie grossed worldwide?',
    'How many wedding ceremonies take place in the United States every year?',
    'How many pages are in the longest novel ever published?',
    'How many miles of shelving exist within the Library of Congress?',
    'How many laps are completed in the Indianapolis 500 race?'
  );

with new_questions(text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier) as (
  values
  ('Bir NBA takımı normal sezonda kaç maç oynar?','How many games does an NBA team play in a regular season?',82,'games','Sports',2,'NBA','starter'),
  ('Bir MLB takımı normal sezonda kaç maç oynar?','How many games does an MLB team play in a regular season?',162,'games','Sports',2,'MLB','starter')
)
insert into public.questions (text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier,is_active)
select nq.text_tr,nq.text_en,nq.answer,nq.answer_unit,nq.category,nq.difficulty,nq.source,nq.access_tier,true
from new_questions nq
where not exists (
  select 1 from public.questions q where lower(btrim(q.text_en))=lower(btrim(nq.text_en))
);