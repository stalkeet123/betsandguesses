-- Retire questions that are too lookup-like, duplicated in feel, or weak for social estimation.
update public.questions
set is_active = false
where access_tier = 'starter'
  and is_active = true
  and text_en in (
    'How many books are estimated to be housed in the Library of Congress?',
    'How many pieces make up the world''s largest jigsaw puzzle ever assembled?',
    'How many bridges are there in the city of Venice, Italy?',
    'How many canals wind through the city of Venice?',
    'How many islands are there in the Philippines?',
    'How many islands make up the country of Indonesia?',
    'How many kilometers of tunnels make up the Paris Catacombs?',
    'How many steps are in the Eiffel Tower?',
    'How many steps must you climb to reach the top of the Statue of Liberty?',
    'How many kilometers does the International Space Station travel in a single day?'
  );

update public.questions
set access_tier = 'starter'
where is_active = true
  and access_tier = 'premium'
  and text_en in (
    'About how many kilograms of bamboo can a giant panda eat in a day?',
    'About how many meters can a tiger leap forward?',
    'How many meters long was the world''s longest sandwich ever made?',
    'Approximately how many meters above sea level is the summit of Mount Fuji?',
    'How many tons did the Titanic weigh?',
    'How many years did it take to build the Great Wall of China across all dynasties?',
    'About how many million US dollars has Avengers: Infinity War grossed worldwide?',
    'About how many million US dollars has The Lion King from 2019 grossed worldwide?',
    'About how many minutes long is Goodfellas?',
    'How many acts performed at the 1969 Woodstock festival?',
    'How many hours does the average person spend sleeping over their entire lifetime?',
    'About how many days does a normal human red blood cell live?',
    'About what percentage of Earth''s water is contained in the ocean?',
    'How many videos are uploaded to YouTube every minute?'
  );

update public.questions set text_en = 'A giant panda can eat about how many pounds of bamboo in one day?', answer = 26, answer_unit = 'pounds' where text_en = 'About how many kilograms of bamboo can a giant panda eat in a day?';
update public.questions set text_en = 'A tiger can leap forward about how many feet?', answer = 33, answer_unit = 'feet' where text_en = 'About how many meters can a tiger leap forward?';
update public.questions set text_en = 'The world''s longest sandwich stretched about how many feet?', answer = 623, answer_unit = 'feet' where text_en = 'How many meters long was the world''s longest sandwich ever made?';
update public.questions set text_en = 'Mount Fuji rises about how many feet above sea level?', answer = 12388, answer_unit = 'feet' where text_en = 'Approximately how many meters above sea level is the summit of Mount Fuji?';
update public.questions set text_en = 'The Titanic weighed roughly how many tons?', answer_unit = 'tons' where text_en = 'How many tons did the Titanic weigh?';
update public.questions set text_en = 'Across all the dynasties that worked on it, the Great Wall was built over roughly how many years?' where text_en = 'How many years did it take to build the Great Wall of China across all dynasties?';
update public.questions set text_en = 'About how many million dollars did Avengers: Infinity War make worldwide?' where text_en = 'About how many million US dollars has Avengers: Infinity War grossed worldwide?';
update public.questions set text_en = 'About how many million dollars did The Lion King (2019) make worldwide?' where text_en = 'About how many million US dollars has The Lion King from 2019 grossed worldwide?';
update public.questions set text_en = 'Goodfellas runs for about how many minutes?' where text_en = 'About how many minutes long is Goodfellas?';
update public.questions set text_en = 'How many different acts played at the original Woodstock festival in 1969?', answer_unit = 'acts' where text_en = 'How many acts performed at the 1969 Woodstock festival?';
update public.questions set text_en = 'Over an average lifetime, about how many hours does a person spend asleep?', answer_unit = 'hours' where text_en = 'How many hours does the average person spend sleeping over their entire lifetime?';
update public.questions set text_en = 'A red blood cell usually lasts about how many days before your body replaces it?' where text_en = 'About how many days does a normal human red blood cell live?';
update public.questions set text_en = 'About what percent of all the water on Earth is in the oceans?' where text_en = 'About what percentage of Earth''s water is contained in the ocean?';
update public.questions set text_en = 'About how many hours of video get uploaded to YouTube every minute?', answer = 500, answer_unit = 'hours of video' where text_en = 'How many videos are uploaded to YouTube every minute?';

