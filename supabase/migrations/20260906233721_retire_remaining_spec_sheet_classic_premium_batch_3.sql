-- Technology: second sweep for spec-sheet / certification-style recall.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Technology'
  and (
    text_en ilike '%bits per channel%'
    or text_en ilike '%bits per pixel%'
    or text_en ilike '%bits wide%'
    or text_en ilike '%gibibyte%'
    or text_en ilike '%kibibyte%'
    or text_en ilike '%mebibyte%'
    or text_en ilike '%tebibyte%'
    or text_en ilike '%floppy disk%'
    or text_en ilike '%Ethernet%'
    or text_en ilike '%USB 3.2%'
    or text_en ilike '%USB4%'
    or text_en ilike '%USB Type-%'
    or text_en ilike '%SATA III%'
    or text_en ilike '%Blu-ray%'
    or text_en ilike '%CD-ROM%'
    or text_en ilike '%DVD%'
    or text_en ilike '%RJ45%'
    or text_en ilike '%twisted wire pairs%'
    or text_en ilike '%USB 2.0 power rail%'
  );

-- Geography: mass-produced summit-height lookup questions are poor social guesses.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Geography'
  and text_en ilike 'Approximately how many meters above sea level is the summit of%';

-- Sports: remove rulebook/equipment-spec recall rather than everyday estimation.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category = 'Sports'
  and (
    text_en ilike '%Rules of Golf%'
    or text_en ilike '%regulation IIHF%'
    or text_en ilike '%regulation badminton%'
    or text_en ilike '%regulation doubles tennis%'
    or text_en ilike '%shot clock%'
    or text_en ilike '%rugby union%'
    or text_en ilike '%volleyball net%'
    or text_en ilike '%Laws of Cricket%'
    or text_en ilike '%World Athletics technical rules%'
    or text_en ilike '%ITTF equipment specifications%'
    or text_en ilike '%USGA equipment rules%'
  );

-- Music and Food: tiny difficulty-1 facts tend to collapse everybody onto the same guess.
update public.questions
set is_active = false
where is_active = true
  and access_tier = 'premium'
  and category in ('Music','Food')
  and coalesce(difficulty, 3) = 1
  and answer <= 10;