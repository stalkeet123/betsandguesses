-- General: obvious conversion/calendar/card facts create no guess spread.
update public.questions
set is_active=false
where is_active=true
  and category='General'
  and access_tier='premium'
  and difficulty=1;

-- Sports: basic rulebook facts are knowledge checks, not estimation play.
update public.questions
set is_active=false
where is_active=true
  and category='Sports'
  and access_tier='premium'
  and difficulty=1;

-- Science: remove remaining small-answer textbook lookup clusters.
update public.questions
set is_active=false
where is_active=true
  and category='Science'
  and access_tier='premium'
  and (
    text_en ilike 'How many atoms are in one formula unit%'
    or text_en ilike 'How many cervical vertebrae%'
    or text_en ilike 'How many lumbar vertebrae%'
    or text_en ilike 'How many chambers does the human heart%'
    or text_en ilike 'How many valves does the human heart%'
    or text_en ilike 'How many complete chromosome sets%'
    or text_en ilike 'How many defining constants%'
    or text_en ilike 'How many different DNA bases%'
    or text_en ilike 'How many gas giant planets%'
    or text_en ilike 'How many ice giant planets%'
    or text_en ilike 'How many laws of planetary motion%'
    or text_en ilike 'How many lobes does the left human lung%'
    or text_en ilike 'How many lobes does the right human lung%'
    or text_en ilike 'How many main internal layers%'
    or text_en ilike 'How many named ocean basins%'
    or text_en ilike 'How many natural satellites does Earth%'
    or text_en ilike 'How many natural satellites does Mars%'
    or text_en ilike 'How many officially recognized dwarf planets%'
    or text_en ilike 'How many pairs of chromosomes%'
    or text_en ilike 'How many planets are in our solar system%'
    or text_en ilike 'How many principal layers does Earth%'
    or text_en ilike 'How many terrestrial planets%'
    or text_en ilike 'What is the approximate maximum percentage of water vapor%'
  );

-- Animals: keep size questions only when the subject itself is broadly recognizable.
update public.questions
set is_active=false
where is_active=true
  and category='Animals'
  and access_tier='premium'
  and (
    text_en ilike 'About how many%weigh%'
    or text_en ilike 'About how many%long%'
    or text_en ilike 'About how many%tall%'
    or text_en ilike '%wingspan%'
  )
  and text_en !~* '(blue whale|giraffe|lion|gorilla|rhinoceros|bison|ostrich|king cobra|anaconda|komodo|saltwater crocodile|narwhal|whale shark|capybara|hippopotamus|bald eagle|manta ray|walrus|peacock|moose|manatee|giant squid|colossal squid|galapagos tortoise)';