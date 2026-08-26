begin;
create temporary table _science_stage_1 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _science_stage_1 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|science|1|' || v.text_en)::uuid, v.text_en, v.answer, v.answer_unit, v.difficulty, v.source
from (values
('How many planets are in our solar system?', 8, 'planets', 1, 'NASA Solar System Facts'),
('How many officially recognized dwarf planets are in our solar system?', 5, 'dwarf planets', 2, 'NASA Solar System Facts'),
('How many terrestrial planets are in our solar system?', 4, 'planets', 2, 'NASA Solar System Facts'),
('How many gas giant planets are in our solar system?', 2, 'planets', 2, 'NASA Solar System Facts'),
('How many ice giant planets are in our solar system?', 2, 'planets', 2, 'NASA Solar System Facts'),
('About how many kilometers across is the Sun?', 1400000, 'kilometers', 2, 'NASA Sun Facts'),
('About how many Earth days does the Sun take to rotate once at its equator?', 25, 'days', 3, 'NASA Sun Facts'),
('About how many Earth days does the Sun take to rotate once near its poles?', 36, 'days', 3, 'NASA Sun Facts'),
('About how many million years does the solar system take to orbit the center of the Milky Way?', 230, 'million years', 3, 'NASA Solar System Facts'),
('About how many kilometers per hour does the solar system travel around the Milky Way?', 828000, 'km/h', 4, 'NASA Solar System Facts'),
('About how many kilometers is Mercury''s radius?', 2440, 'kilometers', 2, 'NASA Solar System Sizes'),
('About how many kilometers is Venus''s radius?', 6052, 'kilometers', 2, 'NASA Solar System Sizes'),
('About how many kilometers is Earth''s mean radius?', 6371, 'kilometers', 2, 'NASA Solar System Sizes'),
('About how many kilometers is Mars''s radius?', 3390, 'kilometers', 2, 'NASA Solar System Sizes'),
('About how many kilometers is Jupiter''s radius?', 69911, 'kilometers', 3, 'NASA Solar System Sizes'),
('About how many kilometers is Saturn''s radius?', 58232, 'kilometers', 3, 'NASA Solar System Sizes'),
('About how many kilometers is Uranus''s radius?', 25362, 'kilometers', 3, 'NASA Solar System Sizes'),
('About how many kilometers is Neptune''s radius?', 24622, 'kilometers', 3, 'NASA Solar System Sizes'),
('About how many kilometers is Jupiter''s equatorial diameter?', 142984, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers is Saturn''s diameter?', 120536, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers is Uranus''s diameter?', 51118, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers is Neptune''s diameter?', 49528, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many million kilometers is Jupiter from the Sun on average?', 778, 'million kilometers', 2, 'NASA Voyager Fact Sheet'),
('About how many million kilometers is Saturn from the Sun on average?', 1400, 'million kilometers', 2, 'NASA Voyager Fact Sheet'),
('About how many million kilometers is Uranus from the Sun on average?', 3000, 'million kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many million kilometers is Neptune from the Sun on average?', 4500, 'million kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Jupiter''s moon Io?', 3630, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Jupiter''s moon Europa?', 3138, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Jupiter''s moon Ganymede?', 5262, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Jupiter''s moon Callisto?', 4800, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Saturn''s moon Mimas?', 392, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Saturn''s moon Enceladus?', 520, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Saturn''s moon Tethys?', 1060, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Saturn''s moon Dione?', 1120, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Saturn''s moon Rhea?', 1530, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Saturn''s moon Titan?', 5150, 'kilometers', 2, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Saturn''s moon Iapetus?', 1460, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Uranus''s moon Miranda?', 472, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Uranus''s moon Ariel?', 1158, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Uranus''s moon Umbriel?', 1172, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Uranus''s moon Titania?', 1580, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Uranus''s moon Oberon?', 1524, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Neptune''s moon Triton?', 2700, 'kilometers', 3, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Neptune''s moon Proteus?', 400, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many kilometers wide is Neptune''s moon Nereid?', 340, 'kilometers', 4, 'NASA Voyager Fact Sheet'),
('About how many seconds does sunlight take to reach Earth?', 500, 'seconds', 2, 'NASA Basics of Space Flight'),
('How many natural satellites does Mars have?', 2, 'moons', 1, 'NASA Basics of Space Flight'),
('How many natural satellites does Earth have?', 1, 'moon', 1, 'NASA Basics of Space Flight'),
('How many laws of planetary motion did Johannes Kepler formulate?', 3, 'laws', 2, 'NASA Orbits and Kepler''s Laws'),
('How many Voyager spacecraft are currently heading out of the solar system?', 2, 'spacecraft', 2, 'NASA Solar System Facts')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _science_stage_1;
  if v_rows<>50 or v_texts<>50 then raise exception 'Science batch 1 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _science_stage_1 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Science batch 1 invalid content'; end if;
  select count(*) into v_ids from _science_stage_1 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Science batch 1 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _science_stage_1 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Science batch 1 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Science',difficulty,source,'premium' from _science_stage_1;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _science_stage_1 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Science batch 1 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _science_stage_1 s on s.id=q.id
  where q.category<>'Science' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Science batch 1 post validation failed: %',v_bad; end if;
end $$;
commit;