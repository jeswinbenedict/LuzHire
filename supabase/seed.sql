-- LuzHire demo seed (local development only, never production).
-- All companies and people are fictional. Demo accounts use "seed-" IDs; real
-- users get Firebase UIDs. Runs as postgres, so moderation triggers treat it as
-- a privileged (system) write.

-- ---------------------------------------------------------------- people
insert into public.profiles (id, role, email, display_name, headline, location, links) values
  ('seed-admin',      'admin',     'admin@luzhire.dev',     'LuzHire Admin',  'Platform administrator', 'Amaravati, IN', '{}'),
  ('seed-candidate',  'candidate', 'candidate@luzhire.dev', 'Asha Verma',     'Flutter developer',      'Bengaluru, IN', '{"github": "https://github.com/example"}'),
  ('seed-candidate2', 'candidate', 'rahul@luzhire.dev',     'Rahul Iyer',     'Data analyst',           'Chennai, IN',   '{}'),
  ('seed-employer',   'employer',  'employer@luzhire.dev',  'Meera Nair',     'Talent lead',            'Hyderabad, IN', '{}'),
  ('seed-employer2',  'employer',  'karthik@luzhire.dev',   'Karthik Rao',    'Founder',                'Pune, IN',      '{}');

insert into public.skills (name, slug)
select s, app.slugify(s)
from unnest(array[
  'Flutter', 'Dart', 'React', 'TypeScript', 'JavaScript', 'Node.js', 'Python', 'Django', 'Java', 'Spring Boot',
  'Kotlin', 'Swift', 'Go', 'Rust', 'SQL', 'PostgreSQL', 'Supabase', 'Firebase', 'AWS', 'GCP',
  'Docker', 'Kubernetes', 'Terraform', 'Machine Learning', 'PyTorch', 'Data Analysis', 'Power BI', 'Figma', 'UI Design', 'UX Research',
  'Product Management', 'Agile', 'Testing', 'Cypress', 'Security', 'Linux', 'Git', 'GraphQL', 'REST APIs', 'Communication'
]) as s;

-- ---------------------------------------------------------------- companies (fictional)
insert into public.companies (id, owner_id, name, slug, description, industry, size_range, website, hq_location, benefits, verification)
select
  ('00000000-0000-4000-a000-' || lpad(i::text, 12, '0'))::uuid,
  case when i % 2 = 0 then 'seed-employer' else 'seed-employer2' end,
  n, app.slugify(n),
  n || ' is a fictional company used for LuzHire demo data.',
  (array['Software', 'Fintech', 'Healthcare', 'Education', 'E-commerce', 'Logistics', 'Media', 'Energy'])[1 + i % 8],
  (array['11-50', '51-200', '201-500', '501-1000', '1001-5000'])[1 + i % 5],
  'https://example.com/' || app.slugify(n),
  (array['Bengaluru, IN', 'Hyderabad, IN', 'Chennai, IN', 'Pune, IN', 'Remote', 'Amaravati, IN'])[1 + i % 6],
  array['Health insurance', 'Flexible hours', 'Learning budget'],
  case when i % 5 = 0 then 'unverified'::public.verification else 'verified'::public.verification end
from unnest(array[
  'Northwind Labs', 'Aster Analytics', 'Bluefin Systems', 'Cedar Health', 'Lumen Learning Co', 'Orbit Logistics',
  'Pixelforge Studio', 'Quartz Fintech', 'Riverstone Energy', 'Saffron Commerce', 'Tidewater Media', 'Umbra Security',
  'Vertex Cloudworks', 'Willow Robotics', 'Zephyr Mobility', 'Kestrel AI', 'Marigold Foods Tech', 'Nimbus Data',
  'Opal Insurance Tech', 'Pinecone Apps', 'Granite DevTools', 'Harbor Payments', 'Ivory Biotech', 'Juniper Games'
]) with ordinality as c(n, i);

