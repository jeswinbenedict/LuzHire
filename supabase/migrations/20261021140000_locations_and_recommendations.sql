-- LuzHire · Phase 11 · Where hiring happens, and jobs picked for you.
--   cities              a small gazetteer (Indian cities and global tech hubs)
--   jobs.city_id/lat/lng set by a trigger from location_text
--   hiring_locations    open roles per city, for the map
--   jobs_near()         jobs within a radius of a point, nearest first
--   recommended_jobs()  jobs ranked for the signed-in candidate, with reasons
-- No PostGIS: distances use the haversine formula.

create table public.cities (
  id           serial primary key,
  name         text not null,
  state        text,
  country_code char(2) not null,
  latitude     double precision not null check (latitude between -90 and 90),
  longitude    double precision not null check (longitude between -180 and 180),
  population   int not null default 0,
  aliases      text[] not null default '{}',
  unique (name, country_code),
  -- Matched as regular-expression words by app.city_in().
  check (lower(name) ~ '^[a-zà-ÿ .''-]+$'),
  check (array_to_string(aliases, ',') ~ '^[a-zà-ÿ ,.-]*$')
);
alter table public.cities enable row level security;
create policy cities_select on public.cities for select to anon, authenticated using (true);

-- Population in thousands (approximate) only orders ambiguous matches.
insert into public.cities (name, state, country_code, latitude, longitude, population, aliases) values
  ('Mumbai', 'Maharashtra', 'IN', 19.076, 72.8777, 20400, '{bombay}'),
  ('Delhi', 'Delhi', 'IN', 28.6139, 77.209, 31000, '{new delhi,ncr,delhi ncr}'),
  ('Bengaluru', 'Karnataka', 'IN', 12.9716, 77.5946, 12700, '{bangalore,blr}'),
  ('Hyderabad', 'Telangana', 'IN', 17.385, 78.4867, 10300, '{secunderabad,hitec city}'),
  ('Chennai', 'Tamil Nadu', 'IN', 13.0827, 80.2707, 11300, '{madras}'),
  ('Kolkata', 'West Bengal', 'IN', 22.5726, 88.3639, 15100, '{calcutta}'),
  ('Pune', 'Maharashtra', 'IN', 18.5204, 73.8567, 6800, '{pimpri-chinchwad,hinjewadi}'),
  ('Ahmedabad', 'Gujarat', 'IN', 23.0225, 72.5714, 8400, '{}'),
  ('Gurugram', 'Haryana', 'IN', 28.4595, 77.0266, 1500, '{gurgaon}'),
  ('Noida', 'Uttar Pradesh', 'IN', 28.5355, 77.391, 800, '{greater noida}'),
  ('Jaipur', 'Rajasthan', 'IN', 26.9124, 75.7873, 4100, '{}'),
  ('Lucknow', 'Uttar Pradesh', 'IN', 26.8467, 80.9462, 3800, '{}'),
  ('Surat', 'Gujarat', 'IN', 21.1702, 72.8311, 7800, '{}'),
  ('Kanpur', 'Uttar Pradesh', 'IN', 26.4499, 80.3319, 3200, '{}'),
  ('Nagpur', 'Maharashtra', 'IN', 21.1458, 79.0882, 2900, '{}'),
  ('Indore', 'Madhya Pradesh', 'IN', 22.7196, 75.8577, 3300, '{}'),
  ('Bhopal', 'Madhya Pradesh', 'IN', 23.2599, 77.4126, 2500, '{}'),
  ('Visakhapatnam', 'Andhra Pradesh', 'IN', 17.6868, 83.2185, 2300, '{vizag}'),
  ('Vijayawada', 'Andhra Pradesh', 'IN', 16.5062, 80.648, 1800, '{}'),
  ('Patna', 'Bihar', 'IN', 25.5941, 85.1376, 2500, '{}'),
  ('Vadodara', 'Gujarat', 'IN', 22.3072, 73.1812, 2200, '{baroda}'),
  ('Ludhiana', 'Punjab', 'IN', 30.901, 75.8573, 1900, '{}'),
  ('Chandigarh', 'Chandigarh', 'IN', 30.7333, 76.7794, 1200, '{mohali,panchkula}'),
  ('Coimbatore', 'Tamil Nadu', 'IN', 11.0168, 76.9558, 2900, '{}'),
  ('Kochi', 'Kerala', 'IN', 9.9312, 76.2673, 2200, '{cochin,ernakulam,kakkanad}'),
  ('Thiruvananthapuram', 'Kerala', 'IN', 8.5241, 76.9366, 1700, '{trivandrum,technopark}'),
  ('Kozhikode', 'Kerala', 'IN', 11.2588, 75.7804, 2100, '{calicut}'),
  ('Mysuru', 'Karnataka', 'IN', 12.2958, 76.6394, 1100, '{mysore}'),
  ('Mangaluru', 'Karnataka', 'IN', 12.9141, 74.856, 700, '{mangalore}'),
  ('Hubballi', 'Karnataka', 'IN', 15.3647, 75.124, 1000, '{hubli,dharwad}'),
  ('Madurai', 'Tamil Nadu', 'IN', 9.9252, 78.1198, 1600, '{}'),
  ('Tiruchirappalli', 'Tamil Nadu', 'IN', 10.7905, 78.7047, 1100, '{trichy}'),
  ('Salem', 'Tamil Nadu', 'IN', 11.6643, 78.146, 1000, '{}'),
  ('Tirunelveli', 'Tamil Nadu', 'IN', 8.7139, 77.7567, 500, '{}'),
  ('Vellore', 'Tamil Nadu', 'IN', 12.9165, 79.1325, 600, '{}'),
  ('Nashik', 'Maharashtra', 'IN', 19.9975, 73.7898, 2100, '{}'),
  ('Aurangabad', 'Maharashtra', 'IN', 19.8762, 75.3433, 1500, '{chhatrapati sambhajinagar}'),
  ('Kolhapur', 'Maharashtra', 'IN', 16.705, 74.2433, 600, '{}'),
  ('Rajkot', 'Gujarat', 'IN', 22.3039, 70.8022, 2000, '{}'),
  ('Gandhinagar', 'Gujarat', 'IN', 23.2156, 72.6369, 300, '{gift city}'),
  ('Jodhpur', 'Rajasthan', 'IN', 26.2389, 73.0243, 1500, '{}'),
  ('Udaipur', 'Rajasthan', 'IN', 24.5854, 73.7125, 600, '{}'),
  ('Kota', 'Rajasthan', 'IN', 25.2138, 75.8648, 1200, '{}'),
  ('Agra', 'Uttar Pradesh', 'IN', 27.1767, 78.0081, 1800, '{}'),
  ('Varanasi', 'Uttar Pradesh', 'IN', 25.3176, 82.9739, 1600, '{banaras}'),
  ('Prayagraj', 'Uttar Pradesh', 'IN', 25.4358, 81.8463, 1500, '{allahabad}'),
  ('Ghaziabad', 'Uttar Pradesh', 'IN', 28.6692, 77.4538, 2400, '{}'),
  ('Meerut', 'Uttar Pradesh', 'IN', 28.9845, 77.7064, 1500, '{}'),
  ('Faridabad', 'Haryana', 'IN', 28.4089, 77.3178, 1800, '{}'),
  ('Dehradun', 'Uttarakhand', 'IN', 30.3165, 78.0322, 800, '{}'),
  ('Amritsar', 'Punjab', 'IN', 31.634, 74.8723, 1200, '{}'),
  ('Jalandhar', 'Punjab', 'IN', 31.326, 75.5762, 900, '{}'),
  ('Srinagar', 'Jammu and Kashmir', 'IN', 34.0837, 74.7973, 1300, '{}'),
  ('Jammu', 'Jammu and Kashmir', 'IN', 32.7266, 74.857, 700, '{}'),
  ('Shimla', 'Himachal Pradesh', 'IN', 31.1048, 77.1734, 200, '{}'),
  ('Raipur', 'Chhattisgarh', 'IN', 21.2514, 81.6296, 1200, '{}'),
  ('Ranchi', 'Jharkhand', 'IN', 23.3441, 85.3096, 1200, '{}'),
  ('Jamshedpur', 'Jharkhand', 'IN', 22.8046, 86.2029, 1400, '{}'),
  ('Bhubaneswar', 'Odisha', 'IN', 20.2961, 85.8245, 1100, '{}'),
  ('Cuttack', 'Odisha', 'IN', 20.4625, 85.883, 700, '{}'),
  ('Guwahati', 'Assam', 'IN', 26.1445, 91.7362, 1100, '{}'),
  ('Shillong', 'Meghalaya', 'IN', 25.5788, 91.8933, 400, '{}'),
  ('Imphal', 'Manipur', 'IN', 24.817, 93.9368, 300, '{}'),
  ('Agartala', 'Tripura', 'IN', 23.8315, 91.2868, 500, '{}'),
  ('Gangtok', 'Sikkim', 'IN', 27.3389, 88.6065, 100, '{}'),
  ('Siliguri', 'West Bengal', 'IN', 26.7271, 88.3953, 700, '{}'),
  ('Durgapur', 'West Bengal', 'IN', 23.5204, 87.3119, 600, '{}'),
  ('Panaji', 'Goa', 'IN', 15.4909, 73.8278, 100, '{goa,panjim,margao,vasco da gama}'),
  ('Puducherry', 'Puducherry', 'IN', 11.9416, 79.8083, 700, '{pondicherry}'),
  ('Tirupati', 'Andhra Pradesh', 'IN', 13.6288, 79.4192, 500, '{}'),
  ('Guntur', 'Andhra Pradesh', 'IN', 16.3067, 80.4365, 800, '{}'),
  ('Warangal', 'Telangana', 'IN', 17.9689, 79.5941, 800, '{}'),
  ('Gwalior', 'Madhya Pradesh', 'IN', 26.2183, 78.1828, 1100, '{}'),
  ('Jabalpur', 'Madhya Pradesh', 'IN', 23.1815, 79.9864, 1300, '{}'),
  ('Bhilai', 'Chhattisgarh', 'IN', 21.1938, 81.3509, 1000, '{durg}'),
  ('Belagavi', 'Karnataka', 'IN', 15.8497, 74.4977, 600, '{belgaum}'),
  ('Manipal', 'Karnataka', 'IN', 13.3525, 74.7928, 50, '{udupi}'),
  ('Thrissur', 'Kerala', 'IN', 10.5276, 76.2144, 900, '{trichur}'),
  ('Kollam', 'Kerala', 'IN', 8.8932, 76.6141, 400, '{quilon}'),
  ('Hosur', 'Tamil Nadu', 'IN', 12.7409, 77.8253, 300, '{}'),
  ('Erode', 'Tamil Nadu', 'IN', 11.341, 77.7172, 500, '{}'),
  ('Sriperumbudur', 'Tamil Nadu', 'IN', 12.9675, 79.9419, 50, '{}'),
  ('Navi Mumbai', 'Maharashtra', 'IN', 19.033, 73.0297, 1200, '{}'),
  ('Thane', 'Maharashtra', 'IN', 19.2183, 72.9781, 1900, '{}'),
  -- Global hubs where remote-first and international jobs are based.
  ('Singapore', null, 'SG', 1.3521, 103.8198, 5900, '{}'),
  ('Dubai', null, 'AE', 25.2048, 55.2708, 3600, '{}'),
  ('Abu Dhabi', null, 'AE', 24.4539, 54.3773, 1500, '{}'),
  ('Riyadh', null, 'SA', 24.7136, 46.6753, 7500, '{}'),
  ('Doha', null, 'QA', 25.2854, 51.531, 1200, '{}'),
  ('London', null, 'GB', 51.5074, -0.1278, 9000, '{}'),
  ('Manchester', null, 'GB', 53.4808, -2.2426, 2800, '{}'),
  ('Dublin', null, 'IE', 53.3498, -6.2603, 1400, '{}'),
  ('Berlin', null, 'DE', 52.52, 13.405, 3700, '{}'),
  ('Munich', null, 'DE', 48.1351, 11.582, 1500, '{münchen}'),
  ('Amsterdam', null, 'NL', 52.3676, 4.9041, 900, '{}'),
  ('Paris', null, 'FR', 48.8566, 2.3522, 11000, '{}'),
  ('Barcelona', null, 'ES', 41.3874, 2.1686, 5600, '{}'),
  ('Madrid', null, 'ES', 40.4168, -3.7038, 6700, '{}'),
  ('Lisbon', null, 'PT', 38.7223, -9.1393, 2900, '{}'),
  ('Warsaw', null, 'PL', 52.2297, 21.0122, 1800, '{}'),
  ('Stockholm', null, 'SE', 59.3293, 18.0686, 1600, '{}'),
  ('Zurich', null, 'CH', 47.3769, 8.5417, 1400, '{zürich}'),
  ('Tel Aviv', null, 'IL', 32.0853, 34.7818, 4000, '{}'),
  ('New York', 'New York', 'US', 40.7128, -74.006, 19000, '{nyc,new york city}'),
  ('San Francisco', 'California', 'US', 37.7749, -122.4194, 4700, '{bay area,sf}'),
  ('San Jose', 'California', 'US', 37.3382, -121.8863, 2000, '{silicon valley}'),
  ('Los Angeles', 'California', 'US', 34.0522, -118.2437, 13000, '{}'),
  ('Seattle', 'Washington', 'US', 47.6062, -122.3321, 4000, '{}'),
  ('Austin', 'Texas', 'US', 30.2672, -97.7431, 2300, '{}'),
  ('Boston', 'Massachusetts', 'US', 42.3601, -71.0589, 4900, '{}'),
  ('Chicago', 'Illinois', 'US', 41.8781, -87.6298, 9500, '{}'),
  ('Toronto', 'Ontario', 'CA', 43.6532, -79.3832, 6200, '{}'),
  ('Vancouver', 'British Columbia', 'CA', 49.2827, -123.1207, 2600, '{}'),
  ('Sydney', 'New South Wales', 'AU', -33.8688, 151.2093, 5300, '{}'),
  ('Melbourne', 'Victoria', 'AU', -37.8136, 144.9631, 5100, '{}'),
  ('Tokyo', null, 'JP', 35.6762, 139.6503, 37000, '{}'),
  ('Kuala Lumpur', null, 'MY', 3.139, 101.6869, 8400, '{}'),
  ('Manila', null, 'PH', 14.5995, 120.9842, 14000, '{metro manila}'),
  ('Jakarta', null, 'ID', -6.2088, 106.8456, 11000, '{}'),
  ('Ho Chi Minh City', null, 'VN', 10.8231, 106.6297, 9300, '{saigon}'),
  ('Colombo', null, 'LK', 6.9271, 79.8612, 750, '{}'),
  ('Dhaka', null, 'BD', 23.8103, 90.4125, 22000, '{}'),
  ('Kathmandu', null, 'NP', 27.7172, 85.324, 1500, '{}'),
  ('Lagos', null, 'NG', 6.5244, 3.3792, 15000, '{}'),
  ('Nairobi', null, 'KE', -1.2921, 36.8219, 4700, '{}'),
  ('Cape Town', null, 'ZA', -33.9249, 18.4241, 4700, '{}'),
  ('São Paulo', null, 'BR', -23.5505, -46.6333, 22000, '{sao paulo}'),
  ('Mexico City', null, 'MX', 19.4326, -99.1332, 21800, '{cdmx}'),
  ('Buenos Aires', null, 'AR', -34.6037, -58.3816, 15000, '{}');

