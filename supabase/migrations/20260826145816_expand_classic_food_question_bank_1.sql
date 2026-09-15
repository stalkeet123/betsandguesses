begin;
create temporary table _food_stage_1 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _food_stage_1 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|food|1|' || v.text_en)::uuid,v.text_en,v.answer,v.answer_unit,v.difficulty,v.source
from (values
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw apple with skin?',52,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw banana?',89,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw orange?',47,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw strawberries?',32,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw blueberries?',57,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw grapes?',69,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw watermelon?',30,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw pineapple?',50,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw mango?',60,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw kiwifruit?',61,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw pear?',57,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw peach?',39,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw plum?',46,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw sweet cherries?',63,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw avocado?',160,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw carrots?',41,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw broccoli?',34,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw cauliflower?',25,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw spinach?',23,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw romaine lettuce?',17,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw tomatoes?',18,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw cucumber with peel?',15,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw potato?',77,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw sweet potato?',86,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw onion?',40,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw red bell pepper?',31,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw white mushrooms?',22,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw green peas?',81,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of raw sweet yellow corn?',86,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of cooked lentils?',116,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of cooked chickpeas?',164,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of cooked kidney beans?',127,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of cooked white rice?',130,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of cooked brown rice?',123,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of cooked quinoa?',120,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of dry rolled oats?',379,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of whole cow''s milk?',61,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of skim cow''s milk?',34,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of plain whole-milk yogurt?',61,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of cheddar cheese?',403,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of whole-milk mozzarella?',300,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of whole cooked egg?',143,'kilocalories',1,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of roasted skinless chicken breast?',165,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of cooked 85-percent-lean ground beef?',250,'kilocalories',3,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of cooked Atlantic salmon?',206,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of canned light tuna in water, drained?',116,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of almonds?',579,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of walnuts?',654,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of peanuts?',567,'kilocalories',2,'USDA FoodData Central'),
('According to USDA food composition data, about how many kilocalories are in 100 grams of dark chocolate with roughly 70 to 85 percent cacao?',598,'kilocalories',3,'USDA FoodData Central')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int;v_texts int;v_collisions int;v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _food_stage_1;
  if v_rows<>50 or v_texts<>50 then raise exception 'Food batch 1 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _food_stage_1 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Food batch 1 invalid content'; end if;
  select count(*) into v_ids from _food_stage_1 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Food batch 1 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _food_stage_1 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Food batch 1 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Food',difficulty,source,'premium' from _food_stage_1;

do $$
declare v_inserted int;v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _food_stage_1 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Food batch 1 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _food_stage_1 s on s.id=q.id
  where q.category<>'Food' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Food batch 1 post validation failed: %',v_bad; end if;
end $$;
commit;