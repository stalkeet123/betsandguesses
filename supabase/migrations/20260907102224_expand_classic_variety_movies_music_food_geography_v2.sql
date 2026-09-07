with new_questions(text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier) as (
  values
  ('Jurassic Park için yapılan tam boy T. rex animatroniği yaklaşık kaç feet uzunluğundaydı?','The full-size T. rex animatronic built for Jurassic Park was about how many feet long?',36,'feet','Movies',2,'ABC News interview with Stan Winston Studio crew','starter'),
  ('Apollo 13 oyuncuları gerçek ağırlıksızlık görüntülerini çekmek için “Vomit Comet”te yaklaşık kaç parabolik uçuş yayı yaptı?','The Apollo 13 cast and crew went through about how many zero-gravity parabolic arcs to film the weightless scenes?',612,'parabolic arcs','Movies',3,'Yale Film Notes / NASA KC-135 production history','starter'),
  ('Inception’daki dönen otel koridoru seti yaklaşık kaç feet uzunluğundaydı?','About how many feet long was the rotating hotel hallway built for Inception?',100,'feet','Movies',2,'Inception production notes / Los Angeles Times','premium'),
  ('Mission: Impossible – Fallout’taki HALO sahnesini çekmek için ekip yaklaşık kaç paraşüt atlayışı yaptı?','About how many skydives did the team make to capture the HALO sequence in Mission: Impossible – Fallout?',106,'jumps','Movies',3,'Christopher McQuarrie production interview','premium'),

  ('The Beatles’ın Ed Sullivan Show’daki ilk büyük ABD TV performansını yaklaşık kaç milyon kişi izledi?','About how many people watched The Beatles’ famous first Ed Sullivan Show performance on TV?',73000000,'viewers','Music',3,'The Beatles official / Ed Sullivan Show archive','starter'),
  ('Michael Jackson’ın Thriller kısa filmi yaklaşık kaç dakika sürer?','Michael Jackson’s Thriller short film runs for about how many minutes?',14,'minutes','Music',2,'Michael Jackson official','starter'),
  ('Guinness’in kaydettiği dev bir koroda aynı anda kaç kişi şarkı söyledi?','How many people sang together in the Guinness-record largest choir?',121440,'people','Music',4,'Guinness World Records','premium'),
  ('Guinness’in kaydettiği en büyük gitar topluluğunda kaç kişi aynı anda gitar çaldı?','How many people played together in the Guinness-record largest guitar ensemble?',6346,'guitarists','Music',4,'Guinness World Records','premium'),

  ('Guinness’e giren dev bir hamburger yaklaşık kaç pound ağırlığındaydı?','A Guinness-record giant hamburger weighed about how many pounds?',2566,'pounds','Food',4,'Guinness World Records','starter'),
  ('Thorntons’ın yaptığı rekor çikolata barı yaklaşık kaç pound ağırlığındaydı?','The record-setting giant chocolate bar made by Thorntons weighed about how many pounds?',12770,'pounds','Food',4,'Guinness World Records','premium'),
  ('Guinness’e giren dev bir fincan kahve yaklaşık kaç ABD galonu kahve içeriyordu?','A Guinness-record giant cup of coffee held about how many US gallons of coffee?',7117,'US gallons','Food',4,'Guinness World Records','starter'),
  ('Airrack’in rekor büyüklükteki pizzasına yaklaşık kaç pepperoni dilimi kondu?','About how many pepperoni slices went onto Airrack’s record-setting giant pizza?',630496,'pepperoni slices','Food',4,'Guinness World Records','premium'),

  ('Great Barrier Reef yaklaşık kaç ayrı mercan resifinden oluşur?','About how many individual coral reefs make up the Great Barrier Reef?',3000,'reefs','Geography',3,'Australian Government / Great Barrier Reef Marine Park Authority','starter'),
  ('Antarktika Dünya’daki tatlı suyun yaklaşık yüzde kaçını barındırır?','About what percent of Earth’s fresh water is stored in Antarctica?',70,'percent','Geography',3,'NASA Jet Propulsion Laboratory','starter'),
  ('Yosemite Falls toplamda yaklaşık kaç feet düşer?','Yosemite Falls drops a total of about how many feet?',2425,'feet','Geography',3,'U.S. National Park Service','premium'),
  ('Death Valley National Park yaklaşık kaç milyon acre büyüklüğündedir?','Death Valley National Park covers about how many acres?',3400000,'acres','Geography',4,'U.S. National Park Service','premium'),
  ('Özgürlük Heykeli yerden meşalenin ucuna kadar yaklaşık kaç feet yüksekliğindedir?','From the ground to the tip of the flame, the Statue of Liberty is about how many feet tall?',305,'feet','Geography',2,'U.S. National Park Service','premium')
)
insert into public.questions (text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier,is_active)
select nq.text_tr,nq.text_en,nq.answer,nq.answer_unit,nq.category,nq.difficulty,nq.source,nq.access_tier,true
from new_questions nq
where not exists (
  select 1 from public.questions q where lower(btrim(q.text_en))=lower(btrim(nq.text_en))
);