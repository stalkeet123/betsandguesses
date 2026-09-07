update public.questions
set is_active=false
where category='Science' and coalesce(is_active,true) and (
  text_en in (
    'About how many billion base pairs are in one copy of the human genome?',
    'About how many Earth days does the Sun take to rotate once at its equator?',
    'About how many Earth days does the Sun take to rotate once near its poles?',
    'About how many kilometers thick is continental crust on average in the USGS simplified Earth model?',
    'About how many kilometers thick is Earth''s solid inner core?',
    'About how many millibars is typical sea-level atmospheric pressure?',
    'About how many million base pairs long are the smallest human chromosomes?',
    'About how many million base pairs long can the largest human chromosomes be?',
    'About how many nephrons are in each human kidney?',
    'About how many seconds does sunlight take to reach Earth?',
    'About what percentage of dry air is nitrogen?',
    'About what percentage of dry air is oxygen?',
    'At about what depth in meters does NOAA define the deep ocean as beginning?',
    'At least about how many kilometers thick is the lithosphere over much of Earth?',
    'How many chromosomes are in a typical human somatic cell?',
    'How many chromosomes in total does the standard octoploid grocery-store strawberry example have?',
    'How many pairs of autosomes do humans typically have?',
    'How many pairs of cranial nerves are there?',
    'How many pairs of ribs are in the human rib cage?',
    'How many pairs of spinal nerves are there?',
    'How many SI derived units have special names and symbols?',
    'How many vertebrae does the human spine typically have?',
    'How many Voyager spacecraft are currently heading out of the solar system?',
    'What fixed frequency in hertz defines the cesium-133 transition used to define the second?',
    'What is the average weight of an elephant in kg?',
    'Your DNA contains roughly how many genes?'
  )
);