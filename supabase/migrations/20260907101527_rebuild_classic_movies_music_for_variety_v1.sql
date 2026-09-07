-- MOVIES: retire repetitive premium templates, retaining only a tiny curated sample.
update public.questions
set is_active=false
where is_active=true
  and category='Movies'
  and access_tier='premium'
  and (
    text_en ilike '%minutes long%'
    or (text_en ilike '%grossed worldwide%' and text_en not in (
      'About how many million US dollars has Avatar grossed worldwide?',
      'About how many million US dollars has Avengers: Endgame grossed worldwide?',
      'About how many million US dollars has Barbie grossed worldwide?'
    ))
    or (text_en ilike '%Academy Awards%' and text_en not in (
      'How many competitive Academy Awards did Oppenheimer win?',
      'How many competitive Academy Awards did Everything Everywhere All at Once win?',
      'How many competitive Academy Awards did Ben-Hur from 1959 win?'
    ))
  );

update public.questions
set is_active=false
where is_active=true
  and category='Movies'
  and access_tier='starter'
  and text_en in (
    'About how many million dollars did The Lion King (2019) make worldwide?',
    'About how many minutes long is Home Alone?',
    'About how many minutes long is Jurassic Park?',
    'Goodfellas runs for about how many minutes?',
    'The Godfather runs for about how many minutes?',
    'How many Academy Awards did Titanic win?'
  );

update public.questions
set is_active=false
where is_active=true
  and category='Music'
  and access_tier='premium'
  and (
    text_en ilike 'How many tracks%'
    or text_en ilike 'How many tracks were%'
    or text_en ilike 'How many studio albums%'
    or text_en ilike 'How many bits per sample%'
    or text_en ilike 'How many channels can a standard MIDI%'
    or text_en ilike 'How many possible MIDI%'
    or text_en ilike 'What is the highest common MP3%'
    or text_en ilike 'What sampling rate%'
    or text_en ilike 'What frequency in hertz%'
    or text_en ilike 'How many pitch classes%'
    or text_en ilike 'How many semitones%'
    or text_en ilike 'How many Brandenburg Concertos%'
    or text_en ilike 'How many Goldberg Variations%'
    or text_en ilike 'How many movements are in%'
    or text_en ilike 'How many numbered piano sonatas%'
    or text_en ilike 'How many numbered symphonies%'
    or text_en ilike 'How many operas make up%'
    or text_en ilike 'How many piano concertos%'
    or text_en ilike 'How many string quartets%'
    or text_en ilike 'How many songs has the band The Beatles%'
    or text_en ilike 'How many finger holes%'
    or text_en ilike 'How many holes does a standard diatonic harmonica%'
    or text_en ilike 'How many pedals does a modern concert harp%'
    or text_en ilike 'How many slide positions%'
    or text_en ilike 'How many strings does a standard mandolin%'
    or text_en ilike 'How many strings does a standard orchestral double bass%'
    or text_en ilike 'How many timpani%'
    or text_en ilike 'How many valves does%'
  );

