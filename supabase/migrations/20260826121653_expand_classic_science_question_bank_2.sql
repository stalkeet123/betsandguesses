begin;
create temporary table _science_stage_2 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _science_stage_2 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|science|2|' || v.text_en)::uuid, v.text_en, v.answer, v.answer_unit, v.difficulty, v.source
from (values
('What is the atomic number of hydrogen?',1,'atomic number',1,'IUPAC Periodic Table'),
('What is the atomic number of carbon?',6,'atomic number',1,'IUPAC Periodic Table'),
('What is the atomic number of oxygen?',8,'atomic number',1,'IUPAC Periodic Table'),
('What is the atomic number of sodium?',11,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of magnesium?',12,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of aluminum?',13,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of silicon?',14,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of chlorine?',17,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of potassium?',19,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of calcium?',20,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of iron?',26,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of cobalt?',27,'atomic number',3,'IUPAC Periodic Table'),
('What is the atomic number of nickel?',28,'atomic number',3,'IUPAC Periodic Table'),
('What is the atomic number of copper?',29,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of zinc?',30,'atomic number',3,'IUPAC Periodic Table'),
('What is the atomic number of silver?',47,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of iodine?',53,'atomic number',3,'IUPAC Periodic Table'),
('What is the atomic number of gold?',79,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of uranium?',92,'atomic number',2,'IUPAC Periodic Table'),
('What is the atomic number of oganesson?',118,'atomic number',4,'IUPAC Periodic Table'),
('How many SI base units are there?',7,'base units',2,'NIST SI Units'),
('How many defining constants underpin the modern SI?',7,'constants',3,'NIST SI Units'),
('How many SI derived units have special names and symbols?',22,'derived units',4,'NIST SI Units'),
('How many units are in NIST''s core set of seven SI base units plus the derived units with special names?',29,'units',4,'NIST SI Units'),
('How many countries took part in the unanimous 2018 vote to redefine the SI?',60,'countries',4,'NIST SI Redefinition'),
('How many SI base units were redefined in 2019?',4,'base units',3,'NIST SI Redefinition'),
('In what year was the International System of Units established under the name SI?',1960,'year',3,'NIST SI History'),
('In what year was the mole adopted as an SI base unit?',1971,'year',4,'NIST SI History'),
('What fixed frequency in hertz defines the cesium-133 transition used to define the second?',9192631770,'hertz',5,'NIST SI Base Unit Definitions'),
('What fixed luminous efficacy value in lumens per watt helps define the candela?',683,'lumens per watt',5,'NIST SI Base Unit Definitions'),
('To the nearest kelvin, what is the normal boiling point of ethanol?',352,'kelvin',3,'NIST Chemistry WebBook'),
('To the nearest kelvin, what is the normal boiling point of nitrogen?',77,'kelvin',3,'NIST Chemistry WebBook'),
('To the nearest kelvin, what is the melting point of nitrogen?',63,'kelvin',4,'NIST Chemistry WebBook'),
('To the nearest kelvin, what is the normal boiling point of argon?',87,'kelvin',4,'NIST Chemistry WebBook'),
('To the nearest kelvin, what is the melting point of argon?',84,'kelvin',4,'NIST Chemistry WebBook'),
('To the nearest kelvin, what is the melting point of aluminum?',933,'kelvin',4,'NIST Chemistry WebBook'),
('To the nearest kelvin, what is the normal boiling point of oxygen?',90,'kelvin',3,'NIST Chemistry WebBook'),
('To the nearest kelvin, what is the melting point of oxygen?',55,'kelvin',4,'NIST Chemistry WebBook'),
('To the nearest kelvin, what is the normal boiling point of water?',373,'kelvin',2,'NIST Chemistry WebBook'),
('To the nearest kelvin, what is the critical temperature of water?',647,'kelvin',5,'NIST Chemistry WebBook'),
('How many atoms are in one molecule of water, H2O?',3,'atoms',1,'NIST Chemistry WebBook'),
('How many atoms are in one molecule of carbon dioxide, CO2?',3,'atoms',1,'NIST Chemistry WebBook'),
('How many atoms are in one molecule of methane, CH4?',5,'atoms',2,'NIST Chemistry WebBook'),
('How many atoms are in one molecule of ammonia, NH3?',4,'atoms',2,'NIST Chemistry WebBook'),
('How many atoms are in one molecule of sulfuric acid, H2SO4?',7,'atoms',3,'NIST Chemistry WebBook'),
('How many atoms are in one molecule of glucose, C6H12O6?',24,'atoms',3,'NIST Chemistry WebBook'),
('How many atoms are in one molecule of ozone, O3?',3,'atoms',2,'NIST Chemistry WebBook'),
('How many atoms are in one molecule of hydrogen peroxide, H2O2?',4,'atoms',2,'NIST Chemistry WebBook'),
('How many atoms are in one formula unit of sodium bicarbonate, NaHCO3?',6,'atoms',3,'NIST Chemistry WebBook'),
('How many atoms are in one molecule of caffeine, C8H10N4O2?',24,'atoms',4,'NIST Chemistry WebBook')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _science_stage_2;
  if v_rows<>50 or v_texts<>50 then raise exception 'Science batch 2 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _science_stage_2 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Science batch 2 invalid content'; end if;
  select count(*) into v_ids from _science_stage_2 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Science batch 2 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _science_stage_2 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Science batch 2 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Science',difficulty,source,'premium' from _science_stage_2;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _science_stage_2 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Science batch 2 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _science_stage_2 s on s.id=q.id
  where q.category<>'Science' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Science batch 2 post validation failed: %',v_bad; end if;
end $$;
commit;