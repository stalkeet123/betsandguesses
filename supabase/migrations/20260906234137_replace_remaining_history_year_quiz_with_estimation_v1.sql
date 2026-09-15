-- Remove the remaining exact-year recall from active premium History.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'History'
  and text_en ilike 'In what year%';

with new_questions(text_tr, text_en, answer, answer_unit, category, difficulty, source, access_tier, is_active) as (
  values
    ('Kraliçe II. Elizabeth yaklaşık kaç yıl hüküm sürdü?', 'Queen Elizabeth II reigned for about how many years?', 70::bigint, 'years', 'History', 2, 'The Royal Family', 'premium', true),
    ('Panama Kanalı''nın ABD öncülüğündeki ana inşaatı yaklaşık kaç yıl sürdü?', 'The main U.S.-led construction of the Panama Canal took about how many years?', 10::bigint, 'years', 'History', 2, 'US National Park Service', 'premium', true),
    ('ABD Bağımsızlık Bildirgesi''ni toplam kaç kişi imzaladı?', 'How many people signed the U.S. Declaration of Independence?', 56::bigint, 'signers', 'History', 2, 'US National Archives', 'premium', true),
    ('Apollo 11 görevi fırlatmadan Dünya''ya dönüşe yaklaşık kaç gün sürdü?', 'The Apollo 11 mission lasted about how many days from launch to splashdown?', 8::bigint, 'days', 'History', 2, 'NASA', 'premium', true),
    ('Berlin Duvarı yıkılmadan önce yaklaşık kaç yıl ayakta kaldı?', 'The Berlin Wall stood for about how many years before it fell?', 28::bigint, 'years', 'History', 2, 'historical chronology', 'premium', true),
    ('ABD''deki Prohibition dönemi yaklaşık kaç yıl sürdü?', 'U.S. Prohibition lasted for about how many years?', 13::bigint, 'years', 'History', 2, 'US National Archives historical chronology', 'premium', true),
    ('Adına rağmen Yüz Yıl Savaşları yaklaşık kaç yıl sürdü?', 'Despite its name, the Hundred Years'' War lasted about how many years?', 116::bigint, 'years', 'History', 3, 'Encyclopaedia Britannica', 'premium', true),
    ('Mayflower gemisinde Amerika''ya giden yaklaşık kaç yolcu vardı?', 'About how many passengers sailed to America on the Mayflower?', 102::bigint, 'passengers', 'History', 2, 'historical records', 'premium', true),
    ('Titanic faciasından yaklaşık kaç kişi sağ kurtuldu?', 'About how many people survived the Titanic disaster?', 706::bigint, 'survivors', 'History', 3, 'historical records', 'premium', true),
    ('Titanic kaç cankurtaran filikası taşıyordu?', 'How many lifeboats did the Titanic carry?', 20::bigint, 'lifeboats', 'History', 2, 'historical records', 'premium', true),
    ('Bağımsızlık Bildirgesi ile ABD Anayasası''nın imzalanması arasında kaç yıl vardı?', 'How many years passed between the Declaration of Independence and the U.S. Constitution?', 11::bigint, 'years', 'History', 2, 'US National Archives', 'premium', true),
    ('İlk motorlu uçuş ile ilk Ay''a insan inişi arasında yaklaşık kaç yıl vardı?', 'About how many years passed between the first powered flight and the first Moon landing?', 66::bigint, 'years', 'History', 3, 'Smithsonian and NASA chronology', 'premium', true)
)
insert into public.questions (
  text_tr, text_en, answer, answer_unit, category, difficulty, source, access_tier, is_active
)
select nq.* from new_questions nq
where not exists (
  select 1 from public.questions q where lower(btrim(q.text_en)) = lower(btrim(nq.text_en))
);