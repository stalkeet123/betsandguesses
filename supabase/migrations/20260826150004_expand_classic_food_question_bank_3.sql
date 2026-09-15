begin;
create temporary table _food_stage_3 (
  id uuid primary key,
  text_en text not null,
  answer bigint not null,
  answer_unit text not null,
  difficulty integer not null,
  source text not null
) on commit drop;

insert into _food_stage_3 (id,text_en,answer,answer_unit,difficulty,source)
select md5('bets-and-guesses|food|3|' || v.text_en)::uuid,v.text_en,v.answer,v.answer_unit,v.difficulty,v.source
from (values
('In what year was Coca-Cola first served at Jacobs'' Pharmacy in Atlanta?',1886,'year',1,'The Coca-Cola Company history'),
('In what year was Brad''s Drink renamed Pepsi-Cola?',1898,'year',2,'PepsiCo history'),
('In what year did the first McDonald''s restaurant open in San Bernardino, California?',1940,'year',1,'McDonald''s corporate history'),
('In what year was Burger King founded?',1954,'year',2,'Burger King corporate history'),
('In what year did the first Kentucky Fried Chicken franchise open?',1952,'year',2,'KFC corporate history'),
('In what year was Starbucks founded in Seattle?',1971,'year',1,'Starbucks company history'),
('In what year was Domino''s founded as the business that became Domino''s Pizza?',1960,'year',2,'Domino''s company history'),
('In what year was Pizza Hut founded in Wichita, Kansas?',1958,'year',2,'Pizza Hut company history'),
('In what year was the sandwich chain that became Subway founded?',1965,'year',2,'Subway company history'),
('In what year was Taco Bell founded?',1962,'year',2,'Taco Bell company history'),
('In what year was Dunkin'' founded under the Dunkin'' Donuts name?',1950,'year',2,'Dunkin'' company history'),
('In what year was Krispy Kreme founded?',1937,'year',2,'Krispy Kreme company history'),
('In what year was Baskin-Robbins founded?',1945,'year',2,'Baskin-Robbins company history'),
('In what year did Ben & Jerry''s open its first scoop shop?',1978,'year',2,'Ben & Jerry''s company history'),
('In what year was the Häagen-Dazs brand created?',1960,'year',3,'Häagen-Dazs brand history'),
('In what year was Red Bull first launched in Austria?',1987,'year',2,'Red Bull company history'),
('In what year was Monster Energy launched?',2002,'year',2,'Monster Beverage company history'),
('In what year was Nutella first introduced under the Nutella name?',1964,'year',1,'Ferrero company history'),
('In what year were Oreo cookies first introduced?',1912,'year',1,'Mondelēz brand history'),
('In what year was the Snickers chocolate bar introduced?',1930,'year',1,'Mars brand history'),
('In what year did Rowntree''s first launch the bar that became Kit Kat as Chocolate Crisp?',1935,'year',3,'Nestlé KitKat history'),
('In what year were M&M''s chocolate candies first sold?',1941,'year',1,'Mars brand history'),
('In what year were Pringles introduced nationally in the United States?',1968,'year',2,'Pringles brand history'),
('In what year were Doritos launched nationally in the United States?',1966,'year',2,'PepsiCo brand history'),
('In what year were Cheetos first introduced?',1948,'year',2,'PepsiCo brand history'),
('In what year were Fritos corn chips created by Charles Elmer Doolin?',1932,'year',3,'Frito-Lay history'),
('In what year were Twinkies invented by James Dewar?',1930,'year',2,'Hostess brand history'),
('In what year were Pop-Tarts introduced by Kellogg''s?',1964,'year',2,'Kellanova brand history'),
('In what year was Gatorade invented at the University of Florida?',1965,'year',1,'University of Florida history'),
('In what year did Momofuku Ando invent instant ramen?',1958,'year',1,'Nissin company history'),
('In what year did Nissin launch Cup Noodles in Japan?',1971,'year',2,'Nissin company history'),
('In what year was the first Michelin Guide published?',1900,'year',2,'Michelin Guide history'),
('In what year was H. J. Heinz''s food company founded?',1869,'year',2,'Kraft Heinz company history'),
('In what year was the business that became Campbell Soup Company founded?',1869,'year',3,'Campbell''s company history'),
('In what year was the Hershey Chocolate Company established?',1894,'year',2,'The Hershey Company history'),
('In what year was the Kellogg Company founded as the Battle Creek Toasted Corn Flake Company?',1906,'year',3,'Kellanova company history'),
('In what year was General Mills created through the merger of several milling companies?',1928,'year',3,'General Mills company history'),
('In what year was Nestlé formed through the merger of Nestlé''s company and the Anglo-Swiss Condensed Milk Company?',1905,'year',3,'Nestlé company history'),
('In what year did John Cadbury open the shop that began the Cadbury business?',1824,'year',3,'Cadbury company history'),
('In what year was the Lindt confectionery business founded in Zurich?',1845,'year',3,'Lindt & Sprüngli history'),
('In what year was Ferrero founded in Alba, Italy?',1946,'year',2,'Ferrero company history'),
('In what year did Frank C. Mars start the candy business that became Mars, Incorporated?',1911,'year',3,'Mars company history'),
('In what year was the Hershey''s Milk Chocolate bar first sold?',1900,'year',2,'The Hershey Company history'),
('In what year did H. B. Reese create Reese''s Peanut Butter Cups?',1928,'year',2,'The Hershey Company history'),
('In what year was Toblerone first created in Bern, Switzerland?',1908,'year',2,'Toblerone brand history'),
('In what year did J. S. Fry & Sons produce one of the first modern molded chocolate bars?',1847,'year',4,'Encyclopaedia Britannica chocolate history'),
('In what year did Daniel Peter develop the first commercially successful milk chocolate?',1875,'year',4,'Encyclopaedia Britannica chocolate history'),
('In what year did Peter Durand receive a British patent for preserving food in tin cans?',1810,'year',4,'Encyclopaedia Britannica canning history'),
('In what year did Angelo Moriondo receive a patent for an early espresso machine?',1884,'year',4,'coffee technology historical records'),
('In what year did Melitta Bentz patent her paper coffee-filter system in Germany?',1908,'year',3,'Melitta company history')
) as v(text_en,answer,answer_unit,difficulty,source);

