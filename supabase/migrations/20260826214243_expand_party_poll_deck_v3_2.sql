begin;
create temporary table _poll_v3_2 (slug text primary key, prompt_template text not null) on commit drop;
insert into _poll_v3_2(slug,prompt_template) values
('poll_v3_051','Who would be best at teaching a skill they learned only recently?'),
('poll_v3_052','Who would be most likely to learn a few useful phrases before visiting another country?'),
('poll_v3_053','Who would be the first to read reviews before buying something expensive?'),
('poll_v3_054','Who would be best at making a convincing presentation with five minutes of preparation?'),
('poll_v3_055','Who would be most likely to win a memory game?'),
('poll_v3_056','Who would be best at recognizing a place from a single photo?'),
('poll_v3_057','Who would be the first to figure out how a new gadget works?'),
('poll_v3_058','Who would be most likely to remember the rules of a game years later?'),
('poll_v3_059','Who would be best at solving a riddle under time pressure?'),
('poll_v3_060','Who would be the first to spot when a plan has one obvious flaw?'),
('poll_v3_061','Who would be most likely to learn a dance move the fastest?'),
('poll_v3_062','Who would be best at copying a complicated rhythm after hearing it once?'),
('poll_v3_063','Who would be the first to recognize a famous landmark from its silhouette?'),
('poll_v3_064','Who would be most likely to win a trivia night by knowing a little about everything?'),
('poll_v3_065','Who would be best at guessing what ingredient is missing from a dish?'),
('poll_v3_066','Who would be the first to master a new board game?'),
('poll_v3_067','Who would be most likely to remember a phone number after hearing it once?'),
('poll_v3_068','Who would be best at estimating how long a task will actually take?'),
('poll_v3_069','Who would be the first to notice a pattern in a sequence?'),
('poll_v3_070','Who would be most likely to win a word game?'),
('poll_v3_071','Who would be best at explaining something complicated in simple words?'),
('poll_v3_072','Who would be the first to learn a new app without asking for help?'),
('poll_v3_073','Who would be most likely to recognize a movie from one line of dialogue?'),
('poll_v3_074','Who would be best at drawing something recognizable in 30 seconds?'),
('poll_v3_075','Who would be the first to solve a practical problem with whatever is nearby?'),
('poll_v3_076','Who would be most likely to win a scavenger hunt?'),
('poll_v3_077','Who would be best at remembering where everyone sat at a dinner last year?'),
('poll_v3_078','Who would be the first to identify a song playing quietly in the background?'),
('poll_v3_079','Who would be most likely to win a geography quiz?'),
('poll_v3_080','Who would be best at estimating the total bill before it arrives?'),
('poll_v3_081','Who would be the first to learn a card trick?'),
('poll_v3_082','Who would be most likely to remember a long list without writing it down?'),
('poll_v3_083','Who would be best at finding the one missing piece of a puzzle?'),
('poll_v3_084','Who would be the first to understand an inside joke in a new group?'),
('poll_v3_085','Who would be most likely to notice when someone changes their hairstyle?'),
('poll_v3_086','Who would be best at guessing the ending of a mystery movie?'),
('poll_v3_087','Who would be the first to find the correct gate in a huge airport?'),
('poll_v3_088','Who would be most likely to win a spelling challenge?'),
('poll_v3_089','Who would be best at recognizing brands from their logos?'),
('poll_v3_090','Who would be the first to spot the difference between two nearly identical pictures?'),
('poll_v3_091','Who would be most likely to win a quick mental-math challenge?'),
('poll_v3_092','Who would be best at remembering the exact wording of a funny quote?'),
('poll_v3_093','Who would be the first to figure out a complicated remote control?'),
('poll_v3_094','Who would be most likely to win a map-reading challenge?'),
('poll_v3_095','Who would be best at arranging a suitcase so everything fits?'),
('poll_v3_096','Who would be the first to notice when a recipe measurement looks wrong?'),
('poll_v3_097','Who would be most likely to win a guessing game with almost no clues?'),
('poll_v3_098','Who would be best at choosing the fastest route during rush hour?'),
('poll_v3_099','Who would be the first to remember a forgotten detail from an old trip?'),
('poll_v3_100','Who would be most likely to master a new hobby after one weekend?');

do $$ declare v_rows int;v_unique int;v_collisions int;v_slug_collisions int; begin
 select count(*),count(distinct lower(btrim(prompt_template))) into v_rows,v_unique from _poll_v3_2;
 if v_rows<>50 or v_unique<>50 then raise exception 'Party poll v3 batch 2 invalid: rows %, unique %',v_rows,v_unique; end if;
 select count(*) into v_collisions from _poll_v3_2 s join public.party_challenges c on lower(btrim(c.prompt_template))=lower(btrim(s.prompt_template));
 if v_collisions<>0 then raise exception 'Party poll v3 batch 2 wording collisions: %',v_collisions; end if;
 select count(*) into v_slug_collisions from _poll_v3_2 s join public.party_challenges c on c.slug=s.slug;
 if v_slug_collisions<>0 then raise exception 'Party poll v3 batch 2 slug collisions: %',v_slug_collisions; end if;
end $$;
insert into public.party_challenges(id,slug,prompt_template,rules,answer_unit,max_result,enabled,bet_boundaries,challenge_type,duration_seconds,performer_success_bonus,category,result_direction,required_items,option_a,option_b)
select md5('bets-and-guesses|party-poll-v3|2|'||slug||'|'||prompt_template)::uuid,slug,prompt_template,
'Use each of your 5, 10, and 20 chips at most once across up to three players. Chip value is voting weight; the highest total chip weight wins.',
'player',7,true,null,'poll',30,15,'poll','higher',array[]::text[],null,null from _poll_v3_2;
do $$ declare v_inserted int; begin select count(*) into v_inserted from public.party_challenges c join _poll_v3_2 s on s.slug=c.slug; if v_inserted<>50 then raise exception 'Party poll v3 batch 2 inserted %',v_inserted; end if; end $$;
commit;