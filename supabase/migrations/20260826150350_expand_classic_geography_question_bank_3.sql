begin;
create temporary table _geography_stage_3 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _geography_stage_3 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|geography|3|' || v.text_en)::uuid,v.text_en,v.answer,v.answer_unit,v.difficulty,v.source
from (values
('How many sovereign countries share a land border with China?',14,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Russia?',14,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Brazil?',10,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Democratic Republic of the Congo?',9,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Germany?',9,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Austria?',8,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Turkey?',8,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Zambia?',8,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Tanzania?',8,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Poland?',7,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Ukraine?',7,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Hungary?',7,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Sudan?',7,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Mali?',7,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Niger?',7,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with South Africa?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with South Sudan?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Central African Republic?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Chad?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Libya?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Ethiopia?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Mozambique?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Cameroon?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Guinea?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Burkina Faso?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Italy?',6,'countries',3,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Bolivia?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Peru?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Colombia?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Argentina?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Kazakhstan?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Switzerland?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Romania?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Bulgaria?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Slovakia?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Côte d''Ivoire?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Kenya?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Uganda?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Senegal?',5,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Belgium?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Greece?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Slovenia?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Lithuania?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Latvia?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Guatemala?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Nigeria?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Benin?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Rwanda?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Zimbabwe?',4,'countries',2,'CIA World Factbook boundary data'),
('How many sovereign countries share a land border with Botswana?',4,'countries',2,'CIA World Factbook boundary data')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int;v_texts int;v_collisions int;v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _geography_stage_3;
  if v_rows<>50 or v_texts<>50 then raise exception 'Geography batch 3 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _geography_stage_3 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Geography batch 3 invalid content'; end if;
  select count(*) into v_ids from _geography_stage_3 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Geography batch 3 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _geography_stage_3 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Geography batch 3 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Geography',difficulty,source,'premium' from _geography_stage_3;

do $$
declare v_inserted int;v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _geography_stage_3 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Geography batch 3 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _geography_stage_3 s on s.id=q.id
  where q.category<>'Geography' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Geography batch 3 post validation failed: %',v_bad; end if;
end $$;
commit;