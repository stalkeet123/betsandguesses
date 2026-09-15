-- Food, Movies, Music and Technology: exact-year recall is overwhelmingly quiz-like.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category in ('Food','Movies','Music','Technology')
  and text_en ilike 'In what year%';

-- History: keep only the broadest/easiest iconic dates for now; retire medium/hard exact-year recall.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'History'
  and text_en ilike 'In what year%'
  and coalesce(difficulty, 3) >= 2;

-- Science: remove chemistry-table and SI-definition exam questions.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Science'
  and (
    text_en ilike 'What is the atomic number of%'
    or text_en ilike 'How many atoms are in one molecule of%'
    or text_en ilike '%SI base unit%'
    or text_en ilike '%seven SI base units%'
    or text_en ilike '%luminous efficacy%'
    or text_en ilike 'In what year was the mole adopted as an SI base unit?'
  );

-- Technology: remove protocol/specification trivia that only rewards technical memorization.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Technology'
  and (
    text_en ilike '%TCP port%'
    or text_en ilike '%UDP header%'
    or text_en ilike '%IPv6%'
    or text_en ilike '%IPv4 address%'
    or text_en ilike '%hexadecimal%'
    or text_en ilike '%UTF-16%'
    or text_en ilike '%UTF-32%'
    or text_en ilike '%UTF-8 encoded%'
    or text_en ilike '%PCI Express%'
    or text_en ilike '%SHA-256%'
    or text_en ilike '%SHA-512%'
    or text_en ilike '%AES-128%'
    or text_en ilike '%AES-256%'
    or text_en ilike '%MAC address%'
    or text_en ilike '%UUID%'
    or text_en ilike '%ASCII character%'
    or text_en ilike '%one byte%'
    or text_en ilike '%TCP/IP model%'
  );