begin;
create temporary table _sports_stage_3 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _sports_stage_3 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|sports|3|' || v.text_en)::uuid, v.text_en, v.answer, v.answer_unit, v.difficulty, v.source
from (values
('How many meters is the official marathon distance?', 42195, 'meters', 1, 'World Athletics technical rules'),
('How many meters is one lap of a standard outdoor athletics track in lane one?', 400, 'meters', 1, 'World Athletics technical rules'),
('How many events make up a standard decathlon?', 10, 'events', 1, 'World Athletics combined events'),
('How many events make up a standard heptathlon?', 7, 'events', 1, 'World Athletics combined events'),
('How many hurdles are used in the men''s 110-meter hurdles race?', 10, 'hurdles', 2, 'World Athletics technical rules'),
('How many hurdles are used in the women''s 100-meter hurdles race?', 10, 'hurdles', 2, 'World Athletics technical rules'),
('How many hurdles are used in a 400-meter hurdles race?', 10, 'hurdles', 2, 'World Athletics technical rules'),
('How many barriers in total does an athlete clear in a 3000-meter steeplechase?', 35, 'barriers', 3, 'World Athletics technical rules'),
('How many water jumps are included in a 3000-meter steeplechase?', 7, 'water jumps', 3, 'World Athletics technical rules'),
('How many runners make up a standard 4-by-100-meter relay team?', 4, 'runners', 1, 'World Athletics relay rules'),
('How many grams does the senior men''s shot weigh in athletics?', 7260, 'grams', 3, 'World Athletics implement specifications'),
('How many grams does the senior women''s shot weigh in athletics?', 4000, 'grams', 2, 'World Athletics implement specifications'),
('How many grams does the senior men''s discus weigh in athletics?', 2000, 'grams', 2, 'World Athletics implement specifications'),
('How many grams does the senior women''s discus weigh in athletics?', 1000, 'grams', 2, 'World Athletics implement specifications'),
('How many grams does the senior men''s javelin weigh in athletics?', 800, 'grams', 2, 'World Athletics implement specifications'),
('How many meters long is a standard long-course competition swimming pool?', 50, 'meters', 1, 'World Aquatics swimming rules'),
('How many meters long is a standard short-course competition swimming pool?', 25, 'meters', 1, 'World Aquatics swimming rules'),
('How many major competitive swimming strokes are used in medley events?', 4, 'strokes', 1, 'World Aquatics swimming rules'),
('How many different strokes does one swimmer perform in an individual medley?', 4, 'strokes', 1, 'World Aquatics swimming rules'),
('How many swimmers make up a standard medley relay team?', 4, 'swimmers', 1, 'World Aquatics swimming rules'),
('How many meters in total does a 4-by-100-meter freestyle relay cover?', 400, 'meters', 1, 'World Aquatics swimming program'),
('How many meters in total does a 4-by-200-meter freestyle relay cover?', 800, 'meters', 1, 'World Aquatics swimming program'),
('How many meters is the longest standard pool freestyle race at major international championships?', 1500, 'meters', 2, 'World Aquatics swimming program'),
('How many lengths of a 50-meter pool make up a 50-meter race?', 1, 'lengths', 1, 'World Aquatics swimming rules'),
('How many lengths of a 50-meter pool make up a 200-meter race?', 4, 'lengths', 1, 'World Aquatics swimming rules'),
('In what year were the first modern Olympic Games held in Athens?', 1896, 'year', 1, 'IOC Olympic history'),
('In what year were the first Olympic Winter Games held in Chamonix?', 1924, 'year', 2, 'IOC Olympic history'),
('In what year did women first compete at the modern Olympic Games?', 1900, 'year', 2, 'IOC Olympic history'),
('How many interlocking rings are in the Olympic symbol?', 5, 'rings', 1, 'IOC Olympic symbol'),
('How many years normally separate editions of the Summer Olympic Games?', 4, 'years', 1, 'IOC Olympic history'),
('In what year were the first Summer Youth Olympic Games held?', 2010, 'year', 2, 'IOC Youth Olympic Games history'),
('In what year were the first Winter Youth Olympic Games held?', 2012, 'year', 2, 'IOC Youth Olympic Games history'),
('In what year were the first Summer Olympic Games held in Asia?', 1964, 'year', 2, 'IOC Olympic host history'),
('In what year were the first Olympic Winter Games held in Asia?', 1972, 'year', 3, 'IOC Olympic host history'),
('In what year were the first Olympic Games held in South America?', 2016, 'year', 2, 'IOC Olympic host history'),
('How many points does a player or pair normally need to win a badminton game, assuming the required margin?', 21, 'points', 1, 'BWF Laws of Badminton'),
('What is the maximum number of games in a standard best-of-three badminton match?', 3, 'games', 1, 'BWF Laws of Badminton'),
('At 29-all in badminton, how many points wins the game?', 30, 'points', 2, 'BWF Laws of Badminton'),
('How many centimeters long is a regulation badminton court?', 1340, 'centimeters', 2, 'BWF Laws of Badminton'),
('How many centimeters wide is a regulation badminton doubles court?', 610, 'centimeters', 2, 'BWF Laws of Badminton'),
('How many centimeters wide is a regulation badminton singles court?', 518, 'centimeters', 2, 'BWF Laws of Badminton'),
('How many millimeters high is the badminton net at the center of the court?', 1524, 'millimeters', 3, 'BWF Laws of Badminton'),
('How many points does a player normally need to win a table tennis game, assuming a two-point margin?', 11, 'points', 1, 'ITTF Laws of Table Tennis'),
('After how many points does service normally change in table tennis before 10-all?', 2, 'points', 2, 'ITTF Laws of Table Tennis'),
('How many centimeters long is a regulation table tennis table?', 274, 'centimeters', 2, 'ITTF equipment specifications'),
('How many millimeters wide is a regulation table tennis table?', 1525, 'millimeters', 2, 'ITTF equipment specifications'),
('How many centimeters high is a regulation table tennis table?', 76, 'centimeters', 2, 'ITTF equipment specifications'),
('How many tenths of a millimeter high is a regulation table tennis net?', 1525, 'tenths of a millimeter', 3, 'ITTF equipment specifications'),
('How many millimeters in diameter is a regulation table tennis ball?', 40, 'millimeters', 1, 'ITTF equipment specifications'),
('How many players take part in a doubles table tennis match in total?', 4, 'players', 1, 'ITTF Laws of Table Tennis')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _sports_stage_3;
  if v_rows<>50 or v_texts<>50 then raise exception 'Sports batch 3 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _sports_stage_3 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Sports batch 3 invalid content'; end if;
  select count(*) into v_ids from _sports_stage_3 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Sports batch 3 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _sports_stage_3 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Sports batch 3 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Sports',difficulty,source,'premium' from _sports_stage_3;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _sports_stage_3 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Sports batch 3 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _sports_stage_3 s on s.id=q.id
  where q.category<>'Sports' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Sports batch 3 post validation failed: %',v_bad; end if;
end $$;
commit;