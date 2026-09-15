with new_questions(text_tr, text_en, answer, answer_unit, category, difficulty, source, access_tier, is_active) as (
  values
    ('Modern bir kara tipi rüzgâr türbininin kanadı ortalama yaklaşık kaç feet uzunluğundadır?', 'A modern land-based wind turbine blade is about how many feet long on average?', 210::bigint, 'feet', 'Technology', 3, 'U.S. Department of Energy', 'premium', true),
    ('Büyük bir rüzgâr türbini yaklaşık kaç farklı parçadan oluşur?', 'A utility-scale wind turbine can contain roughly how many different parts?', 8000::bigint, 'parts', 'Technology', 3, 'U.S. Department of Energy', 'premium', true),
    ('Modern bir rüzgâr türbininin kulesi ortalama yaklaşık kaç feet yüksekliğindedir?', 'A modern utility-scale wind turbine tower is roughly how many feet tall?', 320::bigint, 'feet', 'Technology', 3, 'U.S. Department of Energy', 'premium', true),
    ('Tipik bir ev tipi güneş paneli yaklaşık kaç watt güç üretir?', 'A typical modern residential solar panel is rated at about how many watts?', 400::bigint, 'watts', 'Technology', 2, 'U.S. Department of Energy', 'premium', true),
    ('Airbus A380 en fazla yaklaşık kaç yolcu taşıyabilir?', 'At maximum seating, about how many passengers can an Airbus A380 carry?', 853::bigint, 'passengers', 'Technology', 3, 'Airbus A380 facts and figures', 'premium', true),
    ('Airbus A380''in kanat açıklığı yaklaşık kaç feet''tir?', 'An Airbus A380 has a wingspan of about how many feet?', 262::bigint, 'feet', 'Technology', 3, 'Airbus A380 facts and figures', 'premium', true),
    ('Airbus A380 yaklaşık kaç galon yakıt taşıyabilir?', 'An Airbus A380 can carry roughly how many gallons of fuel?', 84500::bigint, 'gallons', 'Technology', 4, 'Airbus A380 facts and figures', 'premium', true),
    ('Yolcu uçağı seyir irtifasındayken kabin basıncı yaklaşık kaç feet yükseklikteymiş gibi hissedilir?', 'At cruise, a pressurized passenger jet cabin can feel like roughly what altitude?', 8000::bigint, 'feet', 'Technology', 3, 'Federal Aviation Administration', 'premium', true)
)
insert into public.questions (
  text_tr, text_en, answer, answer_unit, category, difficulty, source, access_tier, is_active
)
select nq.* from new_questions nq
where not exists (
  select 1 from public.questions q where lower(btrim(q.text_en)) = lower(btrim(nq.text_en))
);