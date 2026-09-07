do $$
declare
  v_retired integer;
begin
  update public.questions
  set is_active = false
  where access_tier = 'starter'
    and text_en in (
      'How many eggs can a single female octopus lay in one clutch?',
      'How many teeth will a shark grow and lose over its entire lifetime?',
      'How many types of cheese are officially recognized as made in France?',
      'How many provinces are there in Turkey?',
      'How many unique five-card poker hands are possible from a standard deck?',
      'How many words are contained in the complete works of William Shakespeare?',
      'How many tiles cover the roof of the Sydney Opera House?',
      'How many mirrors are in the Hall of Mirrors at Versailles?',
      'How many steps lead to the top of the ancient pyramid of Chichen Itza?',
      'In what year did the Titanic sink?',
      'How many keys are on a standard full-size piano?',
      'How many songs has the band The Beatles officially released?',
      'Approximately how many bones are in the human body?',
      'How many countries participated in the 2020 Tokyo Summer Olympics?',
      'How many home runs did Barry Bonds hit in his entire MLB career?',
      'How many laps are completed in the Indianapolis 500 race?',
      'How many stitches are on the surface of a regulation baseball?',
      'In what year was the first FIFA World Cup held?',
      'What is the length of a football pitch in meters?',
      'How many apps were available on the Apple App Store as of its tenth anniversary?',
      'How many photos has the Hubble Space Telescope taken since its launch?',
      'In what year was Instagram founded?'
    );

  get diagnostics v_retired = row_count;
  if v_retired <> 22 then
    raise exception 'Expected to retire 22 starter questions, retired %', v_retired;
  end if;
end $$;

update public.questions
set answer_unit = 'kilometers per hour'
where access_tier = 'starter'
  and text_en = 'How many kilometers per hour can a peregrine falcon reach while diving?';

update public.questions
set answer_unit = 'countries'
where access_tier = 'starter'
  and text_en = 'How many countries are in the world (UN members)?';

update public.questions
set answer_unit = 'hours'
where access_tier = 'starter'
  and text_en = 'How many hours are in a year?';

update public.questions
set text_en = 'About how many thousand kilometers away is the Moon from Earth?',
    answer_unit = 'thousand kilometers'
where access_tier = 'starter'
  and text_en = 'What is the average distance from the Moon to Earth in thousand km?';