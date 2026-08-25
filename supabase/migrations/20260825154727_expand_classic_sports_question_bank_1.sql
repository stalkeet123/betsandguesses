begin;
create temporary table _sports_stage_1 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _sports_stage_1 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|sports|1|' || v.text_en)::uuid, v.text_en, v.answer, v.answer_unit, v.difficulty, v.source
from (values
('How many players does each team start with on the field in association football?', 11, 'players', 1, 'IFAB Laws of the Game'),
('How many minutes are in a standard association football match before added time and extra time?', 90, 'minutes', 1, 'IFAB Laws of the Game'),
('How many minutes are in one standard half of association football?', 45, 'minutes', 1, 'IFAB Laws of the Game'),
('What is the maximum half-time interval in minutes under the IFAB Laws of the Game?', 15, 'minutes', 2, 'IFAB Laws of the Game'),
('How many meters from the goal line is the penalty mark in association football?', 11, 'meters', 1, 'IFAB Laws of the Game'),
('How many centimeters wide is a regulation association football goal between the posts?', 732, 'centimeters', 2, 'IFAB Laws of the Game'),
('How many centimeters high is a regulation association football goal from ground to crossbar?', 244, 'centimeters', 2, 'IFAB Laws of the Game'),
('What is the minimum corner flagpost height in centimeters in association football?', 150, 'centimeters', 2, 'IFAB Laws of the Game'),
('How many centimeters from each goalpost does the goal area extend in association football?', 550, 'centimeters', 3, 'IFAB Laws of the Game'),
('How many centimeters from each goalpost does the penalty area extend in association football?', 1650, 'centimeters', 3, 'IFAB Laws of the Game'),
('How many players from one team are on the court at a time in NBA basketball?', 5, 'players', 1, 'NBA official rules'),
('How many regulation quarters are played in an NBA game?', 4, 'quarters', 1, 'NBA official rules'),
('How many minutes are in one regulation NBA quarter?', 12, 'minutes', 1, 'NBA official rules'),
('How many seconds are on the standard NBA shot clock at the start of a possession?', 24, 'seconds', 1, 'NBA official rules'),
('To how many seconds can the NBA shot clock reset after an offensive rebound that hits the rim?', 14, 'seconds', 2, 'NBA official rules'),
('How many seconds does an NBA team normally have to advance the ball from the backcourt?', 8, 'seconds', 2, 'NBA official rules'),
('How many personal fouls cause a player to be disqualified from an NBA game?', 6, 'fouls', 2, 'NBA official rules'),
('How many feet above the floor is the rim of an NBA basket?', 10, 'feet', 1, 'NBA court specifications'),
('How many points is a successful NBA free throw worth?', 1, 'points', 1, 'NBA official rules'),
('How many points is a field goal from inside the three-point line worth in NBA basketball?', 2, 'points', 1, 'NBA official rules'),
('How many feet long is a regulation tennis court?', 78, 'feet', 2, 'ITF Rules of Tennis'),
('How many feet wide is a regulation singles tennis court?', 27, 'feet', 2, 'ITF Rules of Tennis'),
('How many feet wide is a regulation doubles tennis court?', 36, 'feet', 2, 'ITF Rules of Tennis'),
('How many inches high is the tennis net at the center?', 36, 'inches', 2, 'ITF Rules of Tennis'),
('How many inches high is a regulation tennis net at the posts?', 42, 'inches', 3, 'ITF Rules of Tennis'),
('What is the minimum number of points a player must win to take a standard tennis game?', 4, 'points', 1, 'ITF Rules of Tennis'),
('How many games must a player normally win to take a standard tennis set, assuming the required margin?', 6, 'games', 1, 'ITF Rules of Tennis'),
('How many points must a player normally reach first to win a standard tie-break, assuming a two-point margin?', 7, 'points', 2, 'ITF Rules of Tennis'),
('How many Grand Slam tennis tournaments are played each year?', 4, 'tournaments', 1, 'Grand Slam tournament structure'),
('How many serve attempts does a player normally have to put the ball in play on a tennis point?', 2, 'attempts', 1, 'ITF Rules of Tennis'),
('How many players from one team are on the court in indoor volleyball?', 6, 'players', 1, 'FIVB Official Volleyball Rules'),
('How many meters long is a regulation indoor volleyball court?', 18, 'meters', 1, 'FIVB Official Volleyball Rules'),
('How many meters wide is a regulation indoor volleyball court?', 9, 'meters', 1, 'FIVB Official Volleyball Rules'),
('How many meters from the center line is the attack line in indoor volleyball?', 3, 'meters', 2, 'FIVB Official Volleyball Rules'),
('What is the maximum number of sets in a standard best-of-five indoor volleyball match?', 5, 'sets', 1, 'FIVB Official Volleyball Rules'),
('How many points are normally needed to win each of the first four volleyball sets, assuming a two-point margin?', 25, 'points', 1, 'FIVB Official Volleyball Rules'),
('How many points are normally needed to win the deciding fifth volleyball set, assuming a two-point margin?', 15, 'points', 1, 'FIVB Official Volleyball Rules'),
('How many team contacts are normally allowed before the ball must be sent over the net in volleyball?', 3, 'contacts', 1, 'FIVB Official Volleyball Rules'),
('How many centimeters high is the men''s indoor volleyball net?', 243, 'centimeters', 2, 'FIVB Official Volleyball Rules'),
('How many centimeters high is the women''s indoor volleyball net?', 224, 'centimeters', 2, 'FIVB Official Volleyball Rules'),
('How many defensive players does a baseball team field at one time?', 9, 'players', 1, 'Official Baseball Rules'),
('How many innings are scheduled in a regulation Major League Baseball game?', 9, 'innings', 1, 'Official Baseball Rules'),
('How many outs end one half-inning in baseball?', 3, 'outs', 1, 'Official Baseball Rules'),
('How many balls normally award a batter first base on a walk?', 4, 'balls', 1, 'Official Baseball Rules'),
('How many strikes normally retire a batter on a strikeout?', 3, 'strikes', 1, 'Official Baseball Rules'),
('How many feet apart are consecutive bases on a regulation Major League Baseball diamond?', 90, 'feet', 2, 'Official Baseball Rules'),
('How many inches is the regulation distance from the pitcher''s plate to the rear point of home plate?', 726, 'inches', 3, 'Official Baseball Rules'),
('How many bases, including home plate, must a runner touch to score a run in baseball?', 4, 'bases', 1, 'Official Baseball Rules'),
('How many outs does one team record over nine complete defensive innings with no extra innings?', 27, 'outs', 2, 'Official Baseball Rules'),
('How many foul lines extend from home plate through first and third base on a baseball field?', 2, 'lines', 1, 'Official Baseball Rules')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _sports_stage_1;
  if v_rows<>50 or v_texts<>50 then raise exception 'Sports batch 1 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _sports_stage_1 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Sports batch 1 invalid content'; end if;
  select count(*) into v_ids from _sports_stage_1 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Sports batch 1 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _sports_stage_1 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Sports batch 1 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Sports',difficulty,source,'premium' from _sports_stage_1;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _sports_stage_1 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Sports batch 1 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _sports_stage_1 s on s.id=q.id
  where q.category<>'Sports' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Sports batch 1 post validation failed: %',v_bad; end if;
end $$;
commit;