-- General: remove administrative-subdivision, component-count, conversion and institutional quiz catalog.
update public.questions
set is_active=false
where is_active=true and category='General' and (
  coalesce(source,'') ~* '(government|confederation|republic|rules|standard|conventions|music theory|united nations|european union|security council|counting units|weight system)'
  or text_en in (
    'At standard atmospheric pressure, at how many degrees Fahrenheit does water boil?',
    'Exactly how many hours are in a 365-day year?',
    'Exactly how many minutes are in one week?',
    'Exactly how many seconds are in one day?',
    'How many feet are in one statute mile?',
    'How many yards are in one statute mile?',
    'How many hours are in one seven-day week?',
    'How many minutes are in one full day?',
    'How many seconds are in one hour?',
    'How many clock faces are on Elizabeth Tower, home of Big Ben?',
    'How many columns surround the Lincoln Memorial?',
    'How many rays are on the crown of the Statue of Liberty?',
    'How many books are estimated to be housed in the Library of Congress?',
    'How many different words did Shakespeare use across his entire body of work?',
    'How many words are contained in the complete works of William Shakespeare?',
    'How many text messages does the average teenager send per day?',
    'How many countries are in the world (UN members)?'
  )
);

update public.questions
set access_tier='starter'
where is_active=true and category='General' and text_en in (
  'How many artworks are housed in the Louvre Museum collection?',
  'How many floors does the Empire State Building have?',
  'How many pieces make up the world''s largest jigsaw puzzle ever assembled?',
  'How many hours per year does the average American spend commuting to work?'
);

update public.questions
set is_active=false
where is_active=true and category='Sports' and access_tier='premium' and (
  coalesce(source,'') ~* '(rules|laws|specifications|playing conditions|official rule book|equipment|world aquatics swimming program)'
  or text_en in (
    'At 29-all in badminton, how many points wins the game?',
    'After how many points does service normally change in table tennis before 10-all?',
    'How many days are scheduled for a standard men''s Test match?',
    'How many wins did the winningest Formula 1 driver record over his entire career?',
    'How many people can the Camp Nou football stadium hold?'
  )
);

update public.questions set is_active=false
where is_active=true and text_en in (
  'How many mirrors are in the Hall of Mirrors at Versailles?',
  'The biggest pizza ever made weighed about how many pounds?',
  'How many chocolate hearts and boxes are sold in the US for Valentine''s Day?',
  'How many countries took part in the unanimous 2018 vote to redefine the SI?',
  'How many thoracic vertebrae are in the human spine?',
  'About how many kilometers thick is oceanic crust in the USGS simplified Earth model?',
  'About how many kilometers thick is Earth''s liquid outer core?'
);

update public.questions
set text_en='Your DNA contains roughly how many genes?',
    text_tr='DNA''nızda kabaca kaç gen bulunur?',
    source='National Human Genome Research Institute'
where is_active=true
  and text_en='About how many genes are in the human genome according to NHGRI''s DNA fact sheet?';