update public.questions set text_en = 'A queen bee can lay about how many eggs in one day?', answer_unit = 'eggs' where text_en = 'How many eggs does a queen honeybee lay in a single day?';
update public.questions set text_en = 'Monarch butterflies can migrate about how many miles in a year?', answer = 2500, answer_unit = 'miles' where text_en = 'How many kilometers do monarch butterflies migrate during their annual journey?';
update public.questions set text_en = 'A peregrine falcon can hit about what speed in a dive?', answer = 242, answer_unit = 'miles per hour' where text_en = 'How many kilometers per hour can a peregrine falcon reach while diving?';
update public.questions set text_en = 'About how many muscles are packed into an elephant''s trunk?', answer_unit = 'muscles' where text_en = 'How many muscles are there in an elephant''s trunk?';
update public.questions set text_en = 'A great white shark has roughly how many teeth in its mouth at once?', answer_unit = 'teeth' where text_en = 'How many teeth does a great white shark have in its mouth at any given time?';
update public.questions set text_en = 'A hovering hummingbird beats its wings about how many times per second?', answer_unit = 'wing beats per second' where text_en = 'How many wing beats per second does a hummingbird make while hovering?';
update public.questions set text_en = 'A giant tortoise can live for about how many years?' where text_en = 'How many years can a giant tortoise live in the wild?';
update public.questions set text_en = 'A lobster can live for roughly how many years?' where text_en = 'How many years can a lobster live in the wild?';
update public.questions set text_en = 'Roughly how many coffee beans go into one espresso shot?', answer_unit = 'coffee beans' where text_en = 'How many coffee beans does it take to make a standard espresso shot?';
update public.questions set text_en = 'About how many grains of rice are in a 2.2-pound bag?', answer_unit = 'grains of rice' where text_en = 'How many grains of rice are in a typical one kilogram bag?';
update public.questions set text_en = 'The heaviest pumpkin ever recorded weighed about how many pounds?', answer = 2703, answer_unit = 'pounds' where text_en = 'How many kilograms did the world''s heaviest pumpkin weigh?';
update public.questions set text_en = 'The biggest pizza ever made weighed about how many pounds?', answer = 42004, answer_unit = 'pounds' where text_en = 'How many kilograms did the largest pizza ever made weigh?';
update public.questions set text_en = 'About how many babies are born worldwide on a typical day?' where text_en = 'How many babies are born around the world every single day?';
update public.questions set text_en = 'Exactly how many hours are in a 365-day year?' where text_en = 'How many hours are in a year?';
update public.questions set text_en = 'About how many pounds of confetti fall in Times Square on New Year''s Eve?', answer = 2200, answer_unit = 'pounds' where text_en = 'How many kilograms of confetti are used at a Times Square New Year''s Eve celebration?';
update public.questions set text_en = 'About how many lights cover the Rockefeller Center Christmas tree each year?', answer_unit = 'lights' where text_en = 'How many light bulbs are used to decorate the Rockefeller Center Christmas tree each year?';
update public.questions set text_en = 'The Amazon River runs for roughly how many miles?', answer = 4000, answer_unit = 'miles' where text_en = 'How many kilometers does the Amazon River stretch from source to mouth?';
update public.questions set text_en = 'The Nile runs for roughly how many miles?', answer = 4130, answer_unit = 'miles' where text_en = 'How many kilometers long is the Nile River from its farthest source to the Mediterranean Sea?';
update public.questions set text_en = 'The Trans-Siberian Railway stretches about how many miles?', answer = 5772, answer_unit = 'miles' where text_en = 'How many kilometers long is the Trans-Siberian Railway?';
update public.questions set text_en = 'At its deepest point, the Mariana Trench is about how many feet deep?', answer = 35876, answer_unit = 'feet' where text_en = 'How many meters deep is the Mariana Trench at its lowest point?';
update public.questions set text_en = 'Angel Falls drops about how many feet from top to bottom?', answer = 3212, answer_unit = 'feet' where text_en = 'How many meters tall is Angel Falls, the world''s tallest waterfall?';
update public.questions set text_en = 'The Burj Khalifa is about how many feet tall?', answer = 2717, answer_unit = 'feet' where text_en = 'How many meters tall is the Burj Khalifa?';
update public.questions set text_en = 'Mount Everest is about how many feet above sea level?', answer = 29032, answer_unit = 'feet' where text_en = 'What is the height of Mount Everest in meters?';
update public.questions set text_en = 'The Great Wall of China stretches about how many miles when all its branches are counted?', answer = 13170, answer_unit = 'miles' where text_en = 'How many kilometers long is the Great Wall of China including all branches?';
update public.questions set text_en = 'About how many people were on the Titanic for its first and only voyage?' where text_en = 'How many people were aboard the Titanic on its maiden voyage?';
update public.questions set text_en = 'About how many life-size figures make up China''s Terracotta Army?', answer_unit = 'figures' where text_en = 'How many soldiers were buried with the Terracotta Army in China?';
update public.questions set text_en = 'About how many miles does a Tour de France rider cover over the whole race?', answer = 2200, answer_unit = 'miles' where text_en = 'How many kilometers does a Tour de France cyclist ride over the entire race?';
update public.questions set text_en = 'A Formula 1 car can hit about what top speed on a straight?', answer = 230, answer_unit = 'miles per hour' where text_en = 'How many kilometers per hour can a Formula 1 car reach at top speed on a straight?';
update public.questions set text_en = 'The fastest pro tennis serves reach about what speed?', answer = 163, answer_unit = 'miles per hour' where text_en = 'How many kilometers per hour can a professional tennis serve reach at its fastest recorded speed?';
update public.questions set text_en = 'An Olympic-size swimming pool holds about how many gallons of water?', answer = 660000, answer_unit = 'gallons' where text_en = 'How many liters of water are in an Olympic-size swimming pool?';
update public.questions set text_en = 'About how far is the Moon from Earth?', answer = 239000, answer_unit = 'miles' where text_en = 'About how many thousand kilometers away is the Moon from Earth?';
update public.questions set text_en = 'If you stretched out all the blood vessels in one human body, about how many miles would they cover?', answer = 60000, answer_unit = 'miles' where text_en = 'How many kilometers of blood vessels are in the human body?';
update public.questions set text_en = 'About how many miles of wiring are packed inside a Boeing 747?', answer = 170, answer_unit = 'miles' where text_en = 'How many kilometers of wiring are inside a Boeing 747 airplane?';
update public.questions set text_en = 'A jumbo jet can burn roughly how many gallons of fuel on a transatlantic flight?', answer = 40000, answer_unit = 'gallons' where text_en = 'How many liters of fuel does a jumbo jet burn on a transatlantic flight?';
update public.questions set text_en = 'The longest ship ever built was about how many feet long?', answer = 1504, answer_unit = 'feet' where text_en = 'How many meters long was the longest ship ever built?';
update public.questions set text_en = 'About how many miles of undersea cable carry most of the world''s internet traffic?', answer = 870000, answer_unit = 'miles' where text_en = 'How many kilometers of undersea cable carry the world''s internet traffic?';
update public.questions set text_en = 'About how many individual parts make up a Boeing 747?', answer_unit = 'parts' where text_en = 'How many parts make up a Boeing 747 airplane?';

