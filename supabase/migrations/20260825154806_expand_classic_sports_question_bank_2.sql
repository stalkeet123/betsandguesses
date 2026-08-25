begin;
create temporary table _sports_stage_2 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _sports_stage_2 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|sports|2|' || v.text_en)::uuid, v.text_en, v.answer, v.answer_unit, v.difficulty, v.source
from (values
('How many players from one team are on the field for a standard NFL play?', 11, 'players', 1, 'NFL official rules'),
('How many regulation quarters are played in an NFL game?', 4, 'quarters', 1, 'NFL official rules'),
('How many minutes are in one regulation NFL quarter?', 15, 'minutes', 1, 'NFL official rules'),
('How many yards must an NFL offense normally gain for a new first down?', 10, 'yards', 1, 'NFL official rules'),
('How many downs does an NFL offense normally have to gain a first down?', 4, 'downs', 1, 'NFL official rules'),
('How many yards long is an NFL field between the two goal lines?', 100, 'yards', 1, 'NFL field specifications'),
('How many yards deep is each NFL end zone?', 10, 'yards', 1, 'NFL field specifications'),
('How many yards long is the entire NFL field including both end zones?', 120, 'yards', 2, 'NFL field specifications'),
('How many points is an NFL touchdown worth?', 6, 'points', 1, 'NFL official rules'),
('How many points is a successful NFL field goal worth?', 3, 'points', 1, 'NFL official rules'),
('What is the maximum number of players from one team normally on the ice at once in IIHF hockey, including the goalkeeper?', 6, 'players', 1, 'IIHF Official Rule Book'),
('How many regulation periods are played in an IIHF ice hockey game?', 3, 'periods', 1, 'IIHF Official Rule Book'),
('How many minutes are in one regulation IIHF ice hockey period?', 20, 'minutes', 1, 'IIHF Official Rule Book'),
('How many meters long is the official IIHF ice hockey rink?', 60, 'meters', 2, 'IIHF Official Rule Book'),
('What is the ideal height of IIHF rink boards in centimeters?', 107, 'centimeters', 3, 'IIHF Official Rule Book'),
('How many inches in diameter is a regulation ice hockey puck?', 3, 'inches', 2, 'IIHF puck specifications'),
('How many inches thick is a regulation ice hockey puck?', 1, 'inches', 2, 'IIHF puck specifications'),
('About how many centimeters wide is a regulation ice hockey goal?', 183, 'centimeters', 2, 'IIHF goal specifications'),
('About how many centimeters high is a regulation ice hockey goal?', 122, 'centimeters', 2, 'IIHF goal specifications'),
('How many minutes is a standard minor penalty in ice hockey?', 2, 'minutes', 1, 'IIHF Official Rule Book'),
('How many players does each team start with in rugby union?', 15, 'players', 1, 'World Rugby Laws'),
('How many minutes is a standard rugby union match before added time?', 80, 'minutes', 1, 'World Rugby Laws'),
('How many minutes are in one standard half of rugby union?', 40, 'minutes', 1, 'World Rugby Laws'),
('What is the maximum half-time interval in minutes in rugby union?', 15, 'minutes', 2, 'World Rugby Laws'),
('What is the maximum field-of-play length in meters under World Rugby laws?', 100, 'meters', 2, 'World Rugby Laws'),
('What is the maximum rugby union field width in meters under World Rugby laws?', 70, 'meters', 2, 'World Rugby Laws'),
('What is the maximum in-goal length in meters under World Rugby laws?', 22, 'meters', 3, 'World Rugby Laws'),
('How many points is a try worth in rugby union?', 5, 'points', 1, 'World Rugby Laws'),
('How many points is a successful conversion worth in rugby union?', 2, 'points', 1, 'World Rugby Laws'),
('How many points is a successful penalty goal worth in rugby union?', 3, 'points', 1, 'World Rugby Laws'),
('How many players are in a cricket team on the fielding side?', 11, 'players', 1, 'ICC playing conditions'),
('How many yards long is a regulation cricket pitch?', 22, 'yards', 1, 'ICC playing conditions'),
('How many feet wide is the prepared cricket pitch area specified by ICC playing conditions?', 10, 'feet', 2, 'ICC playing conditions'),
('How many wickets are positioned on a cricket pitch?', 2, 'wickets', 1, 'Laws of Cricket'),
('How many stumps make up one cricket wicket?', 3, 'stumps', 1, 'Laws of Cricket'),
('How many bails sit on top of one complete cricket wicket?', 2, 'bails', 1, 'Laws of Cricket'),
('How many legal balls make up a standard over in international cricket?', 6, 'balls', 1, 'ICC playing conditions'),
('How many overs per side are scheduled in a standard One Day International innings?', 50, 'overs', 1, 'ICC ODI playing conditions'),
('How many overs per side are scheduled in a standard T20 International innings?', 20, 'overs', 1, 'ICC T20I playing conditions'),
('How many days are scheduled for a standard men''s Test match?', 5, 'days', 2, 'ICC Test match playing conditions'),
('How many holes are in a standard full round of golf?', 18, 'holes', 1, 'Rules of Golf'),
('What is the maximum number of clubs a golfer may normally carry during a round?', 14, 'clubs', 1, 'Rules of Golf'),
('How many hundredths of an inch is the minimum legal golf ball diameter?', 168, 'hundredths of an inch', 3, 'USGA equipment rules'),
('How many hundredths of an ounce is the maximum legal golf ball weight?', 162, 'hundredths of an ounce', 3, 'USGA equipment rules'),
('How many hundredths of an inch wide is a regulation golf hole?', 425, 'hundredths of an inch', 3, 'Rules of Golf equipment specifications'),
('How many club-lengths deep is the teeing area under the Rules of Golf?', 2, 'club-lengths', 2, 'Rules of Golf'),
('How many men''s major championships are traditionally recognized in professional golf?', 4, 'championships', 1, 'professional golf major structure'),
('How many penalty strokes are normally added for a lost ball under stroke-and-distance relief?', 1, 'strokes', 2, 'Rules of Golf'),
('How many penalty strokes are normally added when taking unplayable-ball relief?', 1, 'strokes', 2, 'Rules of Golf'),
('How many strokes is the general penalty in stroke play under the Rules of Golf?', 2, 'strokes', 2, 'Rules of Golf')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _sports_stage_2;
  if v_rows<>50 or v_texts<>50 then raise exception 'Sports batch 2 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _sports_stage_2 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Sports batch 2 invalid content'; end if;
  select count(*) into v_ids from _sports_stage_2 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Sports batch 2 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _sports_stage_2 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Sports batch 2 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Sports',difficulty,source,'premium' from _sports_stage_2;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _sports_stage_2 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Sports batch 2 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _sports_stage_2 s on s.id=q.id
  where q.category<>'Sports' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Sports batch 2 post validation failed: %',v_bad; end if;
end $$;
commit;