-- ---------------------------------------------------------------- geocoding
-- The city named in free text ("Hybrid - Bengaluru, IN"), by whole words.
-- The longest name wins ("Navi Mumbai" over "Mumbai"), then the larger city.
-- Remote-only text matches nothing.
create or replace function app.city_in(place text)
returns int
language sql stable
set search_path = public, pg_temp
as $$
  select c.id
  from public.cities c,
       lateral (
         select max(length(n)) as len
         from unnest(array_prepend(lower(c.name), c.aliases)) n
         -- Names and aliases are plain words (see the checks on cities).
         where lower(place) ~ ('(^|[^a-z])' || n || '($|[^a-z])')
       ) m
  where coalesce(trim(place), '') <> '' and m.len is not null
  order by m.len desc, c.population desc, c.id
  limit 1
$$;

alter table public.jobs
  add column city_id   int references public.cities on delete set null,
  add column latitude  double precision,
  add column longitude double precision;
create index jobs_city_idx on public.jobs (city_id) where status = 'published';

-- Runs as the caller like the other job triggers; reads only public cities.
create or replace function app.jobs_geocode()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' or new.location_text is distinct from old.location_text then
    new.city_id := app.city_in(new.location_text);
    select c.latitude, c.longitude into new.latitude, new.longitude
    from public.cities c where c.id = new.city_id;
    if new.city_id is null then
      new.latitude := null;
      new.longitude := null;
    end if;
  end if;
  return new;
