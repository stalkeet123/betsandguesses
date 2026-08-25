begin;
create temporary table _music_stage_3 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _music_stage_3 (id, text_en, answer, answer_unit, difficulty, source) values
('5f607a6e-2b9f-5d56-857b-6abebe4d5bc9'::uuid, 'In what year was Frank Ocean''s Blonde released?', 2016, 'year', 2, 'album reference'),
('edab0e8a-04ac-5cf6-a32f-da2ef9afe16b'::uuid, 'How many tracks are on Frank Ocean''s Blonde?', 17, 'items', 2, 'album track list'),
('98aa2a2d-968c-55e9-a1cc-32d17e729dd7'::uuid, 'In what year was Joni Mitchell''s Blue released?', 1971, 'year', 2, 'album reference'),
('f4d4532c-8754-5503-a1b1-f625624e03ca'::uuid, 'How many tracks are on Joni Mitchell''s Blue?', 10, 'items', 2, 'album track list'),
('2c68d0fc-8389-5d55-8f1d-e47215dde0cb'::uuid, 'In what year was Marvin Gaye''s What''s Going On released?', 1971, 'year', 2, 'album reference'),
('d273e134-8868-5c07-b93c-c004a85c357f'::uuid, 'How many tracks are on Marvin Gaye''s What''s Going On?', 9, 'items', 2, 'album track list'),
('9cf12910-e4a1-5905-ab95-9e0190aee8e9'::uuid, 'In what year was U2''s The Joshua Tree released?', 1987, 'year', 2, 'album reference'),
('01e82ca3-0911-58cd-a86c-183e02ae2f12'::uuid, 'How many tracks are on U2''s The Joshua Tree?', 11, 'items', 2, 'album track list'),
('4641905e-c4ed-5c0b-99c5-8d1f82b73138'::uuid, 'In what year was U2''s Achtung Baby released?', 1991, 'year', 2, 'album reference'),
('05ea9171-bee9-5fdc-84ed-e52b42714c02'::uuid, 'How many tracks are on U2''s Achtung Baby?', 12, 'items', 2, 'album track list'),
('75ffaca1-c4c5-5075-9e2d-3559a2af90b9'::uuid, 'In what year was Red Hot Chili Peppers'' Californication released?', 1999, 'year', 1, 'album reference'),
('a2b6895f-25d5-52d2-a46c-819e661b1798'::uuid, 'How many tracks are on Red Hot Chili Peppers'' Californication?', 15, 'items', 2, 'album track list'),
('f041eab8-d781-521a-a03c-32ec528294ed'::uuid, 'In what year was Linkin Park''s Hybrid Theory released?', 2000, 'year', 1, 'album reference'),
('a29dc9ad-0019-5dec-95d5-fdd443bc9222'::uuid, 'How many tracks are on the standard edition of Linkin Park''s Hybrid Theory?', 12, 'items', 2, 'album track list'),
('9979f4d3-a17c-55eb-83ee-5b2504005448'::uuid, 'In what year was Green Day''s American Idiot released?', 2004, 'year', 1, 'album reference'),
('32e66a21-b95e-572c-8fe9-62473cc94227'::uuid, 'How many tracks are on Green Day''s American Idiot?', 13, 'items', 2, 'album track list'),
('1f08a780-3d98-5c38-8114-4e115a63636e'::uuid, 'In what year was Arctic Monkeys'' AM released?', 2013, 'year', 2, 'album reference'),
('a1a6c720-5113-51e1-80f6-2731d97bc2dd'::uuid, 'How many tracks are on Arctic Monkeys'' AM?', 12, 'items', 2, 'album track list'),
('caaa85c6-0cf5-5a8d-9c5f-c8a21d148d4b'::uuid, 'In what year was Arctic Monkeys'' debut album Whatever People Say I Am, That''s What I''m Not released?', 2006, 'year', 2, 'album reference'),
('84b9abd3-16ee-58e9-baa9-a40c63e0b16c'::uuid, 'How many tracks are on Whatever People Say I Am, That''s What I''m Not?', 13, 'items', 2, 'album track list'),
('1bed863a-afc9-54a5-a877-cfa545790034'::uuid, 'How many studio albums did Queen release?', 15, 'items', 2, 'artist discography reference'),
('51afbb88-41f7-53e6-8553-e91336194662'::uuid, 'How many studio albums did Pink Floyd release?', 15, 'items', 2, 'artist discography reference'),
('0e771090-2599-5e7f-a99a-a745447cb821'::uuid, 'How many studio albums did Led Zeppelin release, including Coda?', 9, 'items', 2, 'artist discography reference'),
('16db004e-4e2f-513f-8282-33be0b568037'::uuid, 'How many studio albums did Nirvana release?', 3, 'items', 1, 'artist discography reference'),
('373173d4-51bf-5b15-a3b7-21a2eac63f84'::uuid, 'How many studio albums has Radiohead released through A Moon Shaped Pool?', 9, 'items', 2, 'artist discography reference'),
('234d2c5b-9208-5c04-abb0-8aafff33fc71'::uuid, 'How many studio albums has ABBA released through Voyage?', 9, 'items', 2, 'artist discography reference'),
('fb6fd434-ef66-5c22-b80a-b33603b5381b'::uuid, 'How many studio albums did Daft Punk release?', 4, 'items', 1, 'artist discography reference'),
('00f71dbf-4aba-585e-8dd9-79ceda9bc79e'::uuid, 'How many original members were in the Spice Girls?', 5, 'people', 1, 'artist history reference'),
('736a8b3f-8087-57fa-9f0f-792d782d38d6'::uuid, 'How many members were in One Direction when the group was formed?', 5, 'people', 1, 'artist history reference'),
('65224662-04a5-504c-82d2-7955387c6bdd'::uuid, 'How many members are in BTS?', 7, 'people', 1, 'artist reference'),
('852034e7-100a-5979-912c-64cb1bdccd8c'::uuid, 'How many members are in BLACKPINK?', 4, 'people', 1, 'artist reference'),
('971a87e4-8598-5d49-9dc1-7f8700a7c3b7'::uuid, 'How many founding members are associated with the classic Wu-Tang Clan lineup?', 9, 'people', 2, 'artist history reference'),
('1cf517c6-22c6-5623-b64e-7344b65445c6'::uuid, 'How many acts performed at the 1969 Woodstock festival?', 32, 'items', 3, 'festival history reference'),
('7bd140fb-cd8d-5912-bf1c-c348fa845f66'::uuid, 'Across how many calendar dates did the 1969 Woodstock performances run, from August 15 through August 18?', 4, 'days', 2, 'festival history reference'),
('66743016-0057-546e-9bc9-dcb9242f5b00'::uuid, 'About how many minutes did Queen''s famous Live Aid set at Wembley last?', 21, 'minutes', 2, 'concert history reference'),
('17202507-5753-59c5-ae6c-6fb0aa2e7eca'::uuid, 'About how many minutes did The Beatles'' 1969 rooftop concert last?', 42, 'minutes', 3, 'concert history reference'),
('7a686269-7d1d-5737-9b74-923655f10007'::uuid, 'In what year was the first Coachella Valley Music and Arts Festival held?', 1999, 'year', 2, 'festival history reference'),
('9dc89d36-0118-5d96-abee-f4b7bc57e9ac'::uuid, 'In what year was the first Glastonbury Festival held?', 1970, 'year', 2, 'festival history reference'),
('b04fa99d-705b-5754-8497-a304699dc6e7'::uuid, 'In what year did the original Lollapalooza touring festival begin?', 1991, 'year', 2, 'festival history reference'),
('e239bbcb-eeef-5a08-84ac-226e2970422d'::uuid, 'In what year was the first Bonnaroo Music and Arts Festival held?', 2002, 'year', 2, 'festival history reference'),
('6c1746d1-7bba-5c27-875f-09a1c3237e9e'::uuid, 'In what year was the first Eurovision Song Contest held?', 1956, 'year', 1, 'music competition reference'),
('1654aedf-6296-569c-9dc0-6df9070af14c'::uuid, 'How many countries competed in the first Eurovision Song Contest in 1956?', 7, 'items', 2, 'music competition reference'),
('e189245f-21c3-53d1-89fb-c06a2ca2e57c'::uuid, 'In what year were the first Grammy Awards presented?', 1959, 'year', 1, 'awards history reference'),
('88a3d408-3677-575d-8c3e-369f090346a2'::uuid, 'How many award categories were presented at the first Grammy Awards?', 28, 'items', 3, 'awards history reference'),
('74e382c6-56c9-5f15-900c-e4f79607659e'::uuid, 'In what year did MTV begin broadcasting?', 1981, 'year', 1, 'music media reference'),
('8147bf3a-ee1e-5483-ac12-bd9c508d1db1'::uuid, 'In what year was the Billboard Hot 100 first published?', 1958, 'year', 2, 'chart history reference'),
('41e25682-9211-5e51-93a1-b812282de756'::uuid, 'What sampling rate in hertz is used by standard audio CDs?', 44100, 'hertz', 3, 'digital audio specification'),
('3a569232-9780-5da2-97bf-f085ee273321'::uuid, 'How many bits per sample are used by standard audio CDs?', 16, 'bits', 2, 'digital audio specification'),
('3f277605-e04c-501b-841c-921855058f46'::uuid, 'About how many minutes of audio was the original standard compact disc designed to hold?', 74, 'minutes', 3, 'digital audio specification'),
('492e029a-da07-5942-a8d8-d712edde5aea'::uuid, 'What is the highest common MP3 bitrate in kilobits per second?', 320, 'kilobits per second', 2, 'digital audio reference');

do $$
declare v_rows int; v_texts int; v_collisions int; v_id_collisions int;
begin
  select count(*), count(distinct lower(btrim(text_en))) into v_rows, v_texts from _music_stage_3;
  if v_rows <> 50 or v_texts <> 50 then raise exception 'Music batch staging invalid: rows %, unique texts %', v_rows, v_texts; end if;
  if exists (select 1 from _music_stage_3 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Music batch contains invalid content'; end if;
  select count(*) into v_id_collisions from _music_stage_3 s join public.questions q on q.id=s.id;
  if v_id_collisions<>0 then raise exception 'Music UUID collisions: %', v_id_collisions; end if;
  select count(*) into v_collisions from _music_stage_3 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Music wording collisions: %', v_collisions; end if;
end $$;

insert into public.questions (id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Music',difficulty,source,'premium' from _music_stage_3;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _music_stage_3 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Music batch inserted % rows', v_inserted; end if;
  select count(*) into v_bad from public.questions q join _music_stage_3 s on s.id=q.id where q.category<>'Music' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Music batch post validation failed: %', v_bad; end if;
end $$;
commit;