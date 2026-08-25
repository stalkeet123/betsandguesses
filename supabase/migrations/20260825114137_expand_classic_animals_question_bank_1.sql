begin;
create temporary table _animals_stage_1 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _animals_stage_1 (id, text_en, answer, answer_unit, difficulty, source) values
('67d5d91e-60dc-5212-b0bb-1ea0c50d9a3a'::uuid, 'About how many kilometers per hour can a cheetah reach at top speed?', 110, 'kilometers per hour', 2, 'zoological reference'),
('59f15b22-a5ee-5010-a1c9-1b2790c4b4ce'::uuid, 'About how many months is an African elephant pregnant before giving birth?', 22, 'months', 2, 'zoological reference'),
('3cb9c5d7-7a0b-5487-b177-56b36e5455f4'::uuid, 'About how many centimeters tall can an adult male giraffe stand?', 550, 'centimeters', 3, 'zoological reference'),
('fdf3d555-db19-55bb-b2ca-2e1470a9b2f0'::uuid, 'About how many centimeters long is a giraffe''s tongue?', 45, 'centimeters', 2, 'zoological reference'),
('275bff52-324a-50c8-a969-3c8cec497004'::uuid, 'Up to how many hours a day can a koala sleep?', 20, 'hours', 1, 'zoological reference'),
('10209c34-6533-5605-bd8f-dca1c4aafdf5'::uuid, 'Up to how many hours a day can a lion spend sleeping or resting?', 20, 'hours', 2, 'zoological reference'),
('71a1e86e-fada-5a4f-a161-70d8b606a80d'::uuid, 'About how many kilometers per hour can a hippopotamus run on land?', 30, 'kilometers per hour', 3, 'zoological reference'),
('7e8e5eb3-0483-52b5-a80a-eaeb9bd9e679'::uuid, 'About how many meters can a red kangaroo cover in a single long leap?', 9, 'meters', 2, 'zoological reference'),
('d5a501de-721c-5b33-ae66-d6bbd98c7a1b'::uuid, 'About how many kilometers per hour can a red kangaroo reach at top speed?', 70, 'kilometers per hour', 3, 'zoological reference'),
('e5889b43-f09d-5d7c-920b-7cfcd088971f'::uuid, 'About how many liters of water can a camel drink in roughly ten minutes?', 100, 'liters', 2, 'zoological reference'),
('95b42d6e-c346-532e-bc3a-a74cbde09e75'::uuid, 'About how many kilograms of bamboo can a giant panda eat in a day?', 12, 'kilograms', 3, 'zoological reference'),
('37a1f222-3605-5300-af70-fe05e15cf6d1'::uuid, 'About how many centimeters long can a giant anteater''s tongue be?', 60, 'centimeters', 2, 'zoological reference'),
('fe0c6051-0547-5124-8497-6b2d26f323d7'::uuid, 'About how many spines does a typical hedgehog have?', 5000, 'items', 3, 'zoological reference'),
('dfd3ea2f-bb7f-5d01-a7c7-f5b0463eed50'::uuid, 'About how many years can a naked mole-rat live?', 30, 'years', 3, 'zoological reference'),
('3b1b20f8-1631-5e38-a22a-1a58097b0bf3'::uuid, 'About how many kilometers per hour can a pronghorn reach?', 90, 'kilometers per hour', 3, 'zoological reference'),
('a25f8e32-6205-50fd-8fcf-dc6634a7cad0'::uuid, 'About how many kilograms can a large adult capybara weigh?', 65, 'kilograms', 2, 'zoological reference'),
('a2e1ed42-4000-509f-9532-6b801b25856b'::uuid, 'About how many cube-shaped droppings can a wombat produce in a day?', 100, 'items', 4, 'zoological reference'),
('2af41d2c-7207-58ff-ae43-26d79db892b6'::uuid, 'About how many centimeters long can a walrus tusk grow?', 100, 'centimeters', 2, 'zoological reference'),
('da501ebd-d226-5ef4-b9ec-913537a341a6'::uuid, 'About how many kilograms can an adult male white rhinoceros weigh?', 2300, 'kilograms', 3, 'zoological reference'),
('db572ea7-5900-54b9-84cf-2e847bbce90f'::uuid, 'About how many centimeters tall can a large moose stand at the shoulder?', 210, 'centimeters', 3, 'zoological reference'),
('88f9a50f-e0c3-5ef9-9677-c90d21d089a0'::uuid, 'About how many kilometers per hour can a polar bear run for a short distance?', 40, 'kilometers per hour', 3, 'zoological reference'),
('d84399d5-bee2-5334-b868-417b58fddff4'::uuid, 'About how many kilometers per hour can a grizzly bear run at top speed?', 56, 'kilometers per hour', 3, 'zoological reference'),
('45f120ef-a648-5a71-bd51-1472e8f2e7e2'::uuid, 'During flight, about how many times per minute can a small bat''s heart beat?', 1000, 'beats per minute', 4, 'zoological reference'),
('063c67b0-2bf7-5e6c-a5b2-9d1903d2d89a'::uuid, 'About how many centimeters can the wingspan of a large flying fox bat reach?', 150, 'centimeters', 3, 'zoological reference'),
('7ffd199e-23ac-5905-af82-8be01e22309f'::uuid, 'About how many kilograms does an adult male African lion typically weigh?', 190, 'kilograms', 2, 'zoological reference'),
('3cdbd126-d9d5-5f0e-a02f-615ef4f004de'::uuid, 'About how many kilograms can an adult male silverback gorilla weigh?', 180, 'kilograms', 2, 'zoological reference'),
('b122b1b8-0477-5ed1-8304-aaa298162b88'::uuid, 'About how many centimeters can an adult orangutan''s arm span reach?', 220, 'centimeters', 3, 'zoological reference'),
('ce70d9a1-acd1-5b6a-8aa3-d6f64f520e98'::uuid, 'From about how many kilometers away can a howler monkey''s call be heard?', 5, 'kilometers', 3, 'zoological reference'),
('46aec40c-bd39-54b6-8c14-250c50fc960d'::uuid, 'About how many meters can a snow leopard leap horizontally?', 15, 'meters', 3, 'zoological reference'),
('b1d1ed9d-b499-5a7f-8c30-c58594d8bdbe'::uuid, 'About how many kilograms can an adult American bison weigh?', 900, 'kilograms', 2, 'zoological reference'),
('929e2a32-1c71-5399-b0d6-e5c51ffb8d95'::uuid, 'About how many kilometers per hour can an African wild dog reach while running?', 60, 'kilometers per hour', 3, 'zoological reference'),
('bfd595f4-9efe-5635-9f06-705eb0b0bd21'::uuid, 'About how many quills can a North American porcupine have?', 30000, 'items', 4, 'zoological reference'),
('c6bcc130-51ac-58a0-a114-b96d93606d13'::uuid, 'About how many teeth can a giant armadillo have?', 100, 'items', 4, 'zoological reference'),
('148df8ab-b8e0-5964-a216-fd21de88c067'::uuid, 'How many genetically identical young does a nine-banded armadillo usually give birth to at once?', 4, 'items', 2, 'zoological reference'),
('fcf74462-5ef6-5633-94bf-e96f2137ca67'::uuid, 'How many eggs does a female platypus usually lay in a clutch?', 2, 'items', 2, 'zoological reference'),
('774af82f-ab30-51c8-9adb-09003fee5ca3'::uuid, 'About how many days does an echidna egg incubate before hatching?', 10, 'days', 3, 'zoological reference'),
('0292efdd-8f75-5290-b6e6-cd538d1be49b'::uuid, 'About how many kilograms of vegetation can an adult African elephant eat in a day?', 150, 'kilograms', 3, 'zoological reference'),
('5c5f350f-9611-5daf-821e-45774af00c0c'::uuid, 'About how many liters of water can an adult African elephant drink in a day?', 200, 'liters', 3, 'zoological reference'),
('444f36d0-15dc-5f7a-a50c-9ee3b720a480'::uuid, 'About how many kilograms can a giraffe''s heart weigh?', 11, 'kilograms', 3, 'zoological reference'),
('7be0e4f1-5f71-5d44-8924-2b6a60924f68'::uuid, 'About how many kilometers per hour can a tiger reach in a short sprint?', 65, 'kilometers per hour', 2, 'zoological reference'),
('2b16dea6-ae82-5f4a-a4b0-a5eb71abac9c'::uuid, 'About how many meters can a tiger leap forward?', 10, 'meters', 2, 'zoological reference'),
('1b7a6ba9-0fc4-546f-b3df-9bac3802f3f5'::uuid, 'About how many kilometers per hour can a grey wolf reach at top speed?', 60, 'kilometers per hour', 3, 'zoological reference'),
('e074bc95-6b27-5a9b-a76e-df226776c60a'::uuid, 'About how many kilometers can a grey wolf travel in a single day?', 50, 'kilometers', 3, 'zoological reference'),
('394affbc-9e60-5b7d-8ca9-c3f8b3d900e7'::uuid, 'About how many kilometers can some caribou herds travel in a year?', 4400, 'kilometers', 4, 'zoological reference'),
('4c629f74-c738-59fd-926d-03dac3b6c9a8'::uuid, 'About how many centimeters long can a hippopotamus canine tooth grow?', 50, 'centimeters', 3, 'zoological reference'),
('8aa36137-8ce8-5398-9245-470da7fe39a9'::uuid, 'About how many kilometers per hour can an ostrich run?', 70, 'kilometers per hour', 2, 'ornithological reference'),
('9a140cfe-0fd6-504a-b4c5-e0a7b841e543'::uuid, 'About how many centimeters tall can an adult male ostrich stand?', 270, 'centimeters', 2, 'ornithological reference'),
('9fc344f9-5692-5981-b3f9-bb140745ec6c'::uuid, 'About how many grams can a single ostrich egg weigh?', 1500, 'grams', 2, 'ornithological reference'),
('8f88cf81-7fdb-5c25-a23b-23d65e21e932'::uuid, 'About how many days does an ostrich egg take to hatch?', 42, 'days', 2, 'ornithological reference'),
('58fcace1-d871-5bd8-80a0-f2d306a9eb28'::uuid, 'About how many days does a male emperor penguin incubate its egg?', 65, 'days', 3, 'ornithological reference');