with new_questions(text_tr, text_en, answer, answer_unit, category, difficulty, source, access_tier, is_active) as (
  values
    ('Yetişkin bir köpeğin kaç dişi vardır?', 'How many teeth does an adult dog have?', 42::bigint, 'teeth', 'Animals', 2, 'American Kennel Club', 'starter', true),
    ('Tipik bir mısır koçanında yaklaşık kaç tane mısır tanesi vardır?', 'A typical ear of corn has about how many kernels?', 800::bigint, 'kernels', 'Food', 2, 'Iowa Corn Growers Association', 'starter', true),
    ('12 onsluk bir Coca-Cola kutusunda kaç gram şeker vardır?', 'How many grams of sugar are in a 12-ounce can of Coca-Cola?', 39::bigint, 'grams of sugar', 'Food', 2, 'The Coca-Cola Company', 'starter', true),
    ('Bir günde tam olarak kaç saniye vardır?', 'Exactly how many seconds are in one day?', 86400::bigint, 'seconds', 'General', 2, 'calendar arithmetic', 'starter', true),
    ('Bir haftada tam olarak kaç dakika vardır?', 'Exactly how many minutes are in one week?', 10080::bigint, 'minutes', 'General', 2, 'calendar arithmetic', 'starter', true),
    ('Büyük Kanyon yaklaşık kaç mil uzunluğundadır?', 'The Grand Canyon is about how many miles long?', 277::bigint, 'miles', 'Geography', 2, 'US National Park Service', 'starter', true),
    ('Death Valley''deki Badwater Basin deniz seviyesinin kaç feet altındadır?', 'Death Valley''s Badwater Basin sits how many feet below sea level?', 282::bigint, 'feet below sea level', 'Geography', 2, 'US National Park Service', 'starter', true),
    ('Ay''da toplam kaç insan yürümüştür?', 'How many people have walked on the Moon?', 12::bigint, 'people', 'History', 2, 'NASA', 'starter', true),
    ('Titanic kaç Oscar kazanmıştır?', 'How many Academy Awards did Titanic win?', 11::bigint, 'Academy Awards', 'Movies', 2, 'Academy Awards', 'starter', true),
    ('The Godfather filmi yaklaşık kaç dakika sürer?', 'The Godfather runs for about how many minutes?', 175::bigint, 'minutes', 'Movies', 2, 'American Film Institute', 'starter', true),
    ('Marvel''ın Infinity Saga serisinde toplam kaç film vardır?', 'How many movies are in Marvel''s Infinity Saga?', 23::bigint, 'movies', 'Movies', 2, 'Marvel', 'starter', true),
    ('Güneş ışığının Dünya''ya ulaşması yaklaşık kaç dakika sürer?', 'About how many minutes does sunlight take to reach Earth?', 8::bigint, 'minutes', 'Science', 2, 'NASA', 'starter', true),
    ('Deniz seviyesinde hava her inç kareye yaklaşık kaç pound basınç uygular?', 'At sea level, the air presses down with about how many pounds per square inch?', 15::bigint, 'psi', 'Science', 3, 'NOAA', 'starter', true),
    ('MLB tarihinde kaydedilen en hızlı atış yaklaşık saatte kaç mildir?', 'The fastest pitch recorded in MLB was about how many miles per hour?', 106::bigint, 'miles per hour', 'Sports', 2, 'MLB Statcast', 'starter', true),
    ('Bir Boeing 747-400 tam dolu yakıtla yaklaşık kaç galon yakıt taşır?', 'A Boeing 747-400 can carry roughly how many gallons of usable fuel?', 57300::bigint, 'gallons', 'Technology', 3, 'Boeing 747-400 Airport Planning', 'starter', true)
)
insert into public.questions (text_tr, text_en, answer, answer_unit, category, difficulty, source, access_tier, is_active)
select nq.* from new_questions nq
where not exists (
  select 1 from public.questions q where lower(btrim(q.text_en)) = lower(btrim(nq.text_en))
);