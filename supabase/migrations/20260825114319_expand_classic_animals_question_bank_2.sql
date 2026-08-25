begin;
create temporary table _animals_stage_2 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _animals_stage_2 (id, text_en, answer, answer_unit, difficulty, source) values
('37889f31-c309-58c4-ac7b-f6de35f4a8ce'::uuid, 'About how many meters deep can an emperor penguin dive?', 500, 'meters', 3, 'ornithological reference'),
('4a656144-cf7c-59a1-9166-ece756054a23'::uuid, 'About how many minutes can an emperor penguin stay underwater on a long dive?', 20, 'minutes', 3, 'ornithological reference'),
('df6979c6-4b3c-5673-9a7a-f9e83b2e6fcd'::uuid, 'About how many kilometers per hour can a gentoo penguin swim?', 36, 'kilometers per hour', 3, 'ornithological reference'),
('4934fb87-3603-5966-be62-d7d0a982503d'::uuid, 'About how many kilometers can an Arctic tern travel during its yearly migration?', 70000, 'kilometers', 4, 'ornithological reference'),
('038206c5-7319-5e40-8e92-52cab5050993'::uuid, 'About how many centimeters can a wandering albatross''s wingspan reach?', 350, 'centimeters', 3, 'ornithological reference'),
('501c6dfb-bcd1-5e38-a0f4-1c077ff72235'::uuid, 'About how many centimeters can a bald eagle''s wingspan reach?', 230, 'centimeters', 2, 'ornithological reference'),
('c0c6151f-ed09-5d2a-a77e-57336ad41b5c'::uuid, 'About how many centimeters can an Andean condor''s wingspan reach?', 320, 'centimeters', 3, 'ornithological reference'),
('f13eae74-4aa7-5c65-9509-16f7e7ac617d'::uuid, 'How many degrees can an owl turn its head from its forward position?', 270, 'degrees', 2, 'ornithological reference'),
('11e0c9fe-0f29-556d-b6af-5b32c88ebd8b'::uuid, 'About how many kilometers can a ruby-throated hummingbird fly nonstop across the Gulf of Mexico?', 800, 'kilometers', 4, 'ornithological reference'),
('c2f2f82c-ca92-54f7-ac87-e860955136de'::uuid, 'During intense flight, about how many times per minute can a hummingbird''s heart beat?', 1200, 'beats per minute', 4, 'ornithological reference'),
('06d7f8d9-e3fa-5d43-9043-b409491ca1d1'::uuid, 'Up to how many months can a common swift remain almost continuously airborne?', 10, 'months', 4, 'ornithological reference'),
('b0d8733b-7739-52d0-805c-bf1b86404d7d'::uuid, 'At roughly how many meters above sea level have bar-headed geese been observed flying over the Himalayas?', 7000, 'meters', 4, 'ornithological reference'),
('999abc9d-737d-5211-8e9c-a60f6df03ec2'::uuid, 'About how many years can a flamingo live?', 40, 'years', 2, 'ornithological reference'),
('450e1a68-fed0-5e50-8cac-7918319d05e2'::uuid, 'About how many centimeters long can a large toucan''s bill be?', 20, 'centimeters', 2, 'ornithological reference'),
('6510acdb-9a4e-515c-88e3-235468a69f60'::uuid, 'About how many centimeters long can a male peacock''s train grow?', 150, 'centimeters', 2, 'ornithological reference'),
('b92e315e-3620-5436-b6e7-6984c3b42cf9'::uuid, 'About how many centimeters tall can a southern cassowary stand?', 170, 'centimeters', 3, 'ornithological reference'),
('5ccba6c3-1475-5685-a663-090c5c5bf0cc'::uuid, 'About how many centimeters tall can a shoebill stand?', 120, 'centimeters', 3, 'ornithological reference'),
('727670ea-f80f-5925-b092-6b35faa2382f'::uuid, 'About how many centimeters tall can a secretary bird stand?', 130, 'centimeters', 3, 'ornithological reference'),
('a2547b1d-a31a-57fe-832f-d0857b838bf0'::uuid, 'About how many years can a large macaw live?', 50, 'years', 2, 'ornithological reference'),
('c523489d-b690-5439-8520-3001b4cbfc63'::uuid, 'About how many years can a cockatoo live?', 60, 'years', 2, 'ornithological reference'),
('20db2704-380d-52e0-b08a-ef83ad6b8745'::uuid, 'About how many centimeters can an American white pelican''s wingspan reach?', 300, 'centimeters', 3, 'ornithological reference'),
('9041f810-764c-539e-8e83-016be8259f7a'::uuid, 'About how many meters deep can an Atlantic puffin dive?', 60, 'meters', 3, 'ornithological reference'),
('400d240d-2a6b-5fd3-8da3-2a598340cec9'::uuid, 'About how many days does a king penguin incubate a single egg?', 55, 'days', 3, 'ornithological reference'),
('f762cf30-216c-5b9f-bec8-807f2d8a8bb1'::uuid, 'About how many kilometers per hour can a wild turkey run?', 40, 'kilometers per hour', 2, 'ornithological reference'),
('5965979b-f012-5bbf-8978-67371a89e7bf'::uuid, 'About how many centimeters can a mute swan''s wingspan reach?', 240, 'centimeters', 2, 'ornithological reference'),
('12eafb52-0ba8-5ef9-9d14-afcbf8c2e91d'::uuid, 'About how many meters long can a blue whale grow?', 30, 'meters', 2, 'marine biology reference'),
('e2d8998e-805c-57ba-8685-638f37f2cbfe'::uuid, 'About how many kilograms can a large blue whale weigh?', 150000, 'kilograms', 3, 'marine biology reference'),
('51d6119f-d46e-51bd-ba0b-95d87f19a23d'::uuid, 'How low can a blue whale''s heart rate drop during a deep dive, in beats per minute?', 2, 'beats per minute', 4, 'published study'),
('7db998d3-3781-5627-9081-83e1c6bfbfdc'::uuid, 'About how many kilograms can a blue whale''s tongue weigh?', 2700, 'kilograms', 4, 'marine biology reference'),
('e3260fa9-b638-5243-9589-3940b9db78fa'::uuid, 'About how many kilometers can a humpback whale migrate between feeding and breeding grounds?', 8000, 'kilometers', 3, 'marine biology reference'),
('8341819e-16b1-51d2-84ef-0280f3d579f6'::uuid, 'About how many meters deep can a sperm whale dive?', 2000, 'meters', 3, 'marine biology reference'),
('ae14bd76-7f2d-5c1e-971a-b388d9ee8356'::uuid, 'About how many minutes can a sperm whale stay underwater on a long dive?', 90, 'minutes', 3, 'marine biology reference'),
('514e9c72-bb07-5f59-ba17-95e0623eb8a7'::uuid, 'About how many kilometers per hour can an orca swim?', 56, 'kilometers per hour', 3, 'marine biology reference'),
('271e78ee-1104-5fe7-8208-ad40e7bd77a2'::uuid, 'About how many kilometers per hour can a bottlenose dolphin swim?', 35, 'kilometers per hour', 2, 'marine biology reference'),
('c78a0795-053c-59d8-941a-bb4388a2b8e9'::uuid, 'About how many meters long can a whale shark grow?', 18, 'meters', 3, 'marine biology reference'),
('fb223488-bb44-5510-9c66-d9d4d2fd4ab9'::uuid, 'About how many centimeters can a giant manta ray''s wingspan reach?', 700, 'centimeters', 3, 'marine biology reference'),
('bba64e7c-3fce-513b-b436-ca02d599d684'::uuid, 'About how many centimeters long can a narwhal tusk grow?', 300, 'centimeters', 2, 'marine biology reference'),
('9a944014-cf98-584e-9ce4-15789d320c72'::uuid, 'About how many meters deep can a narwhal dive?', 1500, 'meters', 4, 'marine biology reference'),
('de72254f-5fdd-56ec-a1bb-31cdeb341117'::uuid, 'About how many meters deep can a southern elephant seal dive?', 1500, 'meters', 4, 'marine biology reference'),
('2e749c0b-01cf-5e5a-805f-159b6cf11fc2'::uuid, 'About how many minutes can a southern elephant seal remain underwater on an extreme dive?', 120, 'minutes', 4, 'marine biology reference'),
('d2b6f5d4-81a7-5a18-bded-0467570eaaca'::uuid, 'About how many kilograms does an adult West Indian manatee typically weigh?', 500, 'kilograms', 2, 'marine biology reference'),
('02fce94d-39af-5e19-ad21-b47fe5ebf9a1'::uuid, 'About how many years can a dugong live?', 70, 'years', 3, 'marine biology reference'),
('424d94ff-7c5f-54ce-9a51-2ca2fb0c8448'::uuid, 'About how many meters long can a giant squid grow including its tentacles?', 13, 'meters', 3, 'marine biology reference'),
('dc901de5-7e3f-5a9e-aa54-c7defad627ef'::uuid, 'About how many kilograms can a colossal squid weigh?', 500, 'kilograms', 4, 'marine biology reference'),
('ce9127c3-0c7d-585b-b02f-e8b663ed195a'::uuid, 'About how many centimeters across can a giant Pacific octopus span from arm tip to arm tip?', 900, 'centimeters', 4, 'marine biology reference'),
('5b2308e6-b062-5438-aa5a-7460a5039580'::uuid, 'About how many suckers can a giant Pacific octopus have across all eight arms?', 2000, 'items', 4, 'marine biology reference'),
('facbf112-5188-517d-a369-4cd55bfec623'::uuid, 'How many hearts does an octopus have?', 3, 'items', 1, 'marine biology reference'),
('cbfff88d-f11e-5089-a755-bc5e27db176a'::uuid, 'How many hearts does a cuttlefish have?', 3, 'items', 2, 'marine biology reference'),
('6482f381-db5d-5b7f-a433-13d348a14ecf'::uuid, 'About how many tentacles does a chambered nautilus have?', 90, 'items', 3, 'marine biology reference'),
('8d42bfde-d2f5-5fc5-bcd9-879fe0aa2d5c'::uuid, 'About how many eggs can a female ocean sunfish release at one time?', 300000000, 'items', 4, 'marine biology reference');

