begin;
create temporary table _general_stage_2 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _general_stage_2 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|general|2|' || v.text_en)::uuid,v.text_en,v.answer,v.answer_unit,v.difficulty,v.source
from (values
('How many cards are in a standard deck without jokers?',52,'cards',1,'standard playing card deck'),
('How many suits are in a standard deck of playing cards?',4,'suits',1,'standard playing card deck'),
('How many cards are in each suit of a standard deck?',13,'cards',1,'standard playing card deck'),
('How many red cards are in a standard deck?',26,'cards',1,'standard playing card deck'),
('How many black cards are in a standard deck?',26,'cards',1,'standard playing card deck'),
('How many face cards are in a standard deck?',12,'cards',2,'standard playing card deck'),
('How many aces are in a standard deck?',4,'cards',1,'standard playing card deck'),
('How many squares are on a standard chessboard?',64,'squares',1,'FIDE Laws of Chess'),
('How many pieces are on a chessboard at the start of a game?',32,'pieces',1,'FIDE Laws of Chess'),
('How many chess pieces does each player start with?',16,'pieces',1,'FIDE Laws of Chess'),
('How many pawns does each player start with in chess?',8,'pawns',1,'FIDE Laws of Chess'),
('How many rooks are on the board at the start of a chess game?',4,'rooks',2,'FIDE Laws of Chess'),
('How many knights are on the board at the start of a chess game?',4,'knights',2,'FIDE Laws of Chess'),
('How many bishops are on the board at the start of a chess game?',4,'bishops',2,'FIDE Laws of Chess'),
('How many queens are on the board at the start of a chess game?',2,'queens',1,'FIDE Laws of Chess'),
('How many kings are on the board at the start of a chess game?',2,'kings',1,'FIDE Laws of Chess'),
('How many cells are in a standard 9 by 9 Sudoku grid?',81,'cells',1,'standard Sudoku rules'),
('How many rows are in a standard Sudoku grid?',9,'rows',1,'standard Sudoku rules'),
('How many columns are in a standard Sudoku grid?',9,'columns',1,'standard Sudoku rules'),
('How many 3 by 3 boxes are in a standard Sudoku grid?',9,'boxes',1,'standard Sudoku rules'),
('How many tiles are in a standard double-six domino set?',28,'tiles',2,'standard double-six domino set'),
('How many faces does a standard die have?',6,'faces',1,'standard dice conventions'),
('How many total pips appear across all six faces of a standard die?',21,'pips',2,'standard dice conventions'),
('How many pins are set up at the start of a ten-pin bowling frame?',10,'pins',1,'USBC ten-pin bowling rules'),
('How many numbered object balls are used in standard pool?',15,'balls',1,'World Pool-Billiard Association equipment standards'),
('How many balls are used in standard pool when the cue ball is included?',16,'balls',2,'World Pool-Billiard Association equipment standards'),
('How many numbered scoring sectors are on a standard dartboard?',20,'sectors',1,'World Darts Federation dartboard specifications'),
('How many keys are on a standard modern piano?',88,'keys',1,'modern piano standard'),
('How many white keys are on a standard 88-key piano?',52,'keys',2,'modern piano standard'),
('How many black keys are on a standard 88-key piano?',36,'keys',2,'modern piano standard'),
('How many tiles are in a standard English-language Scrabble set?',100,'tiles',2,'Hasbro Scrabble rules'),
('How many strings does a standard guitar usually have?',6,'strings',1,'standard guitar construction'),
('How many strings does a standard ukulele usually have?',4,'strings',1,'standard ukulele construction'),
('How many strings does a standard electric bass usually have?',4,'strings',1,'standard bass guitar construction'),
('How many horizontal lines are in a standard musical staff?',5,'lines',1,'Western music notation'),
('How many tiles are in a standard Mahjong set?',144,'tiles',2,'standard Mahjong set'),
('How many distinct notes are in a diatonic scale before the octave repeats?',7,'notes',2,'Western music theory'),
('How many semitones are in one octave in twelve-tone equal temperament?',12,'semitones',2,'Western music theory'),
('How many rings are in the Olympic symbol?',5,'rings',1,'International Olympic Committee'),
('How many stars are on the flag of the European Union?',12,'stars',1,'European Union flag specification'),
('How many stars are on the flag of the United States?',50,'stars',1,'United States flag specification'),
('How many stripes are on the flag of the United States?',13,'stripes',1,'United States flag specification'),
('How many members sit on the United Nations Security Council?',15,'members',2,'United Nations Security Council'),
('How many permanent members are on the United Nations Security Council?',5,'members',2,'United Nations Security Council'),
('How many member countries are in the European Union as of 2026?',27,'countries',2,'European Union'),
('How many constituent countries make up the United Kingdom?',4,'countries',1,'United Kingdom constitutional structure'),
('How many provinces does Canada have?',10,'provinces',1,'Government of Canada'),
('How many territories does Canada have?',3,'territories',1,'Government of Canada'),
('How many states does Australia have?',6,'states',1,'Australian Government'),
('How many emirates make up the United Arab Emirates?',7,'emirates',1,'United Arab Emirates government')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int; v_texts int; v_collisions int; v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _general_stage_2;
  if v_rows<>50 or v_texts<>50 then raise exception 'General batch 2 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _general_stage_2 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'General batch 2 invalid content'; end if;
  select count(*) into v_ids from _general_stage_2 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'General batch 2 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _general_stage_2 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'General batch 2 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'General',difficulty,source,'premium' from _general_stage_2;

do $$
declare v_inserted int; v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _general_stage_2 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'General batch 2 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _general_stage_2 s on s.id=q.id
  where q.category<>'General' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'General batch 2 post validation failed: %',v_bad; end if;
end $$;
commit;