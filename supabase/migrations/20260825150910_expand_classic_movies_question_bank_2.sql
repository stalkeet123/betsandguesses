begin;
create temporary table _movies_stage_2 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _movies_stage_2 (id,text_en,answer,answer_unit,difficulty,source) values
('ea2ea776-6586-5631-a4c9-09217e87f481'::uuid, 'In what year was Alien released?', 1979, 'year', 2, 'film release reference'),
('43146e0f-fda1-5344-8820-e1f8e4c5d0d3'::uuid, 'In what year was Aliens released?', 1986, 'year', 2, 'film release reference'),
('c2272524-2e76-5db7-a098-7035503de9a4'::uuid, 'In what year was Arrival released?', 2016, 'year', 2, 'film release reference'),
('bdd7618e-f7e7-58c0-80ff-347992306172'::uuid, 'In what year was Back to the Future released?', 1985, 'year', 2, 'film release reference'),
('9ae3e3fa-caad-5f27-9164-4c2345a3d683'::uuid, 'In what year was Barbie released?', 2023, 'year', 2, 'film release reference'),
('2dac4c73-3d80-54bd-a2ac-c1cf1079ff55'::uuid, 'In what year was Batman Begins released?', 2005, 'year', 2, 'film release reference'),
('e3052a10-835e-5724-9efa-a2cd61c9ae40'::uuid, 'In what year was Blade Runner released?', 1982, 'year', 2, 'film release reference'),
('bdce7255-6829-568b-853f-5afcd0c77163'::uuid, 'In what year was Die Hard released?', 1988, 'year', 2, 'film release reference'),
('5d2c9f46-f21e-57df-9da1-2ece3311af1c'::uuid, 'In what year was Django Unchained released?', 2012, 'year', 2, 'film release reference'),
('ba78b620-a624-59ae-9bb9-b17a44fa6112'::uuid, 'In what year was Drive released?', 2011, 'year', 2, 'film release reference'),
('df368588-8a09-5668-a409-6ff0cf1b0890'::uuid, 'In what year was Dune released?', 2021, 'year', 2, 'film release reference'),
('777c2f15-f772-5f8e-9683-d97a970e14c0'::uuid, 'In what year was Dune: Part Two released?', 2024, 'year', 2, 'film release reference'),
('aaeb3934-790a-547a-aa72-3309d103c44a'::uuid, 'In what year was E.T. the Extra-Terrestrial released?', 1982, 'year', 2, 'film release reference'),
('0875725f-cf67-5d3f-b0bb-c4ea0cc32868'::uuid, 'In what year was Eternal Sunshine of the Spotless Mind released?', 2004, 'year', 2, 'film release reference'),
('1097c8d2-e9fb-5327-a949-342c57fcc84a'::uuid, 'In what year was Everything Everywhere All at Once released?', 2022, 'year', 2, 'film release reference'),
('a26757e2-5157-5b0a-b166-102beec970dc'::uuid, 'In what year was Fight Club released?', 1999, 'year', 2, 'film release reference'),
('2dc73ab8-b06b-5d75-b2b6-92605bc11290'::uuid, 'In what year was Forrest Gump released?', 1994, 'year', 2, 'film release reference'),
('c753a43c-40dd-5bd7-944a-ce653a04f28c'::uuid, 'In what year was Get Out released?', 2017, 'year', 2, 'film release reference'),
('9da08a2d-283a-57b1-8f0f-e692635c1425'::uuid, 'In what year was Gladiator released?', 2000, 'year', 2, 'film release reference'),
('007eddd0-7a34-5e9c-9529-24457e96802b'::uuid, 'In what year was Goodfellas released?', 1990, 'year', 2, 'film release reference'),
('6bb6452b-1b97-528e-ab0e-845ff5d0c629'::uuid, 'In what year was Her released?', 2013, 'year', 2, 'film release reference'),
('fa8870ed-25fb-5e2c-bbcb-b4b0878c6ae5'::uuid, 'In what year was Inception released?', 2010, 'year', 2, 'film release reference'),
('9eecc59f-10e0-51ab-a760-a6a6500d5ca5'::uuid, 'In what year was Jurassic Park released?', 1993, 'year', 2, 'film release reference'),
('0acb96d6-32c2-5513-bfd9-8a883692a958'::uuid, 'In what year was Mad Max: Fury Road released?', 2015, 'year', 2, 'film release reference'),
('14c700a2-5219-564e-8939-2e851f79cf71'::uuid, 'In what year was No Country for Old Men released?', 2007, 'year', 2, 'film release reference'),
('21fe80cc-73b8-5806-b58c-8a67caa25035'::uuid, 'In what year was Oppenheimer released?', 2023, 'year', 2, 'film release reference'),
('9605f070-cd35-5e15-bfb7-09ec3bd8ad7c'::uuid, 'In what year was Parasite released?', 2019, 'year', 2, 'film release reference'),
('f3d21d93-bad0-54e4-82b8-fd84dc89f352'::uuid, 'In what year was Pulp Fiction released?', 1994, 'year', 2, 'film release reference'),
('75af39d9-2d31-5056-a6f7-5b282b2e2066'::uuid, 'In what year was Raiders of the Lost Ark released?', 1981, 'year', 2, 'film release reference'),
('03c4da95-9401-571b-8ddf-d790cedcbcb3'::uuid, 'In what year was Schindler''s List released?', 1993, 'year', 2, 'film release reference'),
('1fb866b4-5358-5775-9993-c100bd4e6498'::uuid, 'In what year was Se7en released?', 1995, 'year', 2, 'film release reference'),
('e0bd512c-38c2-5451-849c-f077df9690eb'::uuid, 'In what year was Spirited Away released?', 2001, 'year', 2, 'film release reference'),
('cb71e3b0-b81d-5eb5-8a28-3bb0c495c7bd'::uuid, 'In what year was Star Wars released?', 1977, 'year', 2, 'film release reference'),
('ab7eb89e-480a-56ee-8415-a8d781fb4533'::uuid, 'In what year was The Dark Knight released?', 2008, 'year', 2, 'film release reference'),
('55a3e09a-ea98-5d04-b09b-b0fcafee146c'::uuid, 'In what year was The Departed released?', 2006, 'year', 2, 'film release reference'),
('03c74097-9c54-5da4-87b8-dd39fd16a1a9'::uuid, 'In what year was The Empire Strikes Back released?', 1980, 'year', 2, 'film release reference'),
('ae9956d9-584a-56ee-99df-40f9cd451bd8'::uuid, 'In what year was The Lion King from 1994 released?', 1994, 'year', 2, 'film release reference'),
('97f69b49-88e3-54e1-b5e9-37ab3d9079bd'::uuid, 'In what year was The Lord of the Rings: The Fellowship of the Ring released?', 2001, 'year', 2, 'film release reference'),
('725f9f32-a810-5c13-83d0-c1b93798c484'::uuid, 'In what year was The Lord of the Rings: The Return of the King released?', 2003, 'year', 2, 'film release reference'),
('2b4473be-c6d1-5279-ae55-6a1a6d014319'::uuid, 'In what year was The Lord of the Rings: The Two Towers released?', 2002, 'year', 2, 'film release reference'),
('f891e82a-f4f1-52f6-bd8e-c99ec97b3f09'::uuid, 'In what year was The Matrix released?', 1999, 'year', 2, 'film release reference'),
('93ec5711-0ced-58fa-b3fb-6ea443e58f06'::uuid, 'In what year was The Silence of the Lambs released?', 1991, 'year', 2, 'film release reference'),
('6d82a079-9b8e-5866-9ab7-34a4b16b8f8a'::uuid, 'In what year was The Social Network released?', 2010, 'year', 2, 'film release reference'),
('c85f8940-aad1-5d38-9d0e-34bafca07519'::uuid, 'In what year was The Terminator released?', 1984, 'year', 2, 'film release reference'),
('e6e68691-98f7-56ac-b2cc-20541c853d0f'::uuid, 'In what year was The Truman Show released?', 1998, 'year', 2, 'film release reference'),
('81db0988-d43a-52e4-a62f-cc4ff6bc0307'::uuid, 'In what year was There Will Be Blood released?', 2007, 'year', 2, 'film release reference'),
('c6d09b02-5f71-54fd-aee8-7906b0792e59'::uuid, 'In what year was Titanic released?', 1997, 'year', 2, 'film release reference'),
('17de6ec5-becf-569c-864f-9075e171feea'::uuid, 'In what year was Toy Story released?', 1995, 'year', 2, 'film release reference'),
('28d21018-2b7d-5ad5-a50a-9d09d860bc36'::uuid, 'In what year was Up released?', 2009, 'year', 2, 'film release reference'),
('d210f891-4ab1-57e0-b3bf-b62ccc71fe7f'::uuid, 'In what year was Whiplash released?', 2014, 'year', 2, 'film release reference');

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _movies_stage_2;
  if v_rows<>50 or v_texts<>50 then raise exception 'Movies batch 2 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _movies_stage_2 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Movies batch 2 invalid content'; end if;
  select count(*) into v_ids from _movies_stage_2 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Movies batch 2 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _movies_stage_2 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Movies batch 2 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Movies',difficulty,source,'premium' from _movies_stage_2;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _movies_stage_2 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Movies batch 2 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _movies_stage_2 s on s.id=q.id where q.category<>'Movies' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Movies batch 2 post validation failed: %',v_bad; end if;
end $$;
commit;