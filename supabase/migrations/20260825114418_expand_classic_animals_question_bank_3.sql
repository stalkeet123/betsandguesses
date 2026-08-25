begin;
create temporary table _animals_stage_3 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _animals_stage_3 (id, text_en, answer, answer_unit, difficulty, source) values
('25380241-e28f-5437-84ce-1a227b40c850'::uuid, 'About how many meters can a flying fish glide above the water in one flight?', 200, 'meters', 3, 'marine biology reference'),
('cb43e75e-51e2-560d-8321-71a37066343d'::uuid, 'Up to about how many volts can the strongest known electric eel discharge?', 860, 'volts', 4, 'marine biology reference'),
('2cd3c37d-cd00-57cd-9737-476fff3f89e5'::uuid, 'Up to about how many young can a male seahorse release after one pregnancy?', 2000, 'items', 4, 'marine biology reference'),
('5cbf26bd-28f3-59f2-a7f5-f4ac90cf52ba'::uuid, 'About how many kilograms can a giant clam weigh?', 200, 'kilograms', 3, 'marine biology reference'),
('f2b33ea8-3f45-5c48-b4c2-508cf09abe3f'::uuid, 'About how many meters long can the tentacles of a lion''s mane jellyfish grow?', 36, 'meters', 4, 'marine biology reference'),
('5074a54b-cd7e-50a8-9e65-78f03803353a'::uuid, 'About how many centimeters long can a large Komodo dragon grow?', 300, 'centimeters', 2, 'herpetology reference'),
('8ca41bd3-54c4-521c-b925-6107be4e1153'::uuid, 'About how many kilometers per hour can a Komodo dragon run?', 20, 'kilometers per hour', 3, 'herpetology reference'),
('71aad267-2526-5c2a-bd9c-798d29922e9a'::uuid, 'About how many centimeters long can a large saltwater crocodile grow?', 600, 'centimeters', 2, 'herpetology reference'),
('5c4a9f13-d70b-53d4-8bcd-381130365902'::uuid, 'About how many newtons of bite force has a large saltwater crocodile been measured producing?', 16460, 'newtons', 4, 'herpetology reference'),
('a8306227-82d8-583e-ad5a-a469e850fd53'::uuid, 'About how many years can an American alligator live?', 50, 'years', 2, 'herpetology reference'),
('0c9e4f64-a58c-50a7-96e8-72ee2550df5c'::uuid, 'About how many eggs are in a typical American alligator nest?', 35, 'items', 2, 'herpetology reference'),
('1e127eab-897e-5c5b-afb7-51bf0e51f8c4'::uuid, 'About how many kilometers per hour can an American alligator run on land for a short burst?', 18, 'kilometers per hour', 3, 'herpetology reference'),
('2d8ee65e-4bf5-532e-9808-920291255b62'::uuid, 'About how many centimeters long can a king cobra grow?', 550, 'centimeters', 3, 'herpetology reference'),
('888a9960-6c23-5161-952a-00ba626a3deb'::uuid, 'About how many eggs can a female king cobra lay in a clutch?', 30, 'items', 3, 'herpetology reference'),
('e87d5f92-5d95-5e3b-9c94-61ad860903f9'::uuid, 'About how many centimeters long can a large green anaconda grow?', 600, 'centimeters', 3, 'herpetology reference'),
('12d8ccaa-ba6e-5ebb-a6f4-8aeacdea26b3'::uuid, 'Up to about how many eggs can a large Burmese python lay in one clutch?', 100, 'items', 3, 'herpetology reference'),
('dc71f9b6-7b45-5d94-a524-aabf70dd1459'::uuid, 'About how many meters deep can a leatherback sea turtle dive?', 1200, 'meters', 4, 'herpetology reference'),
('fbb24010-3a88-5d27-9ee5-7611f8770b2a'::uuid, 'About how many eggs does a sea turtle commonly lay in one nest?', 100, 'items', 2, 'herpetology reference'),
('5824c7bc-84e8-522a-8178-efb1950b0045'::uuid, 'About how many kilograms can an adult Galapagos tortoise weigh?', 250, 'kilograms', 3, 'herpetology reference'),
('e852c611-1649-5fdf-9eaa-b2e18186a925'::uuid, 'About how many grams can a goliath frog weigh?', 3300, 'grams', 3, 'herpetology reference'),
('1fbc11ab-3d50-5206-8d27-3d99553ea0cb'::uuid, 'About how many centimeters can a goliath frog jump in a single leap?', 300, 'centimeters', 3, 'herpetology reference'),
('c8c0c585-d898-518d-a025-d37c855debf9'::uuid, 'About how many years can an olm, the cave-dwelling salamander, live?', 100, 'years', 4, 'herpetology reference'),
('3681b19b-e49f-507c-8e7e-20ec04b1eb32'::uuid, 'About how many centimeters long can a hellbender salamander grow?', 74, 'centimeters', 4, 'herpetology reference'),
('464b73bb-385e-5bcf-8d45-d586eccddbcb'::uuid, 'About how many centimeters can a horned lizard squirt blood from its eyes as a defense?', 150, 'centimeters', 4, 'herpetology reference'),
('a71ea1be-1af9-50f7-8a1b-2751867dc808'::uuid, 'About how many meters deep can a marine iguana dive while feeding?', 30, 'meters', 3, 'herpetology reference'),
('9f9cf4ee-f9b8-5b68-8948-9eeb967b71b6'::uuid, 'About how many times its own body weight can the strongest dung beetle pull?', 1141, 'times body weight', 4, 'entomology reference'),
('c250babc-4aac-5e11-a77a-cca275cbe7e5'::uuid, 'About how many centimeters high can a flea jump?', 18, 'centimeters', 3, 'entomology reference'),
('976b00ed-0d1a-54b6-b08b-ec352b5b5524'::uuid, 'About how many kilometers per hour can a large dragonfly reach in flight?', 55, 'kilometers per hour', 3, 'entomology reference'),
('28981891-7308-5db1-80de-8617f2893e52'::uuid, 'About how many individual visual units are packed into a dragonfly''s compound eyes?', 30000, 'items', 4, 'entomology reference'),
('98377ba0-2788-57ca-b2a2-cb96a7430734'::uuid, 'About how many times per second can a mosquito beat its wings?', 500, 'beats per second', 3, 'entomology reference'),
('7352080e-7ae2-5518-b281-f4563733d2ad'::uuid, 'About how many centimeters can an Atlas moth''s wingspan reach?', 27, 'centimeters', 3, 'entomology reference'),
('f60e67b0-c094-5e4d-a448-4cac32655c12'::uuid, 'About how many centimeters long can a male Hercules beetle grow including its horn?', 17, 'centimeters', 3, 'entomology reference'),
('ae2854cb-df5d-5184-9fd7-e8d467a97ba2'::uuid, 'About how many ants can live in a large leafcutter ant colony?', 8000000, 'items', 4, 'entomology reference'),
('d89d2ee4-2be9-5a67-a334-cdb55a9afb5d'::uuid, 'Up to about how many eggs can a termite queen lay in a single day?', 30000, 'items', 4, 'entomology reference'),
('e5b4aa12-e1d4-55a5-abbe-4c052d8ee00a'::uuid, 'About how many years can a termite queen live?', 50, 'years', 4, 'entomology reference'),
('3cb48f4a-1648-5c5f-a2e9-9d2dcff02041'::uuid, 'How many years can a periodical cicada spend underground before emerging?', 17, 'years', 2, 'entomology reference'),
('f218074a-994c-5ef2-8e26-abafc36ed08c'::uuid, 'About how many eggs can be contained in one praying mantis egg case?', 200, 'items', 3, 'entomology reference'),
('97b65178-c717-5ff0-b003-f71e2e934828'::uuid, 'About how many centimeters long can the world''s longest stick insects grow?', 64, 'centimeters', 4, 'entomology reference'),
('a100bac8-fce1-536d-baf9-d0ef7e2dfac1'::uuid, 'About how many grams can a giant weta weigh?', 70, 'grams', 4, 'entomology reference'),
('88472306-519f-5c21-82e5-01215c96eb84'::uuid, 'How many eyes does a horseshoe crab have in total?', 10, 'items', 3, 'marine biology reference'),
('ecc00db8-c7a7-593d-9482-e5d200c785c1'::uuid, 'About how many teeth does a medicinal leech have across its three jaws?', 300, 'items', 4, 'zoological reference'),
('64dcd67b-b0b2-5f1f-a03a-c5453e46193a'::uuid, 'About how many microscopic teeth can a garden snail have on its radula?', 14000, 'items', 4, 'zoological reference'),
('164eb3b2-c2b5-5ae0-a244-7641e35a2bf8'::uuid, 'How many pairs of aortic arches, often called hearts, does an earthworm have?', 5, 'pairs', 3, 'zoological reference'),
('e02fe353-a35a-562b-a80c-7a01c42f27fb'::uuid, 'About how many body segments does a typical earthworm have?', 100, 'items', 3, 'zoological reference'),
('63affff6-203d-5eea-9b06-a9f259947a66'::uuid, 'About how many chambers can an adult chambered nautilus shell contain?', 30, 'items', 4, 'marine biology reference'),
('bda38963-32a8-5457-8c2a-020fe8bec52c'::uuid, 'About how many years can a red sea urchin live?', 200, 'years', 4, 'marine biology reference'),
('37fddfc4-08c2-546c-abf2-5c3c539baaf1'::uuid, 'How many teeth make up Aristotle''s lantern in a typical sea urchin?', 5, 'items', 4, 'marine biology reference'),
('f9a83014-3ae1-5839-8a6b-efed213ef8fe'::uuid, 'How many legs does a tardigrade have?', 8, 'items', 2, 'zoological reference'),
('390d9be0-d22c-5599-b447-ebcf5f7adbeb'::uuid, 'About how many centimeters long can a giant hydrothermal-vent tube worm grow?', 240, 'centimeters', 4, 'marine biology reference'),
('b92bde75-870a-543b-9e01-c36a15e88ec5'::uuid, 'About how many centimeters across can a giant squid''s eye measure?', 27, 'centimeters', 4, 'marine biology reference');

