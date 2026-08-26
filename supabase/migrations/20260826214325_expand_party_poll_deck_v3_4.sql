begin;
create temporary table _poll_v3_4 (slug text primary key, prompt_template text not null) on commit drop;
insert into _poll_v3_4(slug,prompt_template) values
('poll_v3_151','Who would be the best person to organize a group trip with ten moving parts?'),
('poll_v3_152','Who would be most likely to arrive with exactly the thing everyone forgot?'),
('poll_v3_153','Who would be the first to notice the group is running late?'),
('poll_v3_154','Who would be best at turning a vague idea into a real plan?'),
('poll_v3_155','Who would be most likely to keep a shared calendar actually updated?'),
('poll_v3_156','Who would be the best at dividing tasks so everyone has something useful to do?'),
('poll_v3_157','Who would be the first to volunteer to call and make a reservation?'),
('poll_v3_158','Who would be most likely to remember the confirmation number?'),
('poll_v3_159','Who would be the best at finding a compromise when the group cannot agree?'),
('poll_v3_160','Who would be the first to check whether a place is actually open before leaving?'),
('poll_v3_161','Who would be most likely to bring extra water for everyone?'),
('poll_v3_162','Who would be the best at keeping a group moving through a crowded event?'),
('poll_v3_163','Who would be the first to make a checklist for a weekend away?'),
('poll_v3_164','Who would be most likely to save an important address offline before traveling?'),
('poll_v3_165','Who would be the best at picking a meeting point nobody can misunderstand?'),
('poll_v3_166','Who would be the first to suggest leaving early to avoid traffic?'),
('poll_v3_167','Who would be most likely to remember where the car is parked in a huge lot?'),
('poll_v3_168','Who would be the best at finding a quiet place in a busy city?'),
('poll_v3_169','Who would be the first to ask for directions when everyone else is guessing?'),
('poll_v3_170','Who would be most likely to carry a small emergency kit?'),
('poll_v3_171','Who would be the best at keeping track of everyone’s tickets?'),
('poll_v3_172','Who would be the first to check the weather twice before a day outdoors?'),
('poll_v3_173','Who would be most likely to have a useful offline map downloaded?'),
('poll_v3_174','Who would be the best at spotting a tourist trap before entering?'),
('poll_v3_175','Who would be the first to find a charging point when everyone’s battery is low?'),
('poll_v3_176','Who would be most likely to pack a snack for the journey home?'),
('poll_v3_177','Who would be the best at choosing a meeting time everyone can actually make?'),
('poll_v3_178','Who would be the first to send a clear summary after a complicated group chat?'),
('poll_v3_179','Who would be most likely to remember who paid for what?'),
('poll_v3_180','Who would be the best at keeping a surprise plan organized without revealing it?'),
('poll_v3_181','Who would be the first to make a backup reservation just in case?'),
('poll_v3_182','Who would be most likely to bring a pen when one is suddenly needed?'),
('poll_v3_183','Who would be the best at noticing when someone in the group has been left out?'),
('poll_v3_184','Who would be the first to introduce two people who would get along well?'),
('poll_v3_185','Who would be most likely to know the best place to sit at a live event?'),
('poll_v3_186','Who would be the best at choosing one activity everyone can enjoy?'),
('poll_v3_187','Who would be the first to suggest taking a group photo before people leave?'),
('poll_v3_188','Who would be most likely to remember to charge every device before a trip?'),
('poll_v3_189','Who would be the best at keeping track of time without constantly checking a phone?'),
('poll_v3_190','Who would be the first to notice when the directions do not match the surroundings?'),
('poll_v3_191','Who would be most likely to carry tissues when someone needs one?'),
('poll_v3_192','Who would be the best at finding a good meal near a train station?'),
('poll_v3_193','Who would be the first to notice a great photo opportunity?'),
('poll_v3_194','Who would be most likely to save a place in their map app for later?'),
('poll_v3_195','Who would be best at remembering everyone’s preferences when making a group choice?'),
('poll_v3_196','Who would be the first to check the bill for an accidental extra charge?'),
('poll_v3_197','Who would be most likely to carry a reusable bottle everywhere?'),
('poll_v3_198','Who would be the best at planning a full day without making it feel overplanned?'),
('poll_v3_199','Who would be the first to realize the group forgot something before getting too far?'),
('poll_v3_200','Who would be most likely to keep the group chat useful instead of chaotic?');

do $$ declare v_rows int;v_unique int;v_collisions int;v_slug_collisions int; begin
 select count(*),count(distinct lower(btrim(prompt_template))) into v_rows,v_unique from _poll_v3_4;
 if v_rows<>50 or v_unique<>50 then raise exception 'Party poll v3 batch 4 invalid: rows %, unique %',v_rows,v_unique; end if;
 select count(*) into v_collisions from _poll_v3_4 s join public.party_challenges c on lower(btrim(c.prompt_template))=lower(btrim(s.prompt_template));
 if v_collisions<>0 then raise exception 'Party poll v3 batch 4 wording collisions: %',v_collisions; end if;
 select count(*) into v_slug_collisions from _poll_v3_4 s join public.party_challenges c on c.slug=s.slug;
 if v_slug_collisions<>0 then raise exception 'Party poll v3 batch 4 slug collisions: %',v_slug_collisions; end if;
end $$;
insert into public.party_challenges(id,slug,prompt_template,rules,answer_unit,max_result,enabled,bet_boundaries,challenge_type,duration_seconds,performer_success_bonus,category,result_direction,required_items,option_a,option_b)
select md5('bets-and-guesses|party-poll-v3|4|'||slug||'|'||prompt_template)::uuid,slug,prompt_template,
'Use each of your 5, 10, and 20 chips at most once across up to three players. Chip value is voting weight; the highest total chip weight wins.',
'player',7,true,null,'poll',30,15,'poll','higher',array[]::text[],null,null from _poll_v3_4;
do $$ declare v_inserted int; begin select count(*) into v_inserted from public.party_challenges c join _poll_v3_4 s on s.slug=c.slug; if v_inserted<>50 then raise exception 'Party poll v3 batch 4 inserted %',v_inserted; end if; end $$;
commit;