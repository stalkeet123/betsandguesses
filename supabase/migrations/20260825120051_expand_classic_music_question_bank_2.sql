begin;
create temporary table _music_stage_2 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _music_stage_2 (id, text_en, answer, answer_unit, difficulty, source) values
('feac87de-27fc-5773-adca-ac10b5e0d261'::uuid, 'In what year was Michael Jackson''s Thriller released?', 1982, 'year', 1, 'album reference'),
('237b603c-b601-5bfb-8375-12a061bf3e3b'::uuid, 'How many tracks are on the original standard edition of Michael Jackson''s Thriller?', 9, 'items', 2, 'album track list'),
('57b3efee-7572-54d3-9746-885be4505032'::uuid, 'In what year was Pink Floyd''s The Dark Side of the Moon released?', 1973, 'year', 1, 'album reference'),
('b5968ae7-f5dc-50e8-81fe-c422f90662c4'::uuid, 'How many tracks are on Pink Floyd''s The Dark Side of the Moon?', 10, 'items', 2, 'album track list'),
('61ca1888-2475-5075-9cfa-e1cb3eeb0a35'::uuid, 'In what year was Fleetwood Mac''s Rumours released?', 1977, 'year', 1, 'album reference'),
('a1620edb-0278-5e9d-8d47-ce9ed2d687d3'::uuid, 'How many tracks are on the original edition of Fleetwood Mac''s Rumours?', 11, 'items', 2, 'album track list'),
('01063bdb-7ec5-5022-8c9c-ca836f7bd786'::uuid, 'In what year was The Beatles'' Abbey Road released?', 1969, 'year', 1, 'album reference'),
('20ee8377-f156-52b9-87a4-487b4dc8495d'::uuid, 'How many tracks are on The Beatles'' Abbey Road?', 17, 'items', 2, 'album track list'),
('647ffd1c-b930-56b1-aa3e-90a1d04fd8f6'::uuid, 'In what year was The Beatles'' Sgt. Pepper''s Lonely Hearts Club Band released?', 1967, 'year', 1, 'album reference'),
('8224d6ae-b293-5c98-a824-25cbbb373a13'::uuid, 'How many tracks are on Sgt. Pepper''s Lonely Hearts Club Band?', 13, 'items', 2, 'album track list'),
('71dbe9c3-4978-52ac-8c3b-fe869046986e'::uuid, 'In what year was Prince''s Purple Rain album released?', 1984, 'year', 1, 'album reference'),
('04072b19-5fb5-5dbc-83f2-34198e7e531b'::uuid, 'How many tracks are on Prince''s Purple Rain album?', 9, 'items', 2, 'album track list'),
('ab32e6c9-2210-5560-b312-68052e65ebbf'::uuid, 'In what year was AC/DC''s Back in Black released?', 1980, 'year', 1, 'album reference'),
('76e906e0-0e10-5c40-887c-8ff90e3f1467'::uuid, 'How many tracks are on AC/DC''s Back in Black?', 10, 'items', 2, 'album track list'),
('431ef9d6-a853-57e5-901e-e3188c93957f'::uuid, 'In what year was Pink Floyd''s The Wall released?', 1979, 'year', 1, 'album reference'),
('4c728264-e745-5bbb-ac1d-fb7a5c799ed4'::uuid, 'How many tracks are on the original edition of Pink Floyd''s The Wall?', 26, 'items', 3, 'album track list'),
('a8151a17-94d5-598e-98ea-e3d7523fb562'::uuid, 'In what year was Bruce Springsteen''s Born in the U.S.A. released?', 1984, 'year', 1, 'album reference'),
('7a6aec05-727e-56d7-8b6a-fc6ab61cecd4'::uuid, 'How many tracks are on Bruce Springsteen''s Born in the U.S.A.?', 12, 'items', 2, 'album track list'),
('e69e7795-4690-5414-a588-d27b1ecb389c'::uuid, 'In what year was Eagles'' Hotel California released?', 1976, 'year', 1, 'album reference'),
('2b075820-5b7c-5c59-87dd-70b0e7477c16'::uuid, 'How many tracks are on the original Hotel California album?', 9, 'items', 2, 'album track list'),
('3f5657db-9dce-5701-9266-a98f601440c5'::uuid, 'In what year was Guns N'' Roses'' Appetite for Destruction released?', 1987, 'year', 1, 'album reference'),
('2fadef77-048a-502b-9e0e-d5b437f2762a'::uuid, 'How many tracks are on Appetite for Destruction?', 12, 'items', 2, 'album track list'),
('96c01dc8-3b76-58ca-9134-7990b289f9c0'::uuid, 'In what year was Radiohead''s OK Computer released?', 1997, 'year', 1, 'album reference'),
('73d4cdc5-d0d9-5846-9e5a-8bf1705f8b5b'::uuid, 'How many tracks are on Radiohead''s OK Computer?', 12, 'items', 2, 'album track list'),
('fc1ee0ee-d16c-5792-bc9a-f55f63207239'::uuid, 'In what year was Daft Punk''s Random Access Memories released?', 2013, 'year', 1, 'album reference'),
('3a0ffae0-c2eb-5d57-aeeb-64b8f8b336c9'::uuid, 'How many tracks are on Daft Punk''s Random Access Memories?', 13, 'items', 2, 'album track list'),
('924e92b4-4834-53f3-ba97-6866c9638405'::uuid, 'In what year was Kendrick Lamar''s To Pimp a Butterfly released?', 2015, 'year', 1, 'album reference'),
('f051783f-c9fb-5478-882e-f818f09ee907'::uuid, 'How many tracks are on the standard edition of To Pimp a Butterfly?', 16, 'items', 2, 'album track list'),
('801ceaf4-9805-5c6c-a6d0-da58438ce2fe'::uuid, 'In what year was Beyonce''s Lemonade released?', 2016, 'year', 1, 'album reference'),
('dd4235a0-a372-5bcd-93b7-b395600a3687'::uuid, 'How many tracks are on Beyonce''s Lemonade?', 12, 'items', 2, 'album track list'),
('2943898e-b789-5e6b-9434-743d7a0c66de'::uuid, 'In what year was Adele''s album 21 released?', 2011, 'year', 1, 'album reference'),
('2497f896-75bf-5bfc-8e6a-2faff9b6253d'::uuid, 'How many tracks are on the standard edition of Adele''s 21?', 11, 'items', 2, 'album track list'),
('b0f3c477-4e8f-521e-80b4-ba960e8771ee'::uuid, 'In what year was The Clash''s London Calling released?', 1979, 'year', 2, 'album reference'),
('948e6938-5e53-5b94-ade1-2e58df830d94'::uuid, 'How many tracks are on the original edition of The Clash''s London Calling?', 19, 'items', 3, 'album track list'),
('507952d8-9126-5cef-af79-5ca09ce6a4db'::uuid, 'In what year was Stevie Wonder''s Songs in the Key of Life released?', 1976, 'year', 2, 'album reference'),
('22b4ae36-cfa5-5628-a2ae-2a9ed15f1e59'::uuid, 'How many tracks are in the complete original Songs in the Key of Life package, including its bonus EP?', 21, 'items', 3, 'album track list'),
('39113d75-bc60-54e9-b995-5db3265eb9a9'::uuid, 'In what year was Nirvana''s Nevermind released?', 1991, 'year', 1, 'album reference'),
('05850a31-f3d6-5fed-8d54-87c0d12cdbc2'::uuid, 'How many tracks were listed on the original Nevermind album before the hidden track?', 12, 'items', 3, 'album track list'),
('8585f23f-8f42-5bd9-853a-7dcfe5364c7e'::uuid, 'In what year was Alanis Morissette''s Jagged Little Pill released?', 1995, 'year', 2, 'album reference'),
('31d20597-03fe-580a-b7da-7bd7062c0c95'::uuid, 'How many tracks were listed on the original Jagged Little Pill album before its hidden track?', 12, 'items', 3, 'album track list'),
('71501fad-0103-52d7-809a-8990f36f4e3f'::uuid, 'In what year was Daft Punk''s Discovery released?', 2001, 'year', 2, 'album reference'),
('21c5b65f-b67f-5c8e-ab38-08addb7a17dc'::uuid, 'How many tracks are on Daft Punk''s Discovery?', 14, 'items', 2, 'album track list'),
('dfecb858-170d-564c-bb1d-d04e2487737f'::uuid, 'In what year was The Strokes'' Is This It released?', 2001, 'year', 2, 'album reference'),
('41ae84d0-188e-5736-9a79-2808ccedc9d6'::uuid, 'How many tracks are on the standard edition of The Strokes'' Is This It?', 11, 'items', 2, 'album track list'),
('3f24cf98-a2d4-5bbf-a868-3d1d46ce1b0d'::uuid, 'In what year was Kanye West''s The College Dropout released?', 2004, 'year', 1, 'album reference'),
('f9ad1acb-3a7b-58f6-93db-e462ab86777f'::uuid, 'How many tracks are on the standard edition of The College Dropout?', 21, 'items', 3, 'album track list'),
('80f36ea9-6e03-5eb8-8fef-88e91fdd3dc0'::uuid, 'In what year was Kendrick Lamar''s good kid, m.A.A.d city released?', 2012, 'year', 1, 'album reference'),
('509c79fd-3d5d-599d-824c-b74b8bf9941a'::uuid, 'How many tracks are on the standard edition of good kid, m.A.A.d city?', 12, 'items', 2, 'album track list'),
('435eccbe-8a62-578e-81c6-0793b8de64c6'::uuid, 'In what year was Frank Ocean''s Channel Orange released?', 2012, 'year', 2, 'album reference'),
('19c3fc51-0398-53ec-bcbe-48c328b0f88e'::uuid, 'How many tracks are on the standard edition of Frank Ocean''s Channel Orange?', 17, 'items', 3, 'album track list');

do $$
declare v_rows int; v_texts int; v_collisions int; v_id_collisions int;
begin
  select count(*), count(distinct lower(btrim(text_en))) into v_rows, v_texts from _music_stage_2;
  if v_rows <> 50 or v_texts <> 50 then raise exception 'Music batch staging invalid: rows %, unique texts %', v_rows, v_texts; end if;
  if exists (select 1 from _music_stage_2 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Music batch contains invalid content'; end if;
  select count(*) into v_id_collisions from _music_stage_2 s join public.questions q on q.id=s.id;
  if v_id_collisions<>0 then raise exception 'Music UUID collisions: %', v_id_collisions; end if;
  select count(*) into v_collisions from _music_stage_2 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Music wording collisions: %', v_collisions; end if;
end $$;

insert into public.questions (id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Music',difficulty,source,'premium' from _music_stage_2;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _music_stage_2 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Music batch inserted % rows', v_inserted; end if;
  select count(*) into v_bad from public.questions q join _music_stage_2 s on s.id=q.id where q.category<>'Music' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Music batch post validation failed: %', v_bad; end if;
end $$;
commit;