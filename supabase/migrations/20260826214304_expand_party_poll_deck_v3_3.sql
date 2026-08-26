begin;
create temporary table _poll_v3_3 (slug text primary key, prompt_template text not null) on commit drop;
insert into _poll_v3_3(slug,prompt_template) values
('poll_v3_101','Who would be chosen to represent Earth in a friendly alien talent show?'),
('poll_v3_102','Who would be the best roommate on a space station?'),
('poll_v3_103','Who would be most likely to name a pet something completely unexpected?'),
('poll_v3_104','Who would be the first to build a blanket fort that everyone wants to join?'),
('poll_v3_105','Who would make the best voice for an animated sidekick?'),
('poll_v3_106','Who would be most likely to create a catchphrase the whole group starts repeating?'),
('poll_v3_107','Who would be the best at surviving a week in a tiny cabin with no internet?'),
('poll_v3_108','Who would be most likely to turn a costume party into a full character performance?'),
('poll_v3_109','Who would be the first to make friends with a friendly robot?'),
('poll_v3_110','Who would make the best host of a late-night talk show?'),
('poll_v3_111','Who would be most likely to adopt an absurdly specific morning routine?'),
('poll_v3_112','Who would be the best tour guide for a city they invented?'),
('poll_v3_113','Who would be most likely to write a surprisingly good children’s book?'),
('poll_v3_114','Who would be the first to turn a silly idea into an actual project?'),
('poll_v3_115','Who would make the best narrator for a nature documentary?'),
('poll_v3_116','Who would be most likely to create the funniest name for a new restaurant?'),
('poll_v3_117','Who would make the best judge for a completely pointless competition?'),
('poll_v3_118','Who would be most likely to become emotionally attached to a random object?'),
('poll_v3_119','Who would be the first to decorate a room for a made-up holiday?'),
('poll_v3_120','Who would make the best character in a sitcom about this group?'),
('poll_v3_121','Who would be most likely to invent a game with rules that somehow make sense?'),
('poll_v3_122','Who would be best at creating a movie-trailer voice for an ordinary day?'),
('poll_v3_123','Who would be most likely to keep a souvenir from a completely ordinary day?'),
('poll_v3_124','Who would be the best at making a cardboard invention actually work?'),
('poll_v3_125','Who would be most likely to organize a themed dinner just for fun?'),
('poll_v3_126','Who would be the first to wear a ridiculous hat with complete confidence?'),
('poll_v3_127','Who would make the best fictional mayor of this friend group?'),
('poll_v3_128','Who would be most likely to write a five-star review for something very ordinary?'),
('poll_v3_129','Who would be the best at inventing a believable fake holiday tradition?'),
('poll_v3_130','Who would be most likely to build the most elaborate sandwich?'),
('poll_v3_131','Who would be the first to name a household appliance like it was a pet?'),
('poll_v3_132','Who would make the best host of a cooking show with no recipe?'),
('poll_v3_133','Who would be most likely to create a playlist for a very specific mood?'),
('poll_v3_134','Who would be the best at turning a simple photo into a dramatic photoshoot?'),
('poll_v3_135','Who would be most likely to keep a running list of funny quotes from friends?'),
('poll_v3_136','Who would be the first to suggest matching outfits for a group photo?'),
('poll_v3_137','Who would make the best museum guide for an exhibition of completely ordinary objects?'),
('poll_v3_138','Who would be most likely to invent a new snack combination that actually tastes good?'),
('poll_v3_139','Who would be the best at turning three random words into a funny story?'),
('poll_v3_140','Who would be most likely to create a detailed ranking of something nobody else ranks?'),
('poll_v3_141','Who would be the first to buy a tiny gadget just because it looks clever?'),
('poll_v3_142','Who would make the best mascot for the group?'),
('poll_v3_143','Who would be most likely to turn a casual photo into a full photo session?'),
('poll_v3_144','Who would be the best at inventing a slogan for the group?'),
('poll_v3_145','Who would be most likely to create a secret handshake and insist everyone learns it?'),
('poll_v3_146','Who would be the first to start a countdown for something months away?'),
('poll_v3_147','Who would make the best contestant on a show where every challenge is completely random?'),
('poll_v3_148','Who would be most likely to make a spreadsheet for a fun personal project?'),
('poll_v3_149','Who would be the best at naming a boat they do not own?'),
('poll_v3_150','Who would be most likely to start a collection after finding just one interesting item?');

do $$ declare v_rows int;v_unique int;v_collisions int;v_slug_collisions int; begin
 select count(*),count(distinct lower(btrim(prompt_template))) into v_rows,v_unique from _poll_v3_3;
 if v_rows<>50 or v_unique<>50 then raise exception 'Party poll v3 batch 3 invalid: rows %, unique %',v_rows,v_unique; end if;
 select count(*) into v_collisions from _poll_v3_3 s join public.party_challenges c on lower(btrim(c.prompt_template))=lower(btrim(s.prompt_template));
 if v_collisions<>0 then raise exception 'Party poll v3 batch 3 wording collisions: %',v_collisions; end if;
 select count(*) into v_slug_collisions from _poll_v3_3 s join public.party_challenges c on c.slug=s.slug;
 if v_slug_collisions<>0 then raise exception 'Party poll v3 batch 3 slug collisions: %',v_slug_collisions; end if;
end $$;
insert into public.party_challenges(id,slug,prompt_template,rules,answer_unit,max_result,enabled,bet_boundaries,challenge_type,duration_seconds,performer_success_bonus,category,result_direction,required_items,option_a,option_b)
select md5('bets-and-guesses|party-poll-v3|3|'||slug||'|'||prompt_template)::uuid,slug,prompt_template,
'Use each of your 5, 10, and 20 chips at most once across up to three players. Chip value is voting weight; the highest total chip weight wins.',
'player',7,true,null,'poll',30,15,'poll','higher',array[]::text[],null,null from _poll_v3_3;
do $$ declare v_inserted int; begin select count(*) into v_inserted from public.party_challenges c join _poll_v3_3 s on s.slug=c.slug; if v_inserted<>50 then raise exception 'Party poll v3 batch 3 inserted %',v_inserted; end if; end $$;
commit;