end
$$;
create trigger jobs_geocode before insert or update of location_text on public.jobs
  for each row execute function app.jobs_geocode();

update public.jobs j
set city_id = c.id, latitude = c.latitude, longitude = c.longitude
from public.cities c
where c.id = app.city_in(j.location_text);

-- Great-circle distance in km.
create or replace function app.distance_km(lat1 double precision, lng1 double precision,
                                           lat2 double precision, lng2 double precision)
returns double precision
language sql immutable
as $$
  select 2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  ))
$$;

-- ---------------------------------------------------------------- map
create view public.hiring_locations with (security_invoker = true) as
  select c.id as city_id, c.name, c.state, c.country_code, c.latitude, c.longitude,
         count(j.id)::int as open_jobs,
         count(distinct lower(j.company_name))::int as companies
  from public.cities c
  join public.jobs j on j.city_id = c.id and j.status = 'published'
  group by c.id;
grant select on public.hiring_locations to anon, authenticated;

-- ---------------------------------------------------------------- near me
create function public.jobs_near(
  lat        double precision,
  lng        double precision,
  radius_km  double precision default 50,
  page_size  int default 20
)
returns table (
  id uuid, source public.job_source, company_id uuid, company_name text,
  company_logo_path text, external_logo_url text, external_source text,
  external_url text, title text, slug text, summary text,
  employment_type public.employment_type, experience_level public.experience_level,
  workplace public.workplace_type, location_text text, salary_min numeric,
  salary_max numeric, salary_currency char(3), salary_period public.salary_period,
  status public.job_status, deadline date, application_count int,
  published_at timestamptz, distance_km double precision
)
language sql stable security invoker
set search_path = public, pg_temp
as $$
  select j.id, j.source, j.company_id, j.company_name,
         (select c.logo_path from public.companies c where c.id = j.company_id),
         j.external_logo_url, j.external_source, j.external_url, j.title, j.slug,
         j.summary, j.employment_type, j.experience_level, j.workplace,
         j.location_text, j.salary_min, j.salary_max, j.salary_currency,
         j.salary_period, j.status, j.deadline, j.application_count,
         j.published_at,
         round(app.distance_km(lat, lng, j.latitude, j.longitude)::numeric, 1)::double precision
  from public.jobs j
  where j.status = 'published'
    and j.latitude is not null
    and lat between -90 and 90 and lng between -180 and 180
    and app.distance_km(lat, lng, j.latitude, j.longitude) <= least(greatest(coalesce(radius_km, 50), 1), 500)
  order by 24, j.published_at desc, j.id
  limit least(greatest(coalesce(page_size, 20), 1), 50)