do $$
declare v_rows int; v_texts int; v_collisions int; v_id_collisions int;
begin
  select count(*), count(distinct lower(btrim(text_en))) into v_rows, v_texts from _animals_stage_3;
  if v_rows <> 50 or v_texts <> 50 then
    raise exception 'Animals batch 3 staging invalid: rows %, unique texts %', v_rows, v_texts;
  end if;
  if exists (select 1 from _animals_stage_3
             where btrim(text_en)='' or answer<=0 or btrim(answer_unit)=''
                or difficulty not between 1 and 5 or btrim(source)='') then
    raise exception 'Animals batch 3 contains invalid content';
  end if;
  select count(*) into v_id_collisions from _animals_stage_3 s join public.questions q on q.id=s.id;
  if v_id_collisions<>0 then raise exception 'Animals batch 3 UUID collisions: %', v_id_collisions; end if;
  select count(*) into v_collisions
  from _animals_stage_3 s join public.questions q
    on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Animals batch 3 wording collisions: %', v_collisions; end if;
end $$;

insert into public.questions
  (id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Animals',difficulty,source,'premium'
from _animals_stage_3;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _animals_stage_3 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Animals batch 3 inserted % rows', v_inserted; end if;
  select count(*) into v_bad
  from public.questions q join _animals_stage_3 s on s.id=q.id
  where q.category<>'Animals' or q.access_tier<>'premium'
     or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en
     or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit
     or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Animals batch 3 post validation failed: %', v_bad; end if;
end $$;
commit;