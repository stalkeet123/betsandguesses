begin;
create temporary table _music_stage_1 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _music_stage_1 (id, text_en, answer, answer_unit, difficulty, source) values
('f63595d5-a2b7-57a5-aa82-20f7a8cd1c31'::uuid, 'How many strings does a standard guitar have?', 6, 'items', 1, 'instrument reference'),
('f284f61a-54c0-58fd-842d-ef36729f3f69'::uuid, 'How many strings does a standard four-string electric bass have?', 4, 'items', 1, 'instrument reference'),
('608df39d-b93c-521e-8e4e-a8351f6a897e'::uuid, 'How many strings does a standard violin have?', 4, 'items', 1, 'instrument reference'),
('cffde1d1-bfda-54d0-8de6-182e6db4068c'::uuid, 'How many strings does a standard viola have?', 4, 'items', 1, 'instrument reference'),
('6113531b-c84c-567f-8aa8-6f66f43977fe'::uuid, 'How many strings does a standard cello have?', 4, 'items', 1, 'instrument reference'),
('e3867476-10c4-5284-86f1-1595a2e3b553'::uuid, 'How many strings does a standard orchestral double bass usually have?', 4, 'items', 2, 'instrument reference'),
('70599fe5-0925-5f56-ac61-c24141961d8c'::uuid, 'About how many strings does a modern concert pedal harp have?', 47, 'items', 3, 'instrument reference'),
('8718258c-1867-5329-8f8a-34591d26bb06'::uuid, 'How many strings does a standard ukulele have?', 4, 'items', 1, 'instrument reference'),
('fb1e8aef-92ae-55fb-9a21-f02c4195a494'::uuid, 'How many strings does a common five-string banjo have?', 5, 'items', 1, 'instrument reference'),
('b4e7613d-e163-569c-a98e-25076371c2da'::uuid, 'How many strings does a standard mandolin have?', 8, 'items', 2, 'instrument reference'),
('14217c95-95de-5c5a-9229-f6947dd32937'::uuid, 'How many valves does a standard trumpet have?', 3, 'items', 1, 'instrument reference'),
('8e192975-c823-56e0-bd4c-d3c9211ee5ce'::uuid, 'How many slide positions does a standard tenor trombone have?', 7, 'items', 2, 'instrument reference'),
('d55a3bdc-9994-5e65-baad-dff94c1856ed'::uuid, 'How many valves does a standard modern double French horn have?', 4, 'items', 2, 'instrument reference'),
('fc3004c2-f2dd-5cf4-9669-4ed71b7eef3e'::uuid, 'How many finger holes does a standard recorder have when the thumb hole is included?', 8, 'items', 2, 'instrument reference'),
('ce6d57d9-c785-56dd-b96a-f1aa8d7960ee'::uuid, 'How many holes does a standard diatonic harmonica usually have?', 10, 'items', 2, 'instrument reference'),
('7eb94388-3f1b-5f59-b18e-bbd8cd9961c5'::uuid, 'How many pedals does a modern concert harp have?', 7, 'items', 2, 'instrument reference'),
('32372e96-7dc3-5ddc-9fde-549e3a23b1e0'::uuid, 'How many timpani are commonly used in a standard orchestral set?', 4, 'items', 2, 'orchestration reference'),
('1f3df164-769e-5c24-a041-d84cf64755af'::uuid, 'How many horizontal lines are on a standard musical staff?', 5, 'items', 1, 'music theory reference'),
('9f735283-a3f3-5428-887f-ccfcb33c8c62'::uuid, 'How many spaces are between the lines of a standard musical staff?', 4, 'items', 1, 'music theory reference'),
('7e95814c-36b3-506b-98dc-fb3e163125f7'::uuid, 'How many semitones are in one octave in Western equal temperament?', 12, 'items', 1, 'music theory reference'),
('5b0b2f20-6301-5fbb-a4c3-35e7c0e7d665'::uuid, 'How many different note names are in a major scale before the octave repeats?', 7, 'items', 1, 'music theory reference'),
('cf45b90f-0aac-5db7-b3f3-f31d460f67ee'::uuid, 'How many pitch classes are in the chromatic scale?', 12, 'items', 2, 'music theory reference'),
('19b6168b-405f-5a8a-93ec-a6e728fd75b7'::uuid, 'What frequency in hertz is the standard concert pitch A above middle C?', 440, 'hertz', 2, 'music theory reference'),
('4b4e4292-fd7d-5fa3-8f4b-1e3e2a922039'::uuid, 'How many channels can a standard MIDI connection address independently?', 16, 'items', 2, 'MIDI specification'),
('ec1eeb9b-8386-5bf3-9e95-597ff95010de'::uuid, 'How many possible MIDI note numbers are there from 0 through 127?', 128, 'items', 3, 'MIDI specification'),
('57902ac7-207c-5e10-b69e-fe8951147b61'::uuid, 'How many musicians are in a standard string quartet?', 4, 'people', 1, 'ensemble reference'),
('8ea1bc18-430e-57a6-b803-5c5d0db30f79'::uuid, 'How many musicians are in a standard piano trio?', 3, 'people', 1, 'ensemble reference'),
('bd9eea99-e2be-5f9c-96dd-d10fd3ef1077'::uuid, 'How many musicians are in a standard brass quintet?', 5, 'people', 1, 'ensemble reference'),
('690b4c9e-00f8-50af-a6f7-00fc02ef113a'::uuid, 'How many musicians are in a standard woodwind quintet?', 5, 'people', 1, 'ensemble reference'),
('66728014-3a1e-5a12-b513-a210017093c0'::uuid, 'How many concertos make up Vivaldi''s The Four Seasons?', 4, 'items', 1, 'classical music reference'),
('8d3bb662-ae4a-5d36-9c87-c3a8021d7cf7'::uuid, 'How many numbered symphonies did Beethoven compose?', 9, 'items', 1, 'classical music reference'),
('f35daecc-1647-588e-83d4-961027fed9cc'::uuid, 'How many piano concertos did Beethoven compose?', 5, 'items', 2, 'classical music reference'),
('558d461c-42d5-570c-b56c-64de48b90f9a'::uuid, 'How many numbered piano sonatas did Beethoven compose?', 32, 'items', 3, 'classical music reference'),
('de1f5ba2-c444-5992-ae65-036f62f65531'::uuid, 'How many string quartets did Beethoven compose?', 16, 'items', 3, 'classical music reference'),
('38153663-60d3-5d27-99a6-2cd87dcc19fb'::uuid, 'How many numbered symphonies are traditionally attributed to Joseph Haydn?', 104, 'items', 3, 'classical music reference'),
('cb50df1d-40e3-5d47-9163-d5a6a4069102'::uuid, 'How many numbered symphonies did Tchaikovsky compose?', 6, 'items', 2, 'classical music reference'),
('90a8f7c5-6efa-5ef2-97fb-bc0a02cd321e'::uuid, 'How many piano concertos did Rachmaninoff compose?', 4, 'items', 2, 'classical music reference'),
('1505afc4-dc09-5d45-8ce9-a8042a678ecf'::uuid, 'How many piano concertos did Chopin compose?', 2, 'items', 1, 'classical music reference'),
('07d4f01f-2a3c-58d6-b3a8-b6f39c1fa384'::uuid, 'How many Brandenburg Concertos did Bach compose?', 6, 'items', 2, 'classical music reference'),
('f79bc7d9-6e6f-5a9a-b305-626f71645598'::uuid, 'How many Goldberg Variations follow the opening aria in Bach''s Goldberg Variations?', 30, 'items', 3, 'classical music reference'),
('9b90975e-d807-5ef6-9642-a037964997eb'::uuid, 'How many movements are in Holst''s orchestral suite The Planets?', 7, 'items', 2, 'classical music reference'),
('fe7892b3-e203-5971-9a7d-000597fe30f9'::uuid, 'How many movements are in Saint-Saens''s Carnival of the Animals?', 14, 'items', 3, 'classical music reference'),
('249aed8b-d13d-5d77-bc76-d9852722955e'::uuid, 'How many operas make up Wagner''s Ring cycle?', 4, 'items', 2, 'classical music reference'),
('a04d104e-7bbc-5f9b-b2e9-edde78b55549'::uuid, 'In what year was the MIDI 1.0 specification first publicly demonstrated?', 1983, 'year', 3, 'music technology reference'),
('6144de40-f3a8-53ff-ad8a-03b491c3d246'::uuid, 'In what year was the Fender Stratocaster introduced?', 1954, 'year', 2, 'instrument history reference'),
('eb5cb555-6f17-53d9-909f-583518013ac9'::uuid, 'In what year was the Gibson Les Paul model introduced?', 1952, 'year', 2, 'instrument history reference'),
('2d79e943-07e4-5307-9b20-d187189771ea'::uuid, 'In what year was the Roland TR-808 drum machine introduced?', 1980, 'year', 3, 'music technology reference'),
('c86bb80f-5691-5bb1-8042-8a0e01c9a9d2'::uuid, 'In what year did Robert Moog unveil his first modular synthesizer system?', 1964, 'year', 3, 'music technology reference'),
('f448292a-9b5e-5b67-913b-0a82073f6e1a'::uuid, 'In what year was Auto-Tune first released commercially?', 1997, 'year', 3, 'music technology reference'),
('c7ecea5e-bfe0-58df-a841-4fe7215da809'::uuid, 'In what year did Sony introduce the original Walkman?', 1979, 'year', 2, 'music technology reference');

do $$
declare v_rows int; v_texts int; v_collisions int; v_id_collisions int;
begin
  select count(*), count(distinct lower(btrim(text_en))) into v_rows, v_texts from _music_stage_1;
  if v_rows <> 50 or v_texts <> 50 then raise exception 'Music batch staging invalid: rows %, unique texts %', v_rows, v_texts; end if;
  if exists (select 1 from _music_stage_1 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Music batch contains invalid content'; end if;
  select count(*) into v_id_collisions from _music_stage_1 s join public.questions q on q.id=s.id;
  if v_id_collisions<>0 then raise exception 'Music UUID collisions: %', v_id_collisions; end if;
  select count(*) into v_collisions from _music_stage_1 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Music wording collisions: %', v_collisions; end if;
end $$;

insert into public.questions (id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Music',difficulty,source,'premium' from _music_stage_1;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _music_stage_1 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Music batch inserted % rows', v_inserted; end if;
  select count(*) into v_bad from public.questions q join _music_stage_1 s on s.id=q.id where q.category<>'Music' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Music batch post validation failed: %', v_bad; end if;
end $$;
commit;