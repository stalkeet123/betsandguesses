begin;
create temporary table _science_stage_3 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _science_stage_3 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|science|3|' || v.text_en)::uuid, v.text_en, v.answer, v.answer_unit, v.difficulty, v.source
from (values
('About how many million years old is Earth?',4540,'million years',2,'USGS Earth age'),
('About what percentage of Earth''s surface is covered by ocean?',71,'percent',1,'NOAA Ocean Service'),
('About what percentage of Earth''s water is contained in the ocean?',97,'percent',2,'NOAA Ocean Service'),
('How many named ocean basins are recognized by the United States?',5,'ocean basins',1,'NOAA Ocean Service'),
('About how many meters deep is the global ocean on average?',3682,'meters',3,'NOAA Ocean Exploration'),
('At about what depth in meters does NOAA define the deep ocean as beginning?',200,'meters',3,'NOAA Ocean Exploration'),
('How many principal layers does Earth''s atmosphere have?',5,'layers',2,'NOAA NESDIS'),
('About what percentage of dry air is nitrogen?',78,'percent',1,'NOAA Global Monitoring Laboratory'),
('About what percentage of dry air is oxygen?',21,'percent',1,'NOAA Global Monitoring Laboratory'),
('What is the approximate maximum percentage of water vapor in Earth''s atmosphere?',4,'percent',3,'NOAA Global Monitoring Laboratory'),
('About how many millibars is typical sea-level atmospheric pressure?',1013,'millibars',3,'NOAA National Data Buoy Center'),
('Within roughly how many kilometers above the surface does most weather occur?',20,'kilometers',3,'NOAA National Data Buoy Center'),
('About how many million square kilometers of surface area does the global ocean cover?',360,'million square kilometers',4,'NOAA Ocean Exploration'),
('NOAA says there are over how many known species of coral in the ocean?',6000,'species',4,'NOAA Ocean Today'),
('The Arctic Ocean covers more than about how many million square miles?',5,'million square miles',3,'NOAA Ocean Today'),
('About how many kilometers is Earth''s diameter?',12750,'kilometers',2,'USGS Inside the Earth'),
('About how many kilometers thick is oceanic crust in the USGS simplified Earth model?',5,'kilometers',3,'USGS Inside the Earth'),
('About how many kilometers thick is continental crust on average in the USGS simplified Earth model?',30,'kilometers',3,'USGS Inside the Earth'),
('About how many kilometers thick is Earth''s mantle?',2900,'kilometers',3,'USGS Inside the Earth'),
('About how many kilometers thick is Earth''s liquid outer core?',2200,'kilometers',4,'USGS Inside the Earth'),
('About how many kilometers thick is Earth''s solid inner core?',1250,'kilometers',4,'USGS Inside the Earth'),
('At least about how many kilometers thick is the lithosphere over much of Earth?',80,'kilometers',4,'USGS Inside the Earth'),
('How many main internal layers does the USGS simplified Earth model describe?',3,'layers',2,'USGS Inside the Earth'),
('Life began in the ocean more than about how many million years ago?',3500,'million years',4,'NOAA Ocean Today'),
('About how many parts per million of neon are in dry Earth''s atmosphere?',18,'parts per million',5,'NOAA Atmosphere'),
('How many pairs of chromosomes do humans typically have?',23,'pairs',1,'NHGRI Chromosomes Fact Sheet'),
('How many chromosomes are in a typical human somatic cell?',46,'chromosomes',1,'NHGRI Chromosomes Fact Sheet'),
('How many pairs of autosomes do humans typically have?',22,'pairs',2,'NHGRI Chromosome Abnormalities Fact Sheet'),
('How many different DNA bases are used in the human genetic code?',4,'bases',1,'NHGRI DNA Fact Sheet'),
('About how many billion base pairs are in one copy of the human genome?',3,'billion base pairs',2,'NHGRI Human Genomic Variation'),
('About how many genes are in the human genome according to NHGRI''s DNA fact sheet?',20000,'genes',3,'NHGRI DNA Fact Sheet'),
('How many pairs of chromosomes does a fruit fly have?',4,'pairs',3,'NHGRI Chromosomes Fact Sheet'),
('How many pairs of chromosomes does a dog have?',39,'pairs',3,'NHGRI Chromosomes Fact Sheet'),
('How many complete chromosome sets does a standard grocery-store strawberry have?',8,'sets',4,'NHGRI Diploid glossary'),
('How many chromosomes in total does the standard octoploid grocery-store strawberry example have?',56,'chromosomes',4,'NHGRI Diploid glossary'),
('About how many million base pairs long can the largest human chromosomes be?',300,'million base pairs',4,'NHGRI Base Pair glossary'),
('About how many million base pairs long are the smallest human chromosomes?',50,'million base pairs',4,'NHGRI Base Pair glossary'),
('How many chambers does the human heart have?',4,'chambers',1,'NHLBI How the Heart Works'),
('How many valves does the human heart have?',4,'valves',1,'NHLBI How the Heart Works'),
('How many pairs of ribs are in the human rib cage?',12,'pairs',2,'NCBI Bookshelf Medical Terminology'),
('How many lobes does the right human lung have?',3,'lobes',2,'NCBI Bookshelf Medical Terminology'),
('How many lobes does the left human lung have?',2,'lobes',2,'NCBI Bookshelf Medical Terminology'),
('About how many days does a normal human red blood cell live?',120,'days',2,'NLM MeSH Erythrocyte Aging'),
('About how many nephrons are in each human kidney?',1000000,'nephrons',3,'NIDDK Kidneys and How They Work'),
('How many vertebrae does the human spine typically have?',33,'vertebrae',2,'NCBI Bookshelf Spinal Cord'),
('How many cervical vertebrae are in the human spine?',7,'vertebrae',2,'NCBI Bookshelf Spinal Cord'),
('How many thoracic vertebrae are in the human spine?',12,'vertebrae',2,'NCBI Bookshelf Spinal Cord'),
('How many lumbar vertebrae are in the human spine?',5,'vertebrae',2,'NCBI Bookshelf Spinal Cord'),
('How many pairs of cranial nerves are there?',12,'pairs',3,'NCBI Bookshelf Spinal Cord'),
('How many pairs of spinal nerves are there?',31,'pairs',3,'NCBI Bookshelf Spinal Cord')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _science_stage_3;
  if v_rows<>50 or v_texts<>50 then raise exception 'Science batch 3 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _science_stage_3 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Science batch 3 invalid content'; end if;
  select count(*) into v_ids from _science_stage_3 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Science batch 3 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _science_stage_3 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Science batch 3 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Science',difficulty,source,'premium' from _science_stage_3;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _science_stage_3 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Science batch 3 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _science_stage_3 s on s.id=q.id
  where q.category<>'Science' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Science batch 3 post validation failed: %',v_bad; end if;
end $$;
commit;