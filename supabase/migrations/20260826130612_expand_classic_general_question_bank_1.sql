begin;
create temporary table _general_stage_1 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _general_stage_1 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|general|1|' || v.text_en)::uuid,v.text_en,v.answer,v.answer_unit,v.difficulty,v.source
from (values
('How many days are in a standard week?',7,'days',1,'Gregorian calendar conventions'),
('How many months are in a calendar year?',12,'months',1,'Gregorian calendar conventions'),
('How many days are in a common Gregorian year?',365,'days',1,'Gregorian calendar conventions'),
('How many days are in a Gregorian leap year?',366,'days',1,'Gregorian calendar conventions'),
('How many hours are in one day?',24,'hours',1,'SI time conventions'),
('How many minutes are in one hour?',60,'minutes',1,'SI time conventions'),
('How many seconds are in one minute?',60,'seconds',1,'SI time conventions'),
('How many minutes are in one full day?',1440,'minutes',2,'SI time conventions'),
('How many seconds are in one hour?',3600,'seconds',2,'SI time conventions'),
('How many hours are in one seven-day week?',168,'hours',2,'SI time conventions'),
('How many days are in a fortnight?',14,'days',1,'English time conventions'),
('How many years are in a decade?',10,'years',1,'calendar terminology'),
('How many years are in a century?',100,'years',1,'calendar terminology'),
('How many years are in a millennium?',1000,'years',1,'calendar terminology'),
('How many items are in a dozen?',12,'items',1,'traditional counting units'),
('How many items are in a gross?',144,'items',2,'traditional counting units'),
('How many sheets are in a standard ream of paper?',500,'sheets',2,'paper industry conventions'),
('How many centimeters are in one meter?',100,'centimeters',1,'SI metric system'),
('How many millimeters are in one meter?',1000,'millimeters',1,'SI metric system'),
('How many meters are in one kilometer?',1000,'meters',1,'SI metric system'),
('How many grams are in one kilogram?',1000,'grams',1,'SI metric system'),
('How many milligrams are in one gram?',1000,'milligrams',1,'SI metric system'),
('How many milliliters are in one liter?',1000,'milliliters',1,'SI metric system'),
('How many inches are in one foot?',12,'inches',1,'US customary and imperial units'),
('How many feet are in one yard?',3,'feet',1,'US customary and imperial units'),
('How many feet are in one statute mile?',5280,'feet',2,'US customary and imperial units'),
('How many yards are in one statute mile?',1760,'yards',2,'US customary and imperial units'),
('How many avoirdupois ounces are in one pound?',16,'ounces',2,'avoirdupois weight system'),
('How many pounds are in one imperial stone?',14,'pounds',2,'imperial weight system'),
('How many US fluid ounces are in one US cup?',8,'fluid ounces',2,'US customary volume units'),
('How many US cups are in one US liquid gallon?',16,'cups',2,'US customary volume units'),
('How many US pints are in one US liquid gallon?',8,'pints',2,'US customary volume units'),
('How many US quarts are in one US liquid gallon?',4,'quarts',2,'US customary volume units'),
('How many US fluid ounces are in one US liquid gallon?',128,'fluid ounces',3,'US customary volume units'),
('At standard atmospheric pressure, at how many degrees Celsius does water boil?',100,'degrees Celsius',1,'Celsius temperature scale'),
('At standard atmospheric pressure, at how many degrees Fahrenheit does water freeze?',32,'degrees Fahrenheit',1,'Fahrenheit temperature scale'),
('At standard atmospheric pressure, at how many degrees Fahrenheit does water boil?',212,'degrees Fahrenheit',2,'Fahrenheit temperature scale'),
('How many cents are in one US dollar?',100,'cents',1,'United States currency'),
('How many pence are in one pound sterling?',100,'pence',1,'United Kingdom currency'),
('How many cents are in one euro?',100,'cents',1,'European Union currency'),
('How many letters are in the modern English alphabet?',26,'letters',1,'English alphabet'),
('How many letters are in the modern Greek alphabet?',24,'letters',2,'Greek alphabet'),
('How many letters are in the Hebrew alphabet?',22,'letters',2,'Hebrew alphabet'),
('How many letters are in the Arabic alphabet?',28,'letters',2,'Arabic alphabet'),
('How many letters are in the modern Russian alphabet?',33,'letters',2,'Russian alphabet'),
('How many letters are in the modern Spanish alphabet?',27,'letters',2,'Real Academia Española'),
('How many basic symbols are used in the standard Roman numeral system?',7,'symbols',2,'Roman numeral conventions'),
('How many dots are in a standard six-dot Braille cell?',6,'dots',2,'Braille standard'),
('How many official languages does the United Nations have?',6,'languages',2,'United Nations'),
('How many months in the Gregorian calendar have 31 days?',7,'months',2,'Gregorian calendar conventions')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _general_stage_1;
  if v_rows<>50 or v_texts<>50 then raise exception 'General batch 1 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _general_stage_1 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'General batch 1 invalid content'; end if;
  select count(*) into v_ids from _general_stage_1 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'General batch 1 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _general_stage_1 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'General batch 1 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'General',difficulty,source,'premium' from _general_stage_1;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _general_stage_1 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'General batch 1 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _general_stage_1 s on s.id=q.id
  where q.category<>'General' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'General batch 1 post validation failed: %',v_bad; end if;
end $$;
commit;