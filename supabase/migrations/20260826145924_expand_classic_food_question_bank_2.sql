begin;
create temporary table _food_stage_2 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _food_stage_2 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|food|2|' || v.text_en)::uuid,v.text_en,v.answer,v.answer_unit,v.difficulty,v.source
from (values
('According to USDA food-safety guidance, what minimum internal temperature in degrees Fahrenheit should poultry reach?',165,'degrees Fahrenheit',1,'USDA FSIS Safe Minimum Internal Temperature Chart'),
('According to USDA food-safety guidance, what minimum internal temperature in degrees Fahrenheit should ground beef, pork, veal, or lamb reach?',160,'degrees Fahrenheit',1,'USDA FSIS Safe Minimum Internal Temperature Chart'),
('According to USDA food-safety guidance, what minimum internal temperature in degrees Fahrenheit should whole cuts of beef, pork, veal, or lamb reach before resting?',145,'degrees Fahrenheit',2,'USDA FSIS Safe Minimum Internal Temperature Chart'),
('According to USDA food-safety guidance, what minimum internal temperature in degrees Fahrenheit should fish reach?',145,'degrees Fahrenheit',2,'USDA FSIS Safe Minimum Internal Temperature Chart'),
('According to USDA food-safety guidance, to how many degrees Fahrenheit should leftovers be reheated?',165,'degrees Fahrenheit',1,'USDA FSIS Safe Minimum Internal Temperature Chart'),
('According to USDA food-safety guidance, what minimum internal temperature in degrees Fahrenheit should egg dishes reach?',160,'degrees Fahrenheit',2,'USDA FSIS Safe Minimum Internal Temperature Chart'),
('According to USDA guidance, what is the highest recommended refrigerator temperature in degrees Fahrenheit?',40,'degrees Fahrenheit',1,'USDA FSIS Refrigeration and Food Safety'),
('According to USDA guidance, at or above how many degrees Fahrenheit should hot food be held to stay out of the danger zone?',140,'degrees Fahrenheit',2,'USDA FSIS Danger Zone guidance'),
('In USDA food-safety guidance, at how many degrees Fahrenheit does the lower edge of the food danger zone begin?',40,'degrees Fahrenheit',2,'USDA FSIS Danger Zone guidance'),
('In USDA food-safety guidance, at how many degrees Fahrenheit does the upper edge of the food danger zone end?',140,'degrees Fahrenheit',2,'USDA FSIS Danger Zone guidance'),
('Under the USDA two-hour rule, for how many hours may perishable food normally sit at room temperature before refrigeration is required?',2,'hours',1,'USDA FSIS Danger Zone guidance'),
('When the air temperature is above 90 degrees Fahrenheit, after how many hours should perishable food normally be refrigerated under USDA guidance?',1,'hour',2,'USDA FSIS Danger Zone guidance'),
('According to USDA storage guidance, what is the maximum commonly recommended number of refrigerator days for most cooked leftovers?',4,'days',2,'USDA FSIS Leftovers and Food Safety'),
('According to USDA storage guidance, what is the maximum recommended number of refrigerator days for raw poultry before cooking or freezing?',2,'days',2,'USDA FSIS Cold Food Storage Chart'),
('According to USDA storage guidance, what is the maximum recommended number of refrigerator days for raw ground meat before cooking or freezing?',2,'days',2,'USDA FSIS Cold Food Storage Chart'),
('According to USDA storage guidance, what is the maximum recommended number of refrigerator days for raw beef steaks or chops?',5,'days',3,'USDA FSIS Cold Food Storage Chart'),
('According to USDA guidance, after thawing raw poultry in the refrigerator, within how many days should it normally be cooked?',2,'days',3,'USDA FSIS The Big Thaw'),
('On the U.S. FDA Daily Value system for a 2,000-calorie diet, how many grams is the Daily Value for total fat?',78,'grams',2,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many grams is the Daily Value for saturated fat?',20,'grams',2,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many milligrams is the Daily Value for cholesterol?',300,'milligrams',2,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many milligrams is the Daily Value for sodium?',2300,'milligrams',1,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many grams is the Daily Value for total carbohydrate?',275,'grams',2,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many grams is the Daily Value for dietary fiber?',28,'grams',2,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many grams is the Daily Value for added sugars?',50,'grams',2,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many grams is the Daily Value for protein?',50,'grams',2,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many micrograms is the Daily Value for vitamin D?',20,'micrograms',3,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many milligrams is the Daily Value for calcium?',1300,'milligrams',3,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many milligrams is the Daily Value for iron?',18,'milligrams',3,'U.S. FDA Daily Values'),
('On the U.S. FDA Daily Value system, how many milligrams is the Daily Value for potassium?',4700,'milligrams',3,'U.S. FDA Daily Values'),
('How many kilocalories per gram are conventionally assigned to digestible carbohydrate on nutrition labels?',4,'kilocalories per gram',1,'U.S. FDA nutrition labeling conventions'),
('How many kilocalories per gram are conventionally assigned to protein on nutrition labels?',4,'kilocalories per gram',1,'U.S. FDA nutrition labeling conventions'),
('How many kilocalories per gram are conventionally assigned to fat on nutrition labels?',9,'kilocalories per gram',1,'U.S. FDA nutrition labeling conventions'),
('How many kilocalories per gram are conventionally assigned to alcohol in food-energy calculations?',7,'kilocalories per gram',2,'USDA food-energy conversion factors'),
('In U.S. cooking measurements, how many tablespoons are in one cup?',16,'tablespoons',1,'U.S. customary cooking measures'),
('In U.S. cooking measurements, how many teaspoons are in one tablespoon?',3,'teaspoons',1,'U.S. customary cooking measures'),
('In U.S. cooking measurements, how many teaspoons are in one cup?',48,'teaspoons',2,'U.S. customary cooking measures'),
('For U.S. nutrition labeling, one cup is conventionally rounded to how many milliliters?',240,'milliliters',2,'U.S. FDA household measure conventions'),
('For U.S. nutrition labeling, one fluid ounce is conventionally rounded to how many milliliters?',30,'milliliters',2,'U.S. FDA household measure conventions'),
('For food-label serving sizes, one avoirdupois ounce is approximately how many grams when rounded to the nearest whole gram?',28,'grams',1,'U.S. FDA household measure conventions'),
('How many tablespoons are in one standard U.S. stick of butter?',8,'tablespoons',1,'U.S. butter packaging convention'),
('How many standard U.S. sticks of butter equal one U.S. cup?',2,'sticks',1,'U.S. butter packaging convention'),
('About how many grams are in one standard U.S. stick of butter?',113,'grams',2,'U.S. butter packaging convention'),
('How many grams of dry yeast are typically in one standard U.S. active-dry-yeast packet?',7,'grams',2,'commercial baking convention'),
('Under USDA egg-size standards, what is the minimum net weight in ounces of a dozen Large shell eggs?',24,'ounces per dozen',2,'USDA shell egg grading standards'),
('Under USDA egg-size standards, what is the minimum net weight in ounces of a dozen Extra Large shell eggs?',27,'ounces per dozen',3,'USDA shell egg grading standards'),
('Under USDA egg-size standards, what is the minimum net weight in ounces of a dozen Jumbo shell eggs?',30,'ounces per dozen',3,'USDA shell egg grading standards'),
('Under USDA egg-size standards, what is the minimum net weight in ounces of a dozen Medium shell eggs?',21,'ounces per dozen',3,'USDA shell egg grading standards'),
('Under USDA egg-size standards, what is the minimum net weight in ounces of a dozen Small shell eggs?',18,'ounces per dozen',3,'USDA shell egg grading standards'),
('Under USDA egg-size standards, what is the minimum net weight in ounces of a dozen Peewee shell eggs?',15,'ounces per dozen',4,'USDA shell egg grading standards'),
('How many items are in a traditional baker''s dozen?',13,'items',1,'traditional baking terminology')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int;v_texts int;v_collisions int;v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _food_stage_2;
  if v_rows<>50 or v_texts<>50 then raise exception 'Food batch 2 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _food_stage_2 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Food batch 2 invalid content'; end if;
  select count(*) into v_ids from _food_stage_2 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Food batch 2 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _food_stage_2 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Food batch 2 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Food',difficulty,source,'premium' from _food_stage_2;

do $$
declare v_inserted int;v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _food_stage_2 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Food batch 2 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _food_stage_2 s on s.id=q.id
  where q.category<>'Food' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Food batch 2 post validation failed: %',v_bad; end if;
end $$;
commit;