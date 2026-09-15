with v(category,text_en,answer,answer_unit,difficulty,access_tier,source) as (
  values
  -- SPORTS: familiar event/object scale, not rulebook minutiae
  ('Sports','About how many tennis balls are supplied for Wimbledon each tournament?',54250,'tennis balls',4,'starter','Wimbledon / Slazenger'),
  ('Sports','The longest match in Wimbledon history lasted about how many minutes?',665,'minutes',4,'premium','Wimbledon'),
  ('Sports','About how many tennis balls are used during the US Open each year?',70000,'tennis balls',4,'premium','US Open'),
  ('Sports','The highest-scoring game in NBA history had how many combined points?',370,'points',3,'starter','NBA'),
  ('Sports','The longest game in Major League Baseball history lasted how many innings?',26,'innings',3,'premium','MLB'),
  ('Sports','The Stanley Cup weighs about how many pounds?',35,'pounds',3,'starter','NHL'),
  ('Sports','The Vince Lombardi Trophy weighs about how many pounds?',7,'pounds',2,'premium','NFL'),
  ('Sports','The FIFA World Cup Trophy weighs about how many pounds?',14,'pounds',3,'premium','FIFA'),
  ('Sports','The largest Super Bowl crowd ever was about how many people?',103985,'people',4,'starter','NFL'),
  ('Sports','The highest-scoring NFL game ever had how many combined points?',113,'points',3,'premium','NFL'),
  ('Sports','The longest field goal ever made in an NFL game was how many yards?',68,'yards',3,'starter','NFL'),
  ('Sports','How many Olympic medals did Michael Phelps win in his career?',28,'medals',2,'premium','World Aquatics'),
  ('Sports','How many Grand Slam singles titles did Serena Williams win?',23,'titles',2,'premium','WTA'),
  ('Sports','The record crowd at the Kentucky Derby was about how many people?',170513,'people',4,'premium','Kentucky Derby / Churchill Downs'),
  ('Sports','How many stages are in the 2026 Tour de France?',21,'stages',2,'premium','Tour de France'),
  ('Sports','How many matches are scheduled for the expanded 2026 FIFA World Cup?',104,'matches',3,'premium','FIFA'),

  -- MOVIES: production-scale / stunt / practical-effects questions
  ('Movies','About how many still cameras were used for The Matrix bullet-time sequence?',120,'cameras',3,'starter','Guinness World Records / American Society of Cinematographers'),
  ('Movies','About how many extras were used for Saving Private Ryan''s D-Day sequence?',750,'extras',3,'starter','Directors Guild of America'),
  ('Movies','How many takes did Tom Cruise do while hanging from the plane in Mission: Impossible – Rogue Nation?',8,'takes',2,'premium','Paramount Pictures'),
  ('Movies','How many dives to the real Titanic wreck did James Cameron and the crew make while producing Titanic?',12,'dives',2,'premium','Titanic production reporting'),
  ('Movies','Roughly how many people worked on the production of Titanic?',5000,'people',4,'premium','Titanic production reporting'),

  -- GENERAL: iconic-object scale
  ('General','About how many miles of steel wire are packed into the Golden Gate Bridge''s two main cables?',80000,'miles of wire',4,'starter','Golden Gate Bridge Highway and Transportation District'),
  ('General','About how many gallons of paint does it take to cover the outside of the White House?',570,'gallons of paint',3,'premium','The White House'),
  ('General','How many doors are in the White House?',412,'doors',3,'premium','The White House'),
  ('General','The Pentagon contains about how many million square feet of office space?',6500000,'square feet',4,'premium','U.S. Department of Defense')
)
insert into public.questions(text_en,text_tr,answer,answer_unit,category,difficulty,source,rating_sum,rating_count,access_tier,is_active)
select v.text_en, v.text_en, v.answer, v.answer_unit, v.category, v.difficulty, v.source, 0, 0, v.access_tier, true
from v
where not exists (
  select 1 from public.questions q where lower(trim(q.text_en)) = lower(trim(v.text_en))
);

update public.questions
set is_active=false
where category='Sports'
  and text_en='How many home runs did Barry Bonds hit in his entire MLB career?';