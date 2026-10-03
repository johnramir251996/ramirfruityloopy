-- Launch cities (open first) + demo creators so the map isn't empty.
-- Prices in PHP. Top spot = slot_index 0.

insert into public.places (id, name, province, region, island_group, kind, tier, lat, lng, slot_count, slot_price_php, top_price_php) values
  ('quezon-city',     'Quezon City',     'Metro Manila',       'NCR',          'Luzon',    'city',         'major', 14.6760, 121.0437, 60, 2000, 10000),
  ('manila',          'Manila',          'Metro Manila',       'NCR',          'Luzon',    'city',         'major', 14.5995, 120.9842, 60, 2000, 10000),
  ('makati',          'Makati',          'Metro Manila',       'NCR',          'Luzon',    'city',         'major', 14.5547, 121.0244, 40, 2500, 12000),
  ('baguio',          'Baguio',          'Benguet',            'CAR',          'Luzon',    'city',         'mid',   16.4023, 120.5960, 25, 1000,  5000),
  ('vigan',           'Vigan',           'Ilocos Sur',         'Region I',     'Luzon',    'city',         'small', 17.5747, 120.3869, 10,  400,  2000),
  ('puerto-princesa', 'Puerto Princesa', 'Palawan',            'MIMAROPA',     'Luzon',    'city',         'mid',    9.7392, 118.7353, 25, 1000,  5000),
  ('cebu-city',       'Cebu City',       'Cebu',               'Region VII',   'Visayas',  'city',         'major', 10.3157, 123.8854, 60, 2000, 10000),
  ('iloilo-city',     'Iloilo City',     'Iloilo',             'Region VI',    'Visayas',  'city',         'mid',   10.7202, 122.5621, 25, 1000,  5000),
  ('bacolod',         'Bacolod',         'Negros Occidental',  'Region VI',    'Visayas',  'city',         'mid',   10.6765, 122.9509, 25, 1000,  5000),
  ('davao-city',      'Davao City',      'Davao del Sur',      'Region XI',    'Mindanao', 'city',         'major',  7.1907, 125.4553, 60, 2000, 10000),
  ('cagayan-de-oro',  'Cagayan de Oro',  'Misamis Oriental',   'Region X',     'Mindanao', 'city',         'mid',    8.4542, 124.6319, 25, 1000,  5000),
  ('general-luna',    'General Luna (Siargao)', 'Surigao del Norte', 'Caraga', 'Mindanao', 'municipality', 'small',  9.7840, 126.1560, 10,  400,  2000);

insert into public.slots (place_id, slot_index, is_top)
select p.id, g.i, g.i = 0
  from public.places p
  cross join lateral generate_series(0, p.slot_count - 1) as g(i);

-- Demo creators (fictional, flagged is_demo so the site labels them)
with demo(display_name, niche, barangay, follower_range, tiktok, youtube, color, place_id, slot_index, verified) as (values
  ('Kusina ni Lola Ising', 'Food',        'Brgy. Teachers Village', '100K-1M',  'https://www.tiktok.com/@demo_lolaising', null, '#E4572E', 'quezon-city', 0, true),
  ('QC Commuter Diaries',  'Lifestyle',   'Brgy. Cubao',            '10K-100K', 'https://www.tiktok.com/@demo_qccommute', null, '#2E86AB', 'quezon-city', 3, false),
  ('Tito Tech PH',         'Tech',        'Brgy. Diliman',          '10K-100K', null, 'https://www.youtube.com/@demo_titotech', '#3D405B', 'quezon-city', 7, true),
  ('Gala sa Maynila',      'Travel',      'Brgy. 659, Intramuros',  '1K-10K',   'https://www.tiktok.com/@demo_galamaynila', null, '#F2A541', 'manila', 0, false),
  ('Binondo Bites',        'Food',        'Brgy. 291, Binondo',     '10K-100K', 'https://www.tiktok.com/@demo_binondobites', null, '#C1292E', 'manila', 2, true),
  ('Makati Hustle',        'Business',    'Brgy. Poblacion',        '1K-10K',   null, 'https://www.youtube.com/@demo_makatihustle', '#1B998B', 'makati', 0, false),
  ('Baguio Fog Walks',     'Travel',      'Brgy. Session Road',     '10K-100K', 'https://www.tiktok.com/@demo_baguiofog', null, '#5C946E', 'baguio', 0, true),
  ('Sugbo Eats',           'Food',        'Brgy. Lahug',            '100K-1M',  'https://www.tiktok.com/@demo_sugboeats', null, '#E76F51', 'cebu-city', 0, true),
  ('Bisdak Gamer',         'Gaming',      'Brgy. Mabolo',           '10K-100K', null, 'https://www.youtube.com/@demo_bisdakgamer', '#6A4C93', 'cebu-city', 4, false),
  ('Cebu Island Hopper',   'Travel',      'Brgy. Guadalupe',        '1K-10K',   'https://www.tiktok.com/@demo_islandhopper', null, '#2A9D8F', 'cebu-city', 9, false),
  ('Ilonggo Vlogs',        'Lifestyle',   'Brgy. Jaro',             '10K-100K', 'https://www.tiktok.com/@demo_ilonggovlogs', null, '#F4A261', 'iloilo-city', 0, true),
  ('MassKara Moves',       'Dance',       'Brgy. Mandalagan',       '1K-10K',   'https://www.tiktok.com/@demo_masskaramoves', null, '#D62246', 'bacolod', 0, false),
  ('Durian Diaries',       'Food',        'Brgy. Poblacion',        '100K-1M',  'https://www.tiktok.com/@demo_duriandiaries', null, '#8AB17D', 'davao-city', 0, true),
  ('Davao Rides',          'Automotive',  'Brgy. Buhangin',         '10K-100K', null, 'https://www.youtube.com/@demo_davaorides', '#264653', 'davao-city', 5, false),
  ('Kagay-anon Adventures','Adventure',   'Brgy. Carmen',           '1K-10K',   'https://www.tiktok.com/@demo_kagayanon', null, '#E9C46A', 'cagayan-de-oro', 0, false),
  ('Surf Siargao Daily',   'Sports',      'Brgy. Catangnan',        '10K-100K', 'https://www.tiktok.com/@demo_surfsiargao', null, '#00A6A6', 'general-luna', 0, true)
), ins as (
  insert into public.creators (display_name, niche, barangay, follower_range, tiktok_url, youtube_url,
                               contact_email, color, status, verified, is_demo)
  select display_name, niche, barangay, follower_range, tiktok, youtube,
         'demo@example.com', color, 'approved', verified, true
    from demo
  returning id, display_name
)
update public.slots s
   set status = 'live', creator_id = ins.id, claimed_at = now()
  from ins join demo d on d.display_name = ins.display_name
 where s.place_id = d.place_id and s.slot_index = d.slot_index;
