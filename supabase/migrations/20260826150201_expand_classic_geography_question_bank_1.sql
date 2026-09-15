begin;
create temporary table _geography_stage_1 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _geography_stage_1 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|geography|1|' || v.text_en)::uuid,v.text_en,v.answer,v.answer_unit,v.difficulty,v.source
from (values
('According to standard international area data, approximately how many thousand square kilometers of total area does Russia have?',17098,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Canada have?',9985,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does United States have?',9834,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does China have?',9597,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Brazil have?',8516,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Australia have?',7692,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does India have?',3287,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Argentina have?',2780,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Kazakhstan have?',2725,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Algeria have?',2382,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Democratic Republic of the Congo have?',2345,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Saudi Arabia have?',2150,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Mexico have?',1964,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Indonesia have?',1905,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Sudan have?',1886,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Libya have?',1760,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Iran have?',1648,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Mongolia have?',1564,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Peru have?',1285,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Chad have?',1284,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Niger have?',1267,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Angola have?',1247,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Mali have?',1240,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does South Africa have?',1221,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Colombia have?',1142,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Ethiopia have?',1104,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Bolivia have?',1099,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Mauritania have?',1031,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Egypt have?',1001,'thousand square kilometers',2,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Tanzania have?',947,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Nigeria have?',924,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Venezuela have?',916,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Pakistan have?',882,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Namibia have?',825,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Mozambique have?',802,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Turkey have?',784,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Chile have?',756,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Zambia have?',753,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Myanmar have?',677,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Afghanistan have?',652,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does South Sudan have?',644,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does France have?',644,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Somalia have?',638,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Central African Republic have?',623,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Ukraine have?',604,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Madagascar have?',587,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Botswana have?',582,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Kenya have?',580,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Yemen have?',528,'thousand square kilometers',3,'CIA World Factbook area data'),
('According to standard international area data, approximately how many thousand square kilometers of total area does Thailand have?',513,'thousand square kilometers',3,'CIA World Factbook area data')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int;v_texts int;v_collisions int;v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _geography_stage_1;
  if v_rows<>50 or v_texts<>50 then raise exception 'Geography batch 1 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _geography_stage_1 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Geography batch 1 invalid content'; end if;
  select count(*) into v_ids from _geography_stage_1 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Geography batch 1 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _geography_stage_1 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Geography batch 1 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Geography',difficulty,source,'premium' from _geography_stage_1;

do $$
declare v_inserted int;v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _geography_stage_1 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Geography batch 1 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _geography_stage_1 s on s.id=q.id
  where q.category<>'Geography' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Geography batch 1 post validation failed: %',v_bad; end if;
end $$;
commit;