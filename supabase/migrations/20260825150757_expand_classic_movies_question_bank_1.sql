begin;
create temporary table _movies_stage_1 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _movies_stage_1 (id,text_en,answer,answer_unit,difficulty,source) values
('d55febee-b0ef-5cdf-b5c5-c08db729cfaf'::uuid, 'About how many minutes long is Avatar: The Way of Water?', 192, 'minutes', 2, 'film runtime reference'),
('df687dad-5b96-54e2-aa03-c2bb746bf9c0'::uuid, 'About how many minutes long is Avatar?', 162, 'minutes', 2, 'film runtime reference'),
('3a223983-85cd-554d-a576-65b0eecae76f'::uuid, 'About how many minutes long is Back to the Future?', 116, 'minutes', 2, 'film runtime reference'),
('12c833e2-eef5-50f5-9083-8208b1eaefa5'::uuid, 'About how many minutes long is Braveheart?', 178, 'minutes', 2, 'film runtime reference'),
('ba99f7bc-0239-5d28-9671-6f160d79f6af'::uuid, 'About how many minutes long is Casino?', 178, 'minutes', 2, 'film runtime reference'),
('f0c4bc34-ac35-5382-976b-cabd8ea68bc3'::uuid, 'About how many minutes long is E.T. the Extra-Terrestrial?', 115, 'minutes', 2, 'film runtime reference'),
('438daedb-72e1-52a2-8591-f12e1dd2cf38'::uuid, 'About how many minutes long is Everything Everywhere All at Once?', 139, 'minutes', 2, 'film runtime reference'),
('6c4ccef9-81e3-578a-8759-a5ee9914e34f'::uuid, 'About how many minutes long is Fight Club?', 139, 'minutes', 2, 'film runtime reference'),
('e35e484c-7d26-5e98-a586-f0df80f6a3e4'::uuid, 'About how many minutes long is Forrest Gump?', 142, 'minutes', 2, 'film runtime reference'),
('871ddcb7-544b-533d-ae00-bf93078d08a9'::uuid, 'About how many minutes long is Get Out?', 104, 'minutes', 2, 'film runtime reference'),
('cc41c3da-6781-5ad0-b248-26f4861579d1'::uuid, 'About how many minutes long is Ghostbusters from 1984?', 105, 'minutes', 2, 'film runtime reference'),
('9137e3e7-07ee-58ed-bf19-3dee4031c529'::uuid, 'About how many minutes long is Gladiator?', 155, 'minutes', 2, 'film runtime reference'),
('ae4003c7-fdd5-57ee-8b69-b74729b7c540'::uuid, 'About how many minutes long is Goodfellas?', 146, 'minutes', 2, 'film runtime reference'),
('876bcab8-64e2-5082-91e9-651f8762d319'::uuid, 'About how many minutes long is Groundhog Day?', 101, 'minutes', 2, 'film runtime reference'),
('71a73c5f-4b0e-5a26-a97c-9d8e388e8911'::uuid, 'About how many minutes long is Home Alone?', 103, 'minutes', 2, 'film runtime reference'),
('64bcd4cb-0672-5aa0-b5b7-ca7f0769eb4b'::uuid, 'About how many minutes long is Inception?', 148, 'minutes', 2, 'film runtime reference'),
('4fb770ff-cfe0-5b6b-99cd-aab440fa858b'::uuid, 'About how many minutes long is Interstellar?', 169, 'minutes', 2, 'film runtime reference'),
('31a243b9-9946-558a-9266-85920561354e'::uuid, 'About how many minutes long is Jaws?', 124, 'minutes', 2, 'film runtime reference'),
('420ef736-b429-5a26-b68e-81f3b9bed21b'::uuid, 'About how many minutes long is Jurassic Park?', 127, 'minutes', 2, 'film runtime reference'),
('9ee67e88-423f-5bc1-b880-d9bd42b8a747'::uuid, 'About how many minutes long is La La Land?', 128, 'minutes', 2, 'film runtime reference'),
('b2da328c-6530-5f30-b6fc-fec51b890216'::uuid, 'About how many minutes long is Mad Max: Fury Road?', 120, 'minutes', 2, 'film runtime reference'),
('9934c12e-a9cd-5d66-9a13-f59862f06ee6'::uuid, 'About how many minutes long is Oppenheimer?', 180, 'minutes', 2, 'film runtime reference'),
('56318ed8-2079-567a-9e32-be53770b9b4b'::uuid, 'About how many minutes long is Parasite?', 132, 'minutes', 2, 'film runtime reference'),
('6cfce875-ac46-57cb-a554-45b9942ea0db'::uuid, 'About how many minutes long is Pulp Fiction?', 154, 'minutes', 2, 'film runtime reference'),
('2f681110-6735-506c-8492-cc5efde79c32'::uuid, 'About how many minutes long is Raiders of the Lost Ark?', 115, 'minutes', 2, 'film runtime reference'),
('625bdfd8-7cfd-5097-b74a-fbf655d07f06'::uuid, 'About how many minutes long is Saving Private Ryan?', 169, 'minutes', 2, 'film runtime reference'),
('21ceecf2-d086-5b96-b0e6-d8be8ddb4ead'::uuid, 'About how many minutes long is Schindler''s List?', 195, 'minutes', 2, 'film runtime reference'),
('9ca1fe41-71d2-51a6-bd7f-73d367ece99c'::uuid, 'About how many minutes long is The Dark Knight?', 152, 'minutes', 2, 'film runtime reference'),
('939c69d8-8af9-58e4-bb70-dd83eebf226c'::uuid, 'About how many minutes long is The Departed?', 151, 'minutes', 2, 'film runtime reference'),
('02aee856-e67f-5389-87f8-890e02b1cb7d'::uuid, 'About how many minutes long is The Godfather Part II?', 202, 'minutes', 2, 'film runtime reference'),
('423bfc09-c5cb-50e0-b0d7-c00c9441bd3a'::uuid, 'About how many minutes long is The Godfather?', 175, 'minutes', 2, 'film runtime reference'),
('b8604d76-add2-5e32-9032-8b3e931dbb40'::uuid, 'About how many minutes long is The Grand Budapest Hotel?', 99, 'minutes', 2, 'film runtime reference'),
('27ddcb0e-31f0-596c-9296-c128f56aca5b'::uuid, 'About how many minutes long is The Lion King from 1994?', 88, 'minutes', 2, 'film runtime reference'),
('54f2ec52-baa0-5e11-bfd6-d6c011d39935'::uuid, 'About how many minutes long is The Matrix?', 136, 'minutes', 2, 'film runtime reference'),
('3785698e-c72c-50cb-9e1c-c4c8bd4d5f79'::uuid, 'About how many minutes long is The Shawshank Redemption?', 142, 'minutes', 2, 'film runtime reference'),
('63230edc-efe0-5335-b826-6ae847144719'::uuid, 'About how many minutes long is The Silence of the Lambs?', 118, 'minutes', 2, 'film runtime reference'),
('705e11b2-b78a-5710-be11-ee446d598c4f'::uuid, 'About how many minutes long is The Social Network?', 120, 'minutes', 2, 'film runtime reference'),
('4ad695d7-239f-5c85-9a4c-938ea3983343'::uuid, 'About how many minutes long is The Truman Show?', 103, 'minutes', 2, 'film runtime reference'),
('50330d1d-f90c-5f46-a33a-f64fe5a67ff4'::uuid, 'About how many minutes long is Titanic?', 194, 'minutes', 2, 'film runtime reference'),
('21cf853f-1f82-5312-abae-903c3a322a65'::uuid, 'About how many minutes long is Whiplash?', 107, 'minutes', 2, 'film runtime reference'),
('419664ca-1ea8-5224-b669-5c551d6c33d0'::uuid, 'In what year was 2001: A Space Odyssey released?', 1968, 'year', 2, 'film release reference'),
('de42349f-ab16-583f-8962-1658656b384c'::uuid, 'In what year was Casablanca released?', 1942, 'year', 2, 'film release reference'),
('c09aaac0-5e89-5a3b-a826-5ba4c9b14982'::uuid, 'In what year was Citizen Kane released?', 1941, 'year', 2, 'film release reference'),
('dae3bbe3-5f4c-527d-90f6-9079d9dfd94e'::uuid, 'In what year was Jaws released?', 1975, 'year', 2, 'film release reference'),
('8f16f27a-96f9-5d76-8886-ea1e67a6abc3'::uuid, 'In what year was Psycho released?', 1960, 'year', 2, 'film release reference'),
('3ee2c23f-b9fa-5e16-a380-92b5ce3fd7ec'::uuid, 'In what year was Rocky released?', 1976, 'year', 2, 'film release reference'),
('76a3bd9c-aeb9-557e-be53-45b27527797c'::uuid, 'In what year was Seven Samurai released?', 1954, 'year', 2, 'film release reference'),
('8294ff61-2a13-5ac6-ad8c-3c969f0680d6'::uuid, 'In what year was Singin'' in the Rain released?', 1952, 'year', 2, 'film release reference'),
('0ae82bd5-6bb6-50cc-b721-5cb5ed7fd48e'::uuid, 'In what year was The Godfather released?', 1972, 'year', 2, 'film release reference'),
('dbee14ca-d11b-597a-a221-b7a8b929fb6e'::uuid, 'In what year was The Wizard of Oz released?', 1939, 'year', 2, 'film release reference');

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _movies_stage_1;
  if v_rows<>50 or v_texts<>50 then raise exception 'Movies batch 1 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _movies_stage_1 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Movies batch 1 invalid content'; end if;
  select count(*) into v_ids from _movies_stage_1 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Movies batch 1 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _movies_stage_1 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Movies batch 1 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Movies',difficulty,source,'premium' from _movies_stage_1;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _movies_stage_1 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Movies batch 1 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _movies_stage_1 s on s.id=q.id where q.category<>'Movies' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Movies batch 1 post validation failed: %',v_bad; end if;
end $$;
commit;