do $$
declare v_rows int;v_texts int;v_collisions int;v_ids int;
begin
  select count(*),count(distinct lower(btrim(text_en))) into v_rows,v_texts from _food_stage_3;
  if v_rows<>50 or v_texts<>50 then raise exception 'Food batch 3 staging invalid: rows %, unique %',v_rows,v_texts; end if;
  if exists(select 1 from _food_stage_3 where btrim(text_en)='' or answer<=0 or btrim(answer_unit)='' or difficulty not between 1 and 5 or btrim(source)='') then raise exception 'Food batch 3 invalid content'; end if;
  select count(*) into v_ids from _food_stage_3 s join public.questions q on q.id=s.id;
  if v_ids<>0 then raise exception 'Food batch 3 UUID collisions: %',v_ids; end if;
  select count(*) into v_collisions from _food_stage_3 s join public.questions q on lower(btrim(q.text_en))=lower(btrim(s.text_en));
  if v_collisions<>0 then raise exception 'Food batch 3 wording collisions: %',v_collisions; end if;
end $$;

insert into public.questions(id,text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier)
select id,text_en,text_en,answer,answer_unit,'Food',difficulty,source,'premium' from _food_stage_3;

do $$
declare v_inserted int;v_bad int;
begin
  select count(*) into v_inserted from public.questions q join _food_stage_3 s on s.id=q.id;
  if v_inserted<>50 then raise exception 'Food batch 3 inserted %',v_inserted; end if;
  select count(*) into v_bad from public.questions q join _food_stage_3 s on s.id=q.id
  where q.category<>'Food' or q.access_tier<>'premium' or q.text_en is distinct from s.text_en or q.text_tr is distinct from s.text_en or q.answer is distinct from s.answer or q.answer_unit is distinct from s.answer_unit or q.difficulty is distinct from s.difficulty;
  if v_bad<>0 then raise exception 'Food batch 3 post validation failed: %',v_bad; end if;
end $$;
commit;