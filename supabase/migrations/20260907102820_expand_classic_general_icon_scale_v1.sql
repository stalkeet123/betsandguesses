with new_questions(text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier) as (
  values
  ('Beyaz Saray’da toplam yaklaşık kaç oda vardır?','About how many rooms are inside the White House?',132,'rooms','General',2,'White House Historical Association','starter'),
  ('Beyaz Saray’da yaklaşık kaç banyo vardır?','About how many bathrooms are inside the White House?',35,'bathrooms','General',2,'White House Historical Association','premium'),
  ('Pentagon’un koridorlarını uç uca ekleseniz yaklaşık kaç mil eder?','If you laid all of the Pentagon’s corridors end to end, about how many miles would they stretch?',18,'miles','General',3,'U.S. Department of Defense','starter'),
  ('Pentagon binasında yaklaşık kaç pencere vardır?','About how many windows are in the Pentagon?',7754,'windows','General',3,'U.S. Department of Defense','premium'),
  ('ABD Kongre Binası Capitol’de yaklaşık kaç oda vardır?','About how many rooms are inside the U.S. Capitol?',540,'rooms','General',3,'Architect of the Capitol','starter'),
  ('Empire State Building’de yaklaşık kaç pencere vardır?','About how many windows does the Empire State Building have?',6514,'windows','General',3,'Empire State Building official facts','starter'),
  ('Empire State Building yaklaşık kaç ton ağırlığındadır?','About how many tons does the Empire State Building weigh?',365000,'tons','General',4,'Empire State Building official facts','premium'),
  ('Times Square yılbaşı topunun üzerinde kaç kristal üçgen vardır?','How many crystal triangles cover the Times Square New Year’s Eve Ball?',2688,'crystal triangles','General',3,'Times Square official facts','starter'),
  ('Times Square yılbaşı topu yaklaşık kaç pound ağırlığındadır?','About how many pounds does the Times Square New Year’s Eve Ball weigh?',11875,'pounds','General',4,'Times Square official facts','premium'),
  ('Özgürlük Heykeli’nin dışındaki bakır kaplama yaklaşık kaç pound gelir?','About how many pounds of copper make up the Statue of Liberty’s outer skin?',176000,'pounds of copper','General',4,'U.S. National Park Service','premium')
)
insert into public.questions (text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier,is_active)
select nq.text_tr,nq.text_en,nq.answer,nq.answer_unit,nq.category,nq.difficulty,nq.source,nq.access_tier,true
from new_questions nq
where not exists (
  select 1 from public.questions q where lower(btrim(q.text_en))=lower(btrim(nq.text_en))
);