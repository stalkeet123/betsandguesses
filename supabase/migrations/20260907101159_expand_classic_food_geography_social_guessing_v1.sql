with new_questions(text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier) as (
  values
  ('Bir pound bal yapmak için arıların yaklaşık kaç çiçeği ziyaret etmesi gerekir?','Bees have to visit about how many flowers to make one pound of honey?',2000000,'flowers','Food',4,'University of Georgia Bee Program','starter'),
  ('Bir galon elma şarabı yapmak için yaklaşık kaç elma gerekir?','About how many apples does it take to make one gallon of apple cider?',35,'apples','Food',2,'USDA NRCS Minnesota','starter'),
  ('Bir pound cheddar peyniri yapmak için yaklaşık kaç pound süt gerekir?','About how many pounds of milk does it take to make one pound of Cheddar cheese?',10,'pounds of milk','Food',2,'USDA Economic Research Service','premium'),
  ('12 onsluk bir kavanoz fıstık ezmesi yapmak için yaklaşık kaç yer fıstığı gerekir?','About how many peanuts go into a 12-ounce jar of peanut butter?',540,'peanuts','Food',3,'National Peanut Board','starter'),
  ('Bir galon akçaağaç şurubu yapmak için yaklaşık kaç galon ağaç özsuyu gerekir?','About how many gallons of maple sap does it take to make one gallon of maple syrup?',40,'gallons of sap','Food',3,'Penn State Extension','starter'),
  ('Bir acre yer fıstığından yaklaşık kaç peanut-butter sandwich yapılabilir?','About how many peanut-butter sandwiches can one acre of peanuts make?',30000,'sandwiches','Food',4,'National Peanut Board / University of Nebraska-Lincoln Extension','premium'),
  ('Modern bir yumurta tavuğu yılda yaklaşık kaç yumurta verebilir?','A modern laying hen can produce about how many eggs in a year?',300,'eggs','Food',2,'Penn State Extension','premium'),
  ('Bir karpuzun yaklaşık yüzde kaçı sudur?','About what percent of a watermelon is water?',92,'percent','Food',2,'USDA Agricultural Research Service','premium'),

  ('Central Park’ta yaklaşık kaç bank vardır?','About how many benches are scattered around Central Park?',10000,'benches','Geography',3,'Central Park Conservancy','starter'),
  ('Central Park yaklaşık kaç acre büyüklüğündedir?','Central Park covers about how many acres?',843,'acres','Geography',3,'Central Park Conservancy','premium'),
  ('Yellowstone’da yaklaşık kaç aktif geyser vardır?','About how many active geysers are in Yellowstone National Park?',500,'geysers','Geography',3,'U.S. National Park Service','starter'),
  ('Yellowstone’da toplam yaklaşık kaç hidrotermal özellik bulunur?','About how many hydrothermal features are found in Yellowstone National Park?',10000,'hydrothermal features','Geography',4,'U.S. National Park Service','premium'),
  ('Great Lakes dünyadaki yüzey tatlı suyunun yaklaşık yüzde kaçını tutar?','About what percent of the world’s surface fresh water is held in the Great Lakes?',21,'percent','Geography',3,'U.S. Environmental Protection Agency','starter'),
  ('Baykal Gölü dünyadaki donmamış tatlı su rezervinin yaklaşık yüzde kaçını içerir?','About what percent of the world’s unfrozen freshwater reserve is in Lake Baikal?',20,'percent','Geography',3,'UNESCO World Heritage Centre','premium'),
  ('Panama Kanalı Atlantik’ten Pasifik’e yaklaşık kaç mil uzanır?','About how many miles long is the Panama Canal from the Atlantic to the Pacific?',50,'miles','Geography',2,'Panama Canal Authority','starter'),
  ('Grand Canyon en geniş yerinde yaklaşık kaç mil genişliğe ulaşır?','At its widest point, about how many miles across is the Grand Canyon?',18,'miles','Geography',2,'U.S. National Park Service','premium'),
  ('Everglades National Park yaklaşık kaç milyon acre alan kaplar?','About how many acres does Everglades National Park cover?',1542526,'acres','Geography',4,'U.S. National Park Service','premium'),
  ('Golden Gate Bridge’in iki kulesi arasındaki ana açıklık yaklaşık kaç feet uzunluğundadır?','About how many feet long is the Golden Gate Bridge’s main span between its towers?',4200,'feet','Geography',3,'Golden Gate Bridge Highway and Transportation District','premium')
)
insert into public.questions (text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier,is_active)
select nq.text_tr,nq.text_en,nq.answer,nq.answer_unit,nq.category,nq.difficulty,nq.source,nq.access_tier,true
from new_questions nq
where not exists (
  select 1 from public.questions q where lower(btrim(q.text_en))=lower(btrim(nq.text_en))
);