$$;
grant execute on function public.jobs_near to anon, authenticated;

-- ---------------------------------------------------------------- for you
-- Ranks open jobs for the signed-in user from their profile: shared skills
-- (strongest), headline words in the job, their city (or within 50 km), and
-- freshness. Jobs they applied to are left out. Visitors and empty profiles
-- get the newest jobs. Each row says why it was picked.
create function public.recommended_jobs(page_size int default 12)
returns table (
  id uuid, source public.job_source, company_id uuid, company_name text,
  company_logo_path text, external_logo_url text, external_source text,
  external_url text, title text, slug text, summary text,
  employment_type public.employment_type, experience_level public.experience_level,
  workplace public.workplace_type, location_text text, salary_min numeric,
  salary_max numeric, salary_currency char(3), salary_period public.salary_period,
  status public.job_status, deadline date, application_count int,
  published_at timestamptz, score real, match_reasons text[]
)
language sql stable security invoker
set search_path = public, pg_temp
as $$
  with me as (
    select p.id, p.headline,
           (select c.id from public.cities c where c.id = app.city_in(p.location)) as city_id
    from public.profiles p where p.id = app.uid()
  ),
  my_skills as (
    select ps.skill_id from public.profile_skills ps, me where ps.user_id = me.id
  ),
  home as (
    select c.* from public.cities c, me where c.id = me.city_id
  ),
  scored as (
    select j.*,
           (select count(*) from public.job_skills js
            where js.job_id = j.id and js.skill_id in (select skill_id from my_skills))::int as skills_matched,
           coalesce((select nullif(trim(me.headline), '') is not null
                       and j.search @@ plainto_tsquery('english', me.headline) from me), false) as headline_match,
           (select case
                     when j.city_id = home.id then 'in'
                     when j.latitude is not null
                          and app.distance_km(home.latitude, home.longitude, j.latitude, j.longitude) <= 50 then 'near'
                   end
            from home) as place_match,
           (select home.name from home) as home_name
    from public.jobs j
    where j.status = 'published'
      and not exists (
        select 1 from public.applications a
        where a.job_id = j.id and a.candidate_id = app.uid()
      )
  )
  select s.id, s.source, s.company_id, s.company_name,
         (select c.logo_path from public.companies c where c.id = s.company_id),
         s.external_logo_url, s.external_source, s.external_url, s.title, s.slug,
         s.summary, s.employment_type, s.experience_level, s.workplace,
         s.location_text, s.salary_min, s.salary_max, s.salary_currency,
         s.salary_period, s.status, s.deadline, s.application_count, s.published_at,
         (3 * least(s.skills_matched, 5)
          + case when s.headline_match then 2 else 0 end
          + case s.place_match when 'in' then 2 when 'near' then 1.5 else 0 end
          + case when s.published_at > now() - interval '3 days' then 1
                 when s.published_at > now() - interval '7 days' then 0.5 else 0 end)::real,
         array_remove(array[
           case when s.skills_matched = 1 then 'Matches 1 of your skills'
                when s.skills_matched > 1 then 'Matches ' || s.skills_matched || ' of your skills' end,
           case when s.headline_match then 'Fits your headline' end,
           case s.place_match when 'in' then 'In ' || s.home_name
                              when 'near' then 'Near ' || s.home_name end,
           case when s.published_at > now() - interval '3 days' then 'New this week' end
         ], null)
  from scored s
  order by 24 desc, s.published_at desc, s.id
  limit least(greatest(coalesce(page_size, 12), 1), 50)
$$;
grant execute on function public.recommended_jobs to anon, authenticated;
