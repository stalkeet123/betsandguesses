begin;
create temporary table _poll_v3_1 (slug text primary key, prompt_template text not null) on commit drop;
insert into _poll_v3_1(slug,prompt_template) values
('poll_v3_001','Who would be the first to volunteer for a completely unplanned trip?'),
('poll_v3_002','Who would turn a quiet dinner into the funniest night?'),
('poll_v3_003','Who would be trusted with the group’s spare key?'),
('poll_v3_004','Who would be best at finding a solution with almost no instructions?'),
('poll_v3_005','Who would notice first if the restaurant forgot part of the order?'),
('poll_v3_006','Who would be most likely to have a snack hidden in their bag right now?'),
('poll_v3_007','Who would be best at choosing a movie everyone actually enjoys?'),
('poll_v3_008','Who would be the first to suggest dessert after saying they were full?'),
('poll_v3_009','Who would be most likely to know a random fact that saves the day?'),
('poll_v3_010','Who would be best at calming everyone down during travel chaos?'),
('poll_v3_011','Who would be most likely to remember the Wi-Fi password months later?'),
('poll_v3_012','Who would be best at finding the cheapest good option online?'),
('poll_v3_013','Who would be the first to start a sing-along on a road trip?'),
('poll_v3_014','Who would be most likely to bring a charger when everyone else forgot one?'),
('poll_v3_015','Who would be best at assembling furniture without reading the instructions?'),
('poll_v3_016','Who would be most likely to keep every receipt just in case?'),
('poll_v3_017','Who would be the first to spot a typo on a menu?'),
('poll_v3_018','Who would be best at making a boring wait feel fun?'),
('poll_v3_019','Who would be most likely to turn leftovers into a great meal?'),
('poll_v3_020','Who would be trusted to choose the group’s playlist for a long drive?'),
('poll_v3_021','Who would be the first to suggest a game when everyone gets bored?'),
('poll_v3_022','Who would be most likely to remember exactly where they left their keys?'),
('poll_v3_023','Who would be best at talking to customer support and getting a problem fixed?'),
('poll_v3_024','Who would be most likely to bring an umbrella when the forecast says sunshine?'),
('poll_v3_025','Who would be best at picking a gift for someone they barely know?'),
('poll_v3_026','Who would be the first to discover a great local place while traveling?'),
('poll_v3_027','Who would be most likely to have a backup plan for the backup plan?'),
('poll_v3_028','Who would be best at making friends with a neighbor they just met?'),
('poll_v3_029','Who would be the first to wake up naturally before an early alarm?'),
('poll_v3_030','Who would be most likely to know which supermarket line will move fastest?'),
('poll_v3_031','Who would be best at remembering everyone’s birthdays without reminders?'),
('poll_v3_032','Who would be the first to fix a small household problem themselves?'),
('poll_v3_033','Who would be most likely to keep a plant alive for years?'),
('poll_v3_034','Who would be best at navigating a city they have never visited?'),
('poll_v3_035','Who would be the first to read all the instructions before starting something?'),
('poll_v3_036','Who would be most likely to have the cleanest desktop on their computer?'),
('poll_v3_037','Who would be best at choosing the perfect seat in a crowded place?'),
('poll_v3_038','Who would be the first to offer to split the last piece of food?'),
('poll_v3_039','Who would be most likely to remember someone’s name after meeting them once?'),
('poll_v3_040','Who would be best at packing everything needed into one small bag?'),
('poll_v3_041','Who would be the first to find a hidden shortcut in a video game?'),
('poll_v3_042','Who would be most likely to know a song from just the first few seconds?'),
('poll_v3_043','Who would be best at keeping a straight face during a ridiculous situation?'),
('poll_v3_044','Who would be best at choosing a restaurant for a picky group?'),
('poll_v3_045','Who would be most likely to carry cash when everyone else only has cards?'),
('poll_v3_046','Who would be best at remembering directions after hearing them once?'),
('poll_v3_047','Who would be the first to learn everyone’s coffee order?'),
('poll_v3_048','Who would be most likely to finish a puzzle before everyone else?'),
('poll_v3_049','Who would be best at making a new guest feel included?'),
('poll_v3_050','Who would be the first to turn on music while cleaning?');

do $$ declare v_rows int;v_unique int;v_collisions int;v_slug_collisions int; begin
 select count(*),count(distinct lower(btrim(prompt_template))) into v_rows,v_unique from _poll_v3_1;
 if v_rows<>50 or v_unique<>50 then raise exception 'Party poll v3 batch 1 invalid: rows %, unique %',v_rows,v_unique; end if;
 select count(*) into v_collisions from _poll_v3_1 s join public.party_challenges c on lower(btrim(c.prompt_template))=lower(btrim(s.prompt_template));
 if v_collisions<>0 then raise exception 'Party poll v3 batch 1 wording collisions: %',v_collisions; end if;
 select count(*) into v_slug_collisions from _poll_v3_1 s join public.party_challenges c on c.slug=s.slug;
 if v_slug_collisions<>0 then raise exception 'Party poll v3 batch 1 slug collisions: %',v_slug_collisions; end if;
end $$;

insert into public.party_challenges(id,slug,prompt_template,rules,answer_unit,max_result,enabled,bet_boundaries,challenge_type,duration_seconds,performer_success_bonus,category,result_direction,required_items,option_a,option_b)
select md5('bets-and-guesses|party-poll-v3|1|'||slug||'|'||prompt_template)::uuid,slug,prompt_template,
'Use each of your 5, 10, and 20 chips at most once across up to three players. Chip value is voting weight; the highest total chip weight wins.',
'player',7,true,null,'poll',30,15,'poll','higher',array[]::text[],null,null from _poll_v3_1;

do $$ declare v_inserted int; begin select count(*) into v_inserted from public.party_challenges c join _poll_v3_1 s on s.slug=c.slug; if v_inserted<>50 then raise exception 'Party poll v3 batch 1 inserted %',v_inserted; end if; end $$;
commit;