-- ---------------------------------------------------------------- jobs
with titles(t, lvl, skills) as (
  values
    ('Flutter Developer',            'mid',    array['flutter', 'dart', 'firebase']),
    ('Senior Flutter Engineer',      'senior', array['flutter', 'dart', 'testing']),
    ('Frontend Engineer (React)',    'mid',    array['react', 'typescript', 'javascript']),
    ('Backend Engineer (Node.js)',   'mid',    array['node-js', 'postgresql', 'rest-apis']),
    ('Python Developer',             'entry',  array['python', 'django', 'sql']),
    ('Data Analyst',                 'entry',  array['sql', 'data-analysis', 'power-bi']),
    ('Machine Learning Engineer',    'senior', array['machine-learning', 'pytorch', 'python']),
    ('DevOps Engineer',              'mid',    array['docker', 'kubernetes', 'terraform']),
    ('Cloud Engineer (AWS)',         'mid',    array['aws', 'terraform', 'linux']),
    ('Product Designer',             'mid',    array['figma', 'ui-design', 'ux-research']),
    ('Product Manager',              'senior', array['product-management', 'agile', 'communication']),
    ('QA Automation Engineer',       'mid',    array['testing', 'cypress', 'javascript']),
    ('Android Developer (Kotlin)',   'mid',    array['kotlin', 'firebase', 'git']),
    ('iOS Developer (Swift)',        'mid',    array['swift', 'git', 'rest-apis']),
    ('Security Engineer',            'senior', array['security', 'linux', 'aws']),
    ('Software Engineering Intern',  'entry',  array['git', 'javascript', 'sql']),
    ('Data Engineer',                'mid',    array['python', 'sql', 'gcp']),
    ('Go Backend Engineer',          'senior', array['go', 'postgresql', 'graphql']),
    ('Engineering Lead',             'lead',   array['agile', 'communication', 'rest-apis']),
    ('Full-stack Developer',         'mid',    array['supabase', 'typescript', 'flutter'])
),
numbered as (
  select row_number() over () as k, t, lvl, skills from titles
),
gen as (
  select
    g as n,
    nb.t, nb.lvl, nb.skills,
    ('00000000-0000-4000-a000-' || lpad((1 + (g * 7) % 24)::text, 12, '0'))::uuid as company_id
  from generate_series(1, 240) g
  join numbered nb on nb.k = 1 + (g % 20)
)
insert into public.jobs (
  id, company_id, company_name, posted_by, title, summary, description_md, employment_type, experience_level,
  workplace, location_text, country_code, salary_min, salary_max, salary_currency, salary_period,
  responsibilities, qualifications, benefits, status, deadline, published_at
)
select
  ('00000000-0000-4000-b000-' || lpad(n::text, 12, '0'))::uuid,
  company_id, '', 'seed-employer',
  t,
  'Join a small team building ' || lower(t) || ' features used by thousands of people.',
  '## About the role' || E'\n\n' || 'You will work on ' || lower(t) || ' projects with a supportive team.' ||
    E'\n\n' || '## What you will do' || E'\n\n' || '- Build and ship features\n- Review code\n- Improve quality',
  (case when t like '%Intern%' then 'internship' when n % 9 = 0 then 'contract' else 'full_time' end)::public.employment_type,
  lvl::public.experience_level,
  (array['onsite', 'remote', 'hybrid'])[1 + n % 3]::public.workplace_type,
  (array['Bengaluru, IN', 'Hyderabad, IN', 'Chennai, IN', 'Pune, IN', 'Remote', 'Amaravati, IN'])[1 + n % 6],
  'IN',
  case when t like '%Intern%' then 15000 else 400000 + (n % 10) * 150000 end,
  case when t like '%Intern%' then 30000 else 900000 + (n % 10) * 200000 end,
  'INR',
  (case when t like '%Intern%' then 'month' else 'year' end)::public.salary_period,
  array['Design and build features end to end', 'Write tests and documentation', 'Collaborate with design and product'],
  array['Solid fundamentals in the core stack', 'Clear written communication'],
  array['Health insurance', 'Hybrid work', 'Learning budget'],
  (case when n % 23 = 0 then 'draft' when n % 31 = 0 then 'closed' else 'published' end)::public.job_status,
  case when n % 4 = 0 then current_date + (n % 45) end,
  case when n % 23 = 0 then null else now() - make_interval(hours => n * 5) end