do $$
declare v_rows int; v_texts int; v_collisions int; v_id_collisions int;
begin
  select count(*), count(distinct lower(btrim(text_en))) into v_rows, v_texts from _animals_stage_2;
  if v_rows <> 50 or v_texts <> 50 then
    raise exception 'Animals batch 2 staging invalid: rows %, unique texts %', v_rows, v_texts;
  end if;
  if exists (select 1 from _animals_stage_2
             where btrim(text_en)='' or answer<=0 or btrim(answer_unit)=''
                or difficulty not between 1 and 5 or btrim(source)='') then
    raise exception 'Animals batch 2 contains invalid content';
  end if;
  select count(*) into v_id_collisions from _animals_stage_2 s join public.questions q on q.id=s.id;
  if v_id_collisions<>0 then raise exception 'Animals batch 2 UUID collisions: %', v_id_collisions; end if;
  select count(*) into v_collisions
  from _animals_stage_2 s join public.questions q
    on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Animals batch 2 wording collisions: %', v_collisions; end if;
end $$;

insert into public.questions
  (id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Animals',difficulty,source,'premium'
from _animals_stage_2;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _animals_stage_2 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Animals batch 2 inserted % rows', v_inserted; end if;
  select count(*) into v_bad
  from public.questions q join _animals_stage_2 s on s.id=q.id
  where q.category<>'Animals' or q.access_tier<>'premium'
     or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en
     or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit
     or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Animals batch 2 post validation failed: %', v_bad; end if;
end $$;
commit;