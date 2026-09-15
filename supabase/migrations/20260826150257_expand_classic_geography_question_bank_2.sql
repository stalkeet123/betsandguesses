begin;
create temporary table _geography_stage_2 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _geography_stage_2 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|geography|2|' || v.text_en)::uuid,v.text_en,v.answer,v.answer_unit,v.difficulty,v.source
from (values
('Approximately how many meters above sea level is the summit of Mount Everest?',8849,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of K2?',8611,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Kangchenjunga?',8586,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Lhotse?',8516,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Makalu?',8485,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Cho Oyu?',8188,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Dhaulagiri I?',8167,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Manaslu?',8163,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Nanga Parbat?',8126,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Annapurna I?',8091,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Gasherbrum I?',8080,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Broad Peak?',8051,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Gasherbrum II?',8035,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Shishapangma?',8027,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Aconcagua?',6961,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Denali?',6190,'meters',2,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Mount Kilimanjaro?',5895,'meters',3,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Mount Elbrus?',5642,'meters',3,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Vinson Massif?',4892,'meters',3,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Puncak Jaya?',4884,'meters',3,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Mont Blanc?',4806,'meters',3,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Matterhorn?',4478,'meters',3,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Mount Fuji?',3776,'meters',3,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Mount Olympus in Greece?',2918,'meters',3,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many meters above sea level is the summit of Mount Kosciuszko?',2228,'meters',3,'Encyclopaedia Britannica and national mapping data'),
('Approximately how many kilometers long is the Yangtze River?',6300,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Mississippi-Missouri river system?',6275,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Yenisei-Angara-Selenga river system?',5539,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Yellow River?',5464,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Ob-Irtysh river system?',5410,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Paraná River?',4880,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Congo River?',4700,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Amur River?',4444,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Lena River?',4400,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Mekong River?',4350,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Mackenzie river system?',4241,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Niger River?',4184,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Murray-Darling river system?',3672,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Volga River?',3530,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many kilometers long is the Danube River?',2850,'kilometers',3,'Encyclopaedia Britannica geographic data'),
('Approximately how many meters is the maximum depth of Lake Baikal?',1642,'meters',3,'Encyclopaedia Britannica and limnological reference data'),
('Approximately how many meters is the maximum depth of Lake Tanganyika?',1470,'meters',3,'Encyclopaedia Britannica and limnological reference data'),
('Approximately how many meters is the maximum depth of Caspian Sea?',1025,'meters',3,'Encyclopaedia Britannica and limnological reference data'),
('Approximately how many meters is the maximum depth of Lake Malawi?',706,'meters',3,'Encyclopaedia Britannica and limnological reference data'),
('Approximately how many meters is the maximum depth of Issyk-Kul?',668,'meters',3,'Encyclopaedia Britannica and limnological reference data'),
('Approximately how many meters is the maximum depth of Great Slave Lake?',614,'meters',3,'Encyclopaedia Britannica and limnological reference data'),
('Approximately how many meters is the maximum depth of Crater Lake in Oregon?',594,'meters',3,'Encyclopaedia Britannica and limnological reference data'),
('Approximately how many meters is the maximum depth of Lake Tahoe?',501,'meters',3,'Encyclopaedia Britannica and limnological reference data'),
('Approximately how many meters is the maximum depth of Lake Superior?',406,'meters',3,'Encyclopaedia Britannica and limnological reference data'),
('Approximately how many meters is the maximum depth of Lake Geneva?',310,'meters',3,'Encyclopaedia Britannica and limnological reference data')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int;v_texts int;v_collisions int;v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _geography_stage_2;
  if v_rows<>50 or v_texts<>50 then raise exception 'Geography batch 2 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _geography_stage_2 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Geography batch 2 invalid content'; end if;
  select count(*) into v_ids from _geography_stage_2 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Geography batch 2 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _geography_stage_2 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Geography batch 2 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Geography',difficulty,source,'premium' from _geography_stage_2;

do $$
declare v_inserted int;v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _geography_stage_2 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Geography batch 2 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _geography_stage_2 s on s.id=q.id
  where q.category<>'Geography' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Geography batch 2 post validation failed: %',v_bad; end if;
end $$;
commit;