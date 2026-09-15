update public.questions
set is_active=false
where is_active=true and (
  (category='Food' and text_en in (
    'About how many grams are in one standard U.S. stick of butter?',
    'How many grams of dry yeast are typically in one standard U.S. active-dry-yeast packet?',
    'How many hot dogs did the winner eat at Nathan''s Hot Dog Eating Contest in 2023?'
  ))
  or (category='General' and (
    text_en ilike '%standard deck%'
    or text_en ilike '%backgammon%'
    or text_en ilike '%board at the start of a chess game%'
    or text_en ilike '%alphabet%'
    or text_en ilike '%Gregorian calendar%'
    or text_en='How many pounds are in one imperial stone?'
    or text_en ilike 'How many US %'
  ))
  or (category='Science' and (
    text_en ilike 'About how many kilometers is % radius?'
    or text_en ilike 'About how many kilometers is % diameter?'
    or text_en ilike 'About how many kilometers is % equatorial diameter?'
    or text_en ilike 'About how many million kilometers is % from the Sun on average?'
  ))
  or (category='Sports' and access_tier='premium' and (
    text_en ilike '%regulation%'
    or text_en ilike '%specified by%'
    or text_en ilike '%technical rules%'
    or text_en ilike '%official rules%'
    or text_en ilike '%playing conditions%'
    or text_en ilike '%equipment specifications%'
    or text_en ilike '%penalty strokes%'
    or text_en ilike '%tie-break%'
    or text_en ilike '%advance the ball from the backcourt%'
    or text_en ilike '%water jumps%'
    or text_en ilike '%outs does one team record%'
  ))
  or (category='Technology' and text_en='How many transistors did Apple state the original M1 chip contained in billions?')
  or (category='Animals' and text_en='How many rings does a bristlecone pine grow in its lifetime of about 4800 years, one per year?')
  or (category='Sports' and text_en='How many goals did Cristiano Ronaldo score in official club and international matches combined by 2024?')
);