do $$
declare v_rows int; v_texts int; v_collisions int; v_id_collisions int;
begin
  select count(*), count(distinct lower(btrim(text_en))) into v_rows, v_texts from _animals_stage_1;
  if v_rows <> 50 or v_texts <> 50 then
    raise exception 'Animals batch 1 staging invalid: rows %, unique texts %', v_rows, v_texts;
  end if;
  if exists (select 1 from _animals_stage_1
             where btrim(text_en)='' or answer<=0 or btrim(answer_unit)=''
                or difficulty not between 1 and 5 or btrim(source)='') then
    raise exception 'Animals batch 1 contains invalid content';
  end if;
  select count(*) into v_id_collisions from _animals_stage_1 s join public.questions q on q.id=s.id;
  if v_id_collisions<>0 then raise exception 'Animals batch 1 UUID collisions: %', v_id_collisions; end if;
  select count(*) into v_collisions
  from _animals_stage_1 s join public.questions q
    on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Animals batch 1 wording collisions: %', v_collisions; end if;
end $$;

insert into public.questions
  (id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Animals',difficulty,source,'premium'
from _animals_stage_1;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _animals_stage_1 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Animals batch 1 inserted % rows', v_inserted; end if;
  select count(*) into v_bad
  from public.questions q join _animals_stage_1 s on s.id=q.id
  where q.category<>'Animals' or q.access_tier<>'premium'
     or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en
     or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit
     or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Animals batch 1 post validation failed: %', v_bad; end if;
end $$;
commit;