with new_questions(text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier) as (
  values
  ('Oppenheimer’ın 70mm IMAX film kopyası uçtan uca yaklaşık kaç mil uzunluğundaydı?','If you unrolled an Oppenheimer 70mm IMAX print, about how many miles long would it be?',11,'miles','Movies',2,'BFI IMAX','starter'),
  ('Mad Max: Fury Road için yaklaşık kaç gerçek araç üretildi?','About how many real vehicles were built for Mad Max: Fury Road?',150,'vehicles','Movies',3,'Mad Max production design / National Motor Museum','starter'),
  ('Interstellar çekimleri için yapım ekibi yaklaşık kaç acre gerçek mısır ekti?','About how many acres of real corn did the Interstellar production plant for filming?',500,'acres','Movies',3,'Interstellar production notes / Christopher Nolan','starter'),
  ('The Lord of the Rings üçlemesi için yaklaşık kaç ayrı zırh parçası üretildi?','About how many separate pieces of armor were made for The Lord of the Rings trilogy?',48000,'armor pieces','Movies',4,'The Lord of the Rings production notes / Weta Workshop','starter'),
  ('The Lord of the Rings çekimleri için yaklaşık kaç çift protez Hobbit ayağı üretildi?','About how many pairs of prosthetic Hobbit feet were made for The Lord of the Rings trilogy?',1600,'pairs of Hobbit feet','Movies',3,'The Lord of the Rings production notes / Weta Workshop','premium'),
  ('Titanic filmi için yapılan neredeyse tam boy gemi seti yaklaşık kaç feet uzunluğundaydı?','About how many feet long was the near-full-size Titanic ship set built for the movie?',775,'feet','Movies',3,'James Cameron production interview / Titanic production history','starter'),
  ('Titanic filminin dev su tankı yaklaşık kaç milyon galon su alıyordu?','About how many gallons of water did the giant tank built for Titanic hold?',17000000,'gallons','Movies',4,'Titanic production history','premium'),
  ('Jaws için yapılan tam boy mekanik köpekbalığı yaklaşık kaç feet uzunluğundaydı?','About how many feet long was the full-size mechanical shark built for Jaws?',25,'feet','Movies',2,'American Society of Cinematographers / Jaws production','starter'),
  ('Jaws için yapılan mekanik köpekbalığının yapımı yaklaşık kaç dolara mal oldu?','About how many dollars did the mechanical shark for Jaws cost to build?',250000,'US dollars','Movies',4,'American Society of Cinematographers / Jaws production','premium'),

  ('Rod Stewart’ın Copacabana’daki rekor ücretsiz konserine yaklaşık kaç kişi katıldı?','About how many people attended Rod Stewart’s record-setting free concert at Copacabana Beach?',3500000,'people','Music',4,'Guinness World Records','starter'),
  ('Queen’in Live Aid performansını dünya çapında yaklaşık kaç kişi izledi?','About how many people worldwide watched Queen’s Live Aid performance?',1900000000,'people','Music',4,'Queen Official','starter'),
  ('Dünyanın en büyük pipe organında yaklaşık kaç boru vardır?','About how many pipes are in the world’s largest pipe organ?',33114,'pipes','Music',4,'Yamaha Musical Instrument Guide','starter'),
  ('Bir Steinway Model D konser piyanosu yaklaşık kaç pound ağırlığındadır?','About how many pounds does a Steinway Model D concert grand piano weigh?',990,'pounds','Music',3,'Steinway & Sons','starter'),
  ('Stradivari atölyesinden günümüze yaklaşık kaç enstrüman ulaşmıştır?','About how many instruments from Stradivari’s workshop still survive today?',600,'instruments','Music',4,'The Metropolitan Museum of Art','premium'),
  ('Dünya rekoru kıran en büyük orkestrada kaç müzisyen vardı?','How many musicians played in the Guinness World Record largest orchestra?',8573,'musicians','Music',4,'Guinness World Records','starter'),
  ('Dünya rekoru kıran en büyük bateri seti toplam kaç parçadan oluşuyordu?','How many pieces were in the Guinness World Record largest drum set?',813,'pieces','Music',3,'Guinness World Records','premium'),
  ('Bir solo sanatçının dünya rekoru kıran en uzun konseri yaklaşık kaç saat sürdü?','About how many hours did the Guinness World Record longest concert by a solo artist last?',501,'hours','Music',4,'Guinness World Records','premium')
)
insert into public.questions (text_tr,text_en,answer,answer_unit,category,difficulty,source,access_tier,is_active)
select nq.text_tr,nq.text_en,nq.answer,nq.answer_unit,nq.category,nq.difficulty,nq.source,nq.access_tier,true
from new_questions nq
where not exists (
  select 1 from public.questions q where lower(btrim(q.text_en))=lower(btrim(nq.text_en))
);