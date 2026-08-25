begin;
create temporary table _movies_stage_3 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _movies_stage_3 (id,text_en,answer,answer_unit,difficulty,source) values
('87baa731-47c7-5672-b09a-421e7ec535b8'::uuid, 'How many competitive Academy Awards did Amadeus win?', 8, 'awards', 3, 'Academy Awards ceremony records'),
('8471494f-767a-57dc-b88c-a880a1bcf761'::uuid, 'How many competitive Academy Awards did Ben-Hur from 1959 win?', 11, 'awards', 3, 'Academy Awards ceremony records'),
('f2c62dc2-2c62-5e32-8286-5dc65207a77e'::uuid, 'How many competitive Academy Awards did Cabaret win?', 8, 'awards', 3, 'Academy Awards ceremony records'),
('4b91bf01-daca-55a3-bd48-7388e7fc26e6'::uuid, 'How many competitive Academy Awards did Dances with Wolves win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('b80fdc4d-110d-5d18-afa1-8d2b0ff4f84b'::uuid, 'How many competitive Academy Awards did Everything Everywhere All at Once win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('080cc774-afeb-5b5b-a4f4-e0e36e2dabf2'::uuid, 'How many competitive Academy Awards did From Here to Eternity win?', 8, 'awards', 3, 'Academy Awards ceremony records'),
('aee9d494-7526-5e3b-a80b-1307a72b2a85'::uuid, 'How many competitive Academy Awards did Gandhi win?', 8, 'awards', 3, 'Academy Awards ceremony records'),
('fe8dd30d-37d8-54f1-b759-241831e2fbea'::uuid, 'How many competitive Academy Awards did Gigi win?', 9, 'awards', 3, 'Academy Awards ceremony records'),
('f041b182-fd00-544e-b187-9effb55f11d2'::uuid, 'How many competitive Academy Awards did Gone with the Wind win?', 8, 'awards', 3, 'Academy Awards ceremony records'),
('178a6961-aceb-5962-a896-9a31af27b3e9'::uuid, 'How many competitive Academy Awards did Gravity win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('7b70d4b0-f94d-5221-b974-71e7ae28c2e6'::uuid, 'How many competitive Academy Awards did Lawrence of Arabia win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('99b177a5-50bc-5162-9550-3e6d4f736e2a'::uuid, 'How many competitive Academy Awards did My Fair Lady win?', 8, 'awards', 3, 'Academy Awards ceremony records'),
('c89e1717-2ed8-5afa-abc6-005e5506947f'::uuid, 'How many competitive Academy Awards did On the Waterfront win?', 8, 'awards', 3, 'Academy Awards ceremony records'),
('c5ccc350-8c88-5cd2-963e-4c3858ffcbe3'::uuid, 'How many competitive Academy Awards did Oppenheimer win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('f89a79e9-abd4-52b5-93b0-e7f22d9a1a24'::uuid, 'How many competitive Academy Awards did Out of Africa win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('2be5a49b-142f-575b-a45a-f00a61c1e420'::uuid, 'How many competitive Academy Awards did Patton win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('8d04baa5-90d2-525a-aaf3-8aa1d984a115'::uuid, 'How many competitive Academy Awards did Schindler''s List win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('6293d0da-372e-54b4-9437-685984fb8926'::uuid, 'How many competitive Academy Awards did Shakespeare in Love win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('c8109b26-84cc-5711-94f4-d8e43593d0ac'::uuid, 'How many competitive Academy Awards did Slumdog Millionaire win?', 8, 'awards', 3, 'Academy Awards ceremony records'),
('c6b414c2-5497-5153-95db-960f441afce0'::uuid, 'How many competitive Academy Awards did The English Patient win?', 9, 'awards', 3, 'Academy Awards ceremony records'),
('372f076a-92da-558d-8371-c7ba695f89f6'::uuid, 'How many competitive Academy Awards did The Last Emperor win?', 9, 'awards', 3, 'Academy Awards ceremony records'),
('f765d4a9-8d34-5e51-8c4b-11f01ca966e6'::uuid, 'How many competitive Academy Awards did The Lord of the Rings: The Return of the King win?', 11, 'awards', 3, 'Academy Awards ceremony records'),
('41611de4-5b21-59db-a1aa-fe74fd24bfba'::uuid, 'How many competitive Academy Awards did The Sting win?', 7, 'awards', 3, 'Academy Awards ceremony records'),
('7248af28-6352-5ed7-819e-a6e3826ccf2c'::uuid, 'How many competitive Academy Awards did Titanic win?', 11, 'awards', 3, 'Academy Awards ceremony records'),
('8579ee94-40c6-585b-b11c-835c827353c0'::uuid, 'How many competitive Academy Awards did West Side Story from 1961 win?', 10, 'awards', 3, 'Academy Awards ceremony records'),
('6214ab9c-1521-52e3-912f-3263a2a8d1eb'::uuid, 'About how many million US dollars has Avatar grossed worldwide?', 2924, 'USD millions', 3, 'The Numbers worldwide box office'),
('92ac84fc-1e5a-509a-ac74-bb5453bb5f01'::uuid, 'About how many million US dollars has Avatar: The Way of Water grossed worldwide?', 2323, 'USD millions', 3, 'The Numbers worldwide box office'),
('7e2eb61f-c892-5b1b-a62b-e12a5ab2f0d3'::uuid, 'About how many million US dollars has Avengers: Age of Ultron grossed worldwide?', 1395, 'USD millions', 3, 'The Numbers worldwide box office'),
('0340ef5d-a83c-5b05-b381-56907f3d51f3'::uuid, 'About how many million US dollars has Avengers: Endgame grossed worldwide?', 2718, 'USD millions', 3, 'The Numbers worldwide box office'),
('c347ec27-02b4-5b0a-ab99-91cfe4c5e4ca'::uuid, 'About how many million US dollars has Avengers: Infinity War grossed worldwide?', 2048, 'USD millions', 3, 'The Numbers worldwide box office'),
('3afd8fb6-c07e-524d-b127-2c9e2171cf05'::uuid, 'About how many million US dollars has Barbie grossed worldwide?', 1448, 'USD millions', 3, 'The Numbers worldwide box office'),
('3ea214eb-ff5c-526b-9a41-ea2e33b32906'::uuid, 'About how many million US dollars has Beauty and the Beast from 2017 grossed worldwide?', 1260, 'USD millions', 3, 'The Numbers worldwide box office'),
('24ca3828-e42c-587b-84c1-19a018f8696c'::uuid, 'About how many million US dollars has Black Panther grossed worldwide?', 1334, 'USD millions', 3, 'The Numbers worldwide box office'),
('bde8d49a-5506-50cc-951c-de1fa1668a66'::uuid, 'About how many million US dollars has Deadpool & Wolverine grossed worldwide?', 1338, 'USD millions', 3, 'The Numbers worldwide box office'),
('28b57757-d399-52b8-a102-fcbce4f633ab'::uuid, 'About how many million US dollars has Frozen grossed worldwide?', 1269, 'USD millions', 3, 'The Numbers worldwide box office'),
('ae1fa5e7-78dc-541c-9d94-8e5aa3b8ca6d'::uuid, 'About how many million US dollars has Frozen II grossed worldwide?', 1452, 'USD millions', 3, 'The Numbers worldwide box office'),
('3f4859f7-e2e5-5874-b2ac-c42d652ab579'::uuid, 'About how many million US dollars has Furious 7 grossed worldwide?', 1510, 'USD millions', 3, 'The Numbers worldwide box office'),
('f531591e-761f-5459-af58-148a2fe8fc7f'::uuid, 'About how many million US dollars has Harry Potter and the Deathly Hallows – Part 2 grossed worldwide?', 1312, 'USD millions', 3, 'The Numbers worldwide box office'),
('1ce1a74b-8518-529b-bc83-36569061f1d8'::uuid, 'About how many million US dollars has Incredibles 2 grossed worldwide?', 1243, 'USD millions', 3, 'The Numbers worldwide box office'),
('ba10ee5e-73c2-525f-8691-4c01fea86a99'::uuid, 'About how many million US dollars has Inside Out 2 grossed worldwide?', 1699, 'USD millions', 3, 'The Numbers worldwide box office'),
('f3ec8df8-757a-5682-8da8-dda2d87cafc7'::uuid, 'About how many million US dollars has Jurassic World grossed worldwide?', 1671, 'USD millions', 3, 'The Numbers worldwide box office'),
('fdf52cce-93aa-5abd-8eee-b80674b89125'::uuid, 'About how many million US dollars has Jurassic World: Fallen Kingdom grossed worldwide?', 1308, 'USD millions', 3, 'The Numbers worldwide box office'),
('f324c71a-4f4d-5836-9571-9213aa897c0f'::uuid, 'About how many million US dollars has Spider-Man: No Way Home grossed worldwide?', 1921, 'USD millions', 3, 'The Numbers worldwide box office'),
('59af59e9-7616-5209-aa88-2ea465dfec53'::uuid, 'About how many million US dollars has Star Wars: The Force Awakens grossed worldwide?', 2056, 'USD millions', 3, 'The Numbers worldwide box office'),
('9645b57a-286e-533c-abc4-1574f5e68209'::uuid, 'About how many million US dollars has Star Wars: The Last Jedi grossed worldwide?', 1323, 'USD millions', 3, 'The Numbers worldwide box office'),
('8c117475-d52e-5f6b-b9dd-7a8ffac77682'::uuid, 'About how many million US dollars has The Avengers grossed worldwide?', 1515, 'USD millions', 3, 'The Numbers worldwide box office'),
('6976ed5e-5eb0-5ba5-aae2-d3001721cd11'::uuid, 'About how many million US dollars has The Lion King from 2019 grossed worldwide?', 1661, 'USD millions', 3, 'The Numbers worldwide box office'),
('796d28ee-b8e3-5a3d-8a68-40ab6496b253'::uuid, 'About how many million US dollars has The Super Mario Bros. Movie grossed worldwide?', 1359, 'USD millions', 3, 'The Numbers worldwide box office'),
('264ab676-c8c6-5e8b-9e25-c0a0ccfab770'::uuid, 'About how many million US dollars has Titanic grossed worldwide?', 2223, 'USD millions', 3, 'The Numbers worldwide box office'),
('5dce10fc-825e-5aab-9226-43d35016701f'::uuid, 'About how many million US dollars has Top Gun: Maverick grossed worldwide?', 1452, 'USD millions', 3, 'The Numbers worldwide box office');

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _movies_stage_3;
  if v_rows<>50 or v_texts<>50 then raise exception 'Movies batch 3 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _movies_stage_3 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Movies batch 3 invalid content'; end if;
  select count(*) into v_ids from _movies_stage_3 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Movies batch 3 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _movies_stage_3 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Movies batch 3 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Movies',difficulty,source,'premium' from _movies_stage_3;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _movies_stage_3 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Movies batch 3 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _movies_stage_3 s on s.id=q.id where q.category<>'Movies' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Movies batch 3 post validation failed: %',v_bad; end if;
end $$;
commit;