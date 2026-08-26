begin;
create temporary table _general_stage_3 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _general_stage_3 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|general|3|' || v.text_en)::uuid,v.text_en,v.answer,v.answer_unit,v.difficulty,v.source
from (values
('How many prefectures does Japan have?',47,'prefectures',1,'Government of Japan'),
('How many federal states does Germany have?',16,'states',1,'Federal Republic of Germany'),
('How many regions does Italy have?',20,'regions',1,'Italian Republic'),
('How many autonomous communities does Spain have?',17,'communities',2,'Government of Spain'),
('How many cantons does Switzerland have?',26,'cantons',2,'Swiss Confederation'),
('How many federal states does Austria have?',9,'states',2,'Republic of Austria'),
('How many provinces does the Netherlands have?',12,'provinces',2,'Government of the Netherlands'),
('How many provinces does Belgium have?',10,'provinces',2,'Belgian government'),
('How many voivodeships does Poland have?',16,'voivodeships',2,'Government of Poland'),
('How many provinces does South Africa have?',9,'provinces',1,'Government of South Africa'),
('How many states does Nigeria have?',36,'states',2,'Federal Republic of Nigeria'),
('How many counties does Kenya have?',47,'counties',2,'Government of Kenya'),
('How many states does Mexico have, excluding Mexico City?',31,'states',2,'Government of Mexico'),
('How many provinces does Argentina have?',23,'provinces',2,'Government of Argentina'),
('How many states does Brazil have, excluding the Federal District?',26,'states',2,'Government of Brazil'),
('How many states does India have as of 2026?',28,'states',2,'Government of India'),
('How many union territories does India have as of 2026?',8,'territories',2,'Government of India'),
('How many counties does Sweden have?',21,'counties',2,'Government of Sweden'),
('How many governorates does Egypt have?',27,'governorates',2,'Government of Egypt'),
('How many administrative regions does Greece have?',13,'regions',2,'Hellenic Republic'),
('How many signs are in the Western zodiac?',12,'signs',1,'Western zodiac tradition'),
('How many animals are in the traditional Chinese zodiac cycle?',12,'animals',1,'Chinese zodiac tradition'),
('How many cards are in a standard tarot deck?',78,'cards',2,'standard tarot deck'),
('How many Major Arcana cards are in a standard tarot deck?',22,'cards',2,'standard tarot deck'),
('How many Minor Arcana cards are in a standard tarot deck?',56,'cards',2,'standard tarot deck'),
('How many balls are used in the standard American 75-ball bingo game?',75,'balls',2,'75-ball bingo rules'),
('How many balls are used in standard 90-ball bingo?',90,'balls',2,'90-ball bingo rules'),
('How many checkers are used in a standard backgammon set?',30,'checkers',2,'standard backgammon rules'),
('How many checkers does each player have in backgammon?',15,'checkers',2,'standard backgammon rules'),
('How many pieces are on the board at the start of standard checkers?',24,'pieces',2,'English draughts rules'),
('How many pieces does each player start with in standard checkers?',12,'pieces',2,'English draughts rules'),
('How many rows are in a standard Connect Four grid?',6,'rows',1,'Connect Four standard board'),
('How many columns are in a standard Connect Four grid?',7,'columns',1,'Connect Four standard board'),
('How many circular slots are in a standard Connect Four grid?',42,'slots',2,'Connect Four standard board'),
('How many squares are in a standard tic-tac-toe grid?',9,'squares',1,'standard tic-tac-toe rules'),
('How many pockets are on a single-zero European roulette wheel?',37,'pockets',2,'European roulette standard'),
('How many pockets are on a double-zero American roulette wheel?',38,'pockets',2,'American roulette standard'),
('How many object balls are on a snooker table at the start of a frame?',22,'balls',2,'World Professional Billiards and Snooker Association rules'),
('How many red balls are on a snooker table at the start of a frame?',15,'balls',2,'World Professional Billiards and Snooker Association rules'),
('How many balls are used in standard three-cushion carom billiards?',3,'balls',3,'Union Mondiale de Billard rules'),
('How many presidential faces are carved into Mount Rushmore?',4,'faces',1,'US National Park Service'),
('How many clock faces are on Elizabeth Tower, home of Big Ben?',4,'clock faces',2,'UK Parliament'),
('How many rays are on the crown of the Statue of Liberty?',7,'rays',2,'US National Park Service'),
('How many public visitor levels does the Eiffel Tower have?',3,'levels',1,'Eiffel Tower official site'),
('How many floors does the Empire State Building have?',102,'floors',2,'Empire State Building official facts'),
('How many columns surround the Lincoln Memorial?',36,'columns',2,'US National Park Service'),
('About how many meters tall is the Eiffel Tower including its current antenna?',330,'meters',2,'Eiffel Tower official site'),
('How many meters long is the main suspension span of the Golden Gate Bridge?',1280,'meters',3,'Golden Gate Bridge Highway and Transportation District'),
('About how many kilometers long is the Channel Tunnel from portal to portal?',50,'kilometers',3,'Getlink Channel Tunnel facts'),
('About how many kilometers long is the Suez Canal?',193,'kilometers',3,'Suez Canal Authority')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _general_stage_3;
  if v_rows<>50 or v_texts<>50 then raise exception 'General batch 3 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _general_stage_3 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'General batch 3 invalid content'; end if;
  select count(*) into v_ids from _general_stage_3 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'General batch 3 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _general_stage_3 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'General batch 3 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'General',difficulty,source,'premium' from _general_stage_3;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _general_stage_3 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'General batch 3 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _general_stage_3 s on s.id=q.id
  where q.category<>'General' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'General batch 3 post validation failed: %',v_bad; end if;
end $$;
commit;