from gen;

insert into public.job_skills (job_id, skill_id)
select j.id, s.id
from public.jobs j
join lateral (
  select unnest(case
    when j.title like 'Flutter%' or j.title like 'Senior Flutter%' then array['flutter', 'dart', 'firebase']
    when j.title like 'Frontend%' then array['react', 'typescript', 'javascript']
    when j.title like 'Backend%' then array['node-js', 'postgresql', 'rest-apis']
    when j.title like 'Python%' then array['python', 'django', 'sql']
    when j.title like 'Data Analyst%' then array['sql', 'data-analysis', 'power-bi']
    when j.title like 'Machine%' then array['machine-learning', 'pytorch', 'python']
    when j.title like 'DevOps%' then array['docker', 'kubernetes', 'terraform']
    when j.title like 'Cloud%' then array['aws', 'terraform', 'linux']
    when j.title like 'Product Designer%' then array['figma', 'ui-design', 'ux-research']
    when j.title like 'Product Manager%' then array['product-management', 'agile', 'communication']
    when j.title like 'QA%' then array['testing', 'cypress', 'javascript']
    when j.title like 'Android%' then array['kotlin', 'firebase', 'git']
    when j.title like 'iOS%' then array['swift', 'git', 'rest-apis']
    when j.title like 'Security%' then array['security', 'linux', 'aws']
    when j.title like 'Software Engineering Intern%' then array['git', 'javascript', 'sql']
    when j.title like 'Data Engineer%' then array['python', 'sql', 'gcp']
    when j.title like 'Go %' then array['go', 'postgresql', 'graphql']
    when j.title like 'Engineering Lead%' then array['agile', 'communication', 'rest-apis']
    else array['supabase', 'typescript', 'flutter']
  end) as slug
) x on true
join public.skills s on s.slug = x.slug;

-- ---------------------------------------------------------------- demo candidate data
insert into public.educations (user_id, institution, degree, field, start_date, end_date)
values ('seed-candidate', 'VIT-AP University', 'Integrated M.Tech', 'Computer Science and Engineering', '2023-07-01', null);
insert into public.experiences (user_id, company, title, start_date, end_date, description)
values ('seed-candidate', 'Pixelforge Studio', 'Flutter Intern', '2025-05-01', '2025-07-31', 'Built onboarding screens and widget tests.');
insert into public.profile_skills (user_id, skill_id)
select 'seed-candidate', id from public.skills where slug in ('flutter', 'dart', 'firebase', 'git');
insert into public.resumes (id, user_id, storage_path, file_name, is_primary)
values ('00000000-0000-4000-c000-000000000001', 'seed-candidate', 'seed-candidate/asha-verma-resume.pdf', 'asha-verma-resume.pdf', true);

-- Applications at different stages (system writes, so the stage is kept as given).
insert into public.applications (id, job_id, candidate_id, resume_id, cover_letter, stage)
select
  ('00000000-0000-4000-d000-' || lpad(r.k::text, 12, '0'))::uuid,
  r.job_id, 'seed-candidate', '00000000-0000-4000-c000-000000000001',
  'I would love to help build this.', r.stage::public.application_stage
from (values
  (1, '00000000-0000-4000-b000-000000000001'::uuid, 'applied'),
  (2, '00000000-0000-4000-b000-000000000021'::uuid, 'shortlisted'),
  (3, '00000000-0000-4000-b000-000000000041'::uuid, 'technical_interview'),
  (4, '00000000-0000-4000-b000-000000000061'::uuid, 'rejected')
) as r(k, job_id, stage);

insert into public.interviews (application_id, scheduled_at, duration_min, mode, meeting_url, interviewer_ids, notes)
values ('00000000-0000-4000-d000-000000000003', date_trunc('hour', now()) + interval '2 days 10 hours', 45, 'video',
        'https://meet.example.com/luzhire-demo', array['seed-employer'], 'Focus on state management.');

insert into public.announcements (title, body_md, audience, published_at, created_by)
values ('Welcome to LuzHire', 'This is a demo environment with fictional companies and jobs.', 'all', now(), 'seed-admin');
