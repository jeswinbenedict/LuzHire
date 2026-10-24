import { describe, expect, it } from 'vitest';
import { authorizeCron } from '../../api/_lib/cron.js';
import { HttpError } from '../../api/_lib/http.js';
import {
  dedupeKey,
  employmentTypeOf,
  htmlToMarkdown,
  parseSalary,
  type IngestJob,
} from '../../api/_lib/ingest/normalize.js';
import { inIndia } from '../../api/_lib/ingest/boards.js';
import { enabledProviders } from '../../api/_lib/ingest/live.js';
import {
  adzuna,
  ashby,
  greenhouse,
  himalayas,
  jobicy,
  lever,
  remoteOk,
  remotive,
  type Provider,
} from '../../api/_lib/ingest/providers.js';
import { runIngest, type ExistingJob, type IngestDeps, type RunLog } from '../../api/_lib/ingest/run.js';

describe('htmlToMarkdown', () => {
  it('keeps structure and drops anything executable', () => {
    const md = htmlToMarkdown(
      '<h2>About</h2><p>We build <strong>tools</strong> &amp; more.</p>' +
        '<ul><li>Ship <em>features</em></li><li>Review code</li></ul>' +
        '<script>alert(1)</script><p onclick="x()">Hi<br>there</p><a href="javascript:x">link</a>',
    );
    expect(md).toBe(
      '## About\n\nWe build **tools** & more.\n\n- Ship features\n\n- Review code\n\nHi\nthere\n\nlink',
    );
    expect(md).not.toContain('<');
    expect(md).not.toContain('alert');
  });

  it('decodes double-encoded feeds and caps the length', () => {
    expect(htmlToMarkdown('&lt;p&gt;Hello &amp;amp; welcome&lt;/p&gt;')).toBe('Hello & welcome');
    expect(htmlToMarkdown(`<p>${'a'.repeat(50)}</p>`, 20)).toHaveLength(20);
  });
});

describe('parseSalary', () => {
  it('reads ranges, currencies and periods', () => {
    expect(parseSalary('$80k - $100k')).toEqual({ min: 80000, max: 100000, currency: 'USD', period: 'year' });
    expect(parseSalary('€4,000 - 5,000 per month')).toEqual({ min: 4000, max: 5000, currency: 'EUR', period: 'month' });
    expect(parseSalary('$45/hour')).toEqual({ min: 45, max: 45, currency: 'USD', period: 'hour' });
    expect(parseSalary('₹12-18 LPA')).toEqual({ min: 1200000, max: 1800000, currency: 'INR', period: 'year' });
  });

  it('refuses anything ambiguous instead of guessing', () => {
    expect(parseSalary('$1000 per task')).toBeNull();
    expect(parseSalary('Competitive')).toBeNull();
    expect(parseSalary('80 - 100')).toBeNull(); // no currency
    expect(parseSalary('$50')).toBeNull(); // no period, too small to be a year
    expect(parseSalary('')).toBeNull();
  });
});

describe('helpers', () => {
  it('maps employment types', () => {
    expect(employmentTypeOf('full_time')).toBe('full_time');
    expect(employmentTypeOf('Part-time')).toBe('part_time');
    expect(employmentTypeOf('freelance')).toBe('contract');
    expect(employmentTypeOf('internship')).toBe('internship');
    expect(employmentTypeOf('')).toBe('full_time');
  });

  it('matches the same job across providers', () => {
    expect(dedupeKey('Senior Flutter Developer', 'Nimbus Labs Pvt. Ltd.')).toBe(
      dedupeKey('senior flutter developer', 'Nimbus Labs'),
    );
  });
});

describe('providers', () => {
  it('Remotive: maps jobs and rejects unsafe or incomplete rows', async () => {
    const result = await remotive.fetch(async () => ({
      'job-count': 3,
      'total-job-count': 3,
      jobs: [
        {
          id: 7,
          url: 'https://remotive.com/remote-jobs/dev/flutter-7',
          title: 'Flutter Developer',
          company_name: 'Orbit',
          company_logo: 'https://remotive.com/job/7/logo',
          job_type: 'contract',
          publication_date: '2026-10-18T10:00:00',
          candidate_required_location: 'India',
          salary: '$40k - $60k',
          tags: ['Flutter', 'Dart'],
          description: '<p>Build the app for our customers worldwide every day.</p>',
        },
        { id: 8, url: 'https://evil.example/x', title: 'Phish', company_name: 'X', description: '' },
        { id: 9, url: 'https://remotive.com/remote-jobs/x-9', title: '', company_name: 'Y', description: '' },
      ],
    }));
    expect(result.complete).toBe(true);
    expect(result.jobs).toHaveLength(1);
    expect(result.jobs[0]).toMatchObject({
      source: 'remotive',
      externalId: '7',
      workplace: 'remote',
      employmentType: 'contract',
      location: 'Remote (India)',
      salaryMin: 40000,
      salaryCurrency: 'USD',
      salaryPeriod: 'year',
      publishedAt: '2026-10-18T10:00:00.000Z',
      tags: ['Flutter', 'Dart'],
    });
  });

  it('Remotive: a sample of the feed is not treated as complete', async () => {
    const result = await remotive.fetch(async () => ({ 'job-count': 10, 'total-job-count': 1250, jobs: [] }));
    expect(result.complete).toBe(false);
  });

  it('Adzuna: ignores predicted salaries and stops at the last page', async () => {
    const urls: string[] = [];
    const result = await adzuna('id', 'key', 3).fetch(async (url) => {
      urls.push(url);
      return {
        results: [
          {
            id: '101',
            redirect_url: 'https://www.adzuna.in/land/ad/101',
            title: '<strong>Data</strong> Analyst',
            company: { display_name: 'Acme' },
            location: { display_name: 'Pune, Maharashtra' },
            salary_min: 600000,
            salary_max: 900000,
            salary_is_predicted: '1',
            contract_time: 'full_time',
            created: '2026-10-19T08:00:00Z',
            description: 'Analyse data for our product teams across India.',
          },
        ],
      };
    });
    expect(urls).toHaveLength(1);
    expect(urls[0]).toContain('/jobs/in/search/1');
    expect(result.complete).toBe(false);
    expect(result.jobs[0]).toMatchObject({
      title: 'Data Analyst',
      companyName: 'Acme',
      location: 'Pune, Maharashtra',
      salaryMin: null,
    });
  });
});

describe('company career boards', () => {
  it('recognises Indian locations, not look-alikes', () => {
    expect(inIndia('Bengaluru-VTP, India')).toBe(true);
    expect(inIndia('Gurugram')).toBe(true);
    expect(inIndia('Remote - India')).toBe(true);
    expect(inIndia('Indianapolis, Indiana')).toBe(false);
    expect(inIndia('Singapore')).toBe(false);
  });

  it('Greenhouse: imports India roles only, with the company name and its own dates', async () => {
    const urls: string[] = [];
    const result = await greenhouse([{ token: 'acme', name: 'Acme Corp' }]).fetch(async (url) => {
      urls.push(url);
      return {
        jobs: [
          {
            id: 11,
            title: 'Backend Engineer',
            absolute_url: 'https://job-boards.greenhouse.io/acme/jobs/11',
            location: { name: 'Bengaluru, India' },
            first_published: '2026-05-01T09:00:00-04:00',
            content: '&lt;p&gt;Build &lt;strong&gt;payments&lt;/strong&gt; for millions of users across India.&lt;/p&gt;',
          },
          {
            id: 12,
            title: 'Software Engineering Intern',
            absolute_url: 'https://job-boards.greenhouse.io/acme/jobs/12',
            location: { name: 'Multiple locations' },
            offices: [{ name: 'Pune' }, { name: 'Berlin' }],
            updated_at: '2026-10-01T00:00:00Z',
            content: '',
          },
          { id: 13, title: 'Account Executive', absolute_url: 'https://job-boards.greenhouse.io/acme/jobs/13', location: { name: 'Austin, TX' } },
          { id: 14, title: 'Unsafe link', absolute_url: 'javascript:alert(1)', location: { name: 'Mumbai' } },
        ],
      };
    });
    expect(urls).toEqual(['https://boards-api.greenhouse.io/v1/boards/acme/jobs?content=true']);
    expect(result.jobs.map((j) => j.externalId)).toEqual(['acme:11', 'acme:12']);
    expect(result.jobs[0]).toMatchObject({
      source: 'greenhouse',
      companyName: 'Acme Corp',
      location: 'Bengaluru, India',
      workplace: 'onsite',
      publishedAt: '2026-05-01T13:00:00.000Z',
      descriptionMd: 'Build **payments** for millions of users across India.',
    });
    expect(result.jobs[1]).toMatchObject({ location: 'Pune', employmentType: 'internship' });
    expect(result.complete).toBe(true);
  });

  it('Lever: pages through the board and keeps salary only when complete', async () => {
    const posting = (id: string, over: Record<string, unknown> = {}) => ({
      id,
      text: `Role ${id}`,
      hostedUrl: `https://jobs.lever.co/acme/${id}`,
      categories: { location: 'hyderabad', commitment: 'Full time', allLocations: ['hyderabad'] },
      country: 'IN',
      workplaceType: 'onsite',
      createdAt: Date.parse('2026-09-01T00:00:00Z'),
      description: '<p>We are hiring engineers to build the future of lending in India.</p>',
      lists: [{ text: 'What you will do', content: '<li>Ship features</li>' }],
      ...over,
    });
    const urls: string[] = [];
    const result = await lever([{ token: 'acme', name: 'Acme' }]).fetch(async (url) => {
      urls.push(url);
      const skip = Number(new URL(url).searchParams.get('skip'));
      if (skip === 0) {
        return [
          posting('a', {
            workplaceType: 'hybrid',
            salaryRange: { min: 1200000, max: 1800000, currency: 'inr', interval: 'per-year-salary' },
          }),
          ...Array.from({ length: 99 }, (_, i) => posting(`f${i}`)),
        ];
      }
      if (skip === 100) {
        return [
          posting('remote', { country: 'US', workplaceType: 'remote', categories: { location: 'Remote', allLocations: ['Remote', 'Chennai'] } }),
          posting('us', { country: 'US', categories: { location: 'New York', allLocations: ['New York'] } }),
        ];
      }
      return [];
    });
    // Three pages requested at once; the second was short, so no more.
    expect(urls).toHaveLength(3);
    expect(result.jobs).toHaveLength(101);
    expect(result.jobs[0]).toMatchObject({
      externalId: 'acme:a',
      location: 'Hyderabad',
      workplace: 'hybrid',
      salaryMin: 1200000,
      salaryMax: 1800000,
      salaryCurrency: 'INR',
      salaryPeriod: 'year',
    });
    expect(result.jobs[0]!.descriptionMd).toContain('## What you will do\n\n- Ship features');
    expect(result.jobs.at(-1)).toMatchObject({ externalId: 'acme:remote', location: 'Chennai', workplace: 'remote' });
  });

  it('Ashby: skips unlisted jobs and hidden pay', async () => {
    const result = await ashby([{ token: 'acme', name: 'Acme' }]).fetch(async () => ({
      jobs: [
        {
          id: 'x1',
          title: 'ML Engineer',
          jobUrl: 'https://jobs.ashbyhq.com/acme/x1',
          location: 'Remote',
          address: { postalAddress: { addressCountry: 'India' } },
          isRemote: true,
          workplaceType: 'Remote',
          employmentType: 'FullTime',
          isListed: true,
          shouldDisplayCompensationOnJobPostings: true,
          compensation: { compensationTierSummary: '₹30L – ₹45L per year' },
          publishedAt: '2026-10-01T10:00:00.000+00:00',
          descriptionHtml: '<p>Train speech models for every Indian language at scale.</p>',
        },
        {
          id: 'x2',
          title: 'Designer',
          jobUrl: 'https://jobs.ashbyhq.com/acme/x2',
          location: 'Delhi',
          employmentType: 'Intern',
          isListed: true,
          shouldDisplayCompensationOnJobPostings: false,
          compensation: { compensationTierSummary: '₹50K per month' },
          publishedAt: '2026-10-01T10:00:00.000+00:00',
        },
        { id: 'x3', title: 'Hidden', jobUrl: 'https://jobs.ashbyhq.com/acme/x3', location: 'Delhi', isListed: false },
        { id: 'x4', title: 'London role', jobUrl: 'https://jobs.ashbyhq.com/acme/x4', location: 'London', isListed: true },
      ],
    }));
    expect(result.jobs.map((j) => j.externalId)).toEqual(['acme:x1', 'acme:x2']);
    expect(result.jobs[0]).toMatchObject({ location: 'India', workplace: 'remote', salaryMin: 3000000, salaryCurrency: 'INR' });
    expect(result.jobs[1]).toMatchObject({ location: 'Delhi', employmentType: 'internship', salaryMin: null });
  });

  it('a failing board is reported, and only answered boards can close jobs', async () => {
    const result = await greenhouse([
      { token: 'up', name: 'Up' },
      { token: 'down', name: 'Down' },
    ]).fetch(async (url) => {
      if (url.includes('/down/')) throw new Error('boards-api.greenhouse.io answered 500');
      return { jobs: [] };
    });
    expect(result.warnings).toEqual(['down: boards-api.greenhouse.io answered 500']);
    expect(result.covers?.('up:1')).toBe(true);
    expect(result.covers?.('down:1')).toBe(false);
    await expect(greenhouse([{ token: 'down', name: 'Down' }]).fetch(async () => { throw new Error('offline'); })).rejects.toThrow(
      'No board answered',
    );
  });
});

describe('remote job feeds', () => {
  it('Himalayas: keeps the application link unchanged and reads pay', async () => {
    const urls: string[] = [];
    const result = await himalayas(3).fetch(async (url) => {
      urls.push(url);
      return {
        jobs: [
          {
            guid: 'https://himalayas.app/companies/orbit/jobs/data-engineer',
            applicationLink: 'https://himalayas.app/companies/orbit/jobs/data-engineer?utm_source=api',
            title: 'Data Engineer',
            companyName: 'Orbit',
            companyLogo: 'https://cdn-images.himalayas.app/abc',
            employmentType: 'Contractor',
            minSalary: 40,
            maxSalary: 60,
            currency: 'USD',
            salaryPeriod: 'hourly',
            locationRestrictions: ['India', 'Philippines'],
            pubDate: 1792771982,
            description: '<p>Build data pipelines for a fully remote analytics team.</p>',
          },
          { applicationLink: 'https://evil.example/x', title: 'Bad', companyName: 'X' },
        ],
      };
    });
    expect(urls).toEqual(['https://himalayas.app/jobs/api/search?country=India&page=1']); // short page: stop
    expect(result.jobs).toHaveLength(1);
    expect(result.jobs[0]).toMatchObject({
      source: 'himalayas',
      externalUrl: 'https://himalayas.app/companies/orbit/jobs/data-engineer?utm_source=api',
      location: 'Remote (India, Philippines)',
      employmentType: 'contract',
      salaryMin: 40,
      salaryMax: 60,
      salaryPeriod: 'hour',
      publishedAt: new Date(1792771982 * 1000).toISOString(),
    });
    expect(result.complete).toBe(false);
  });

  it('Jobicy: reads the APAC and worldwide feeds', async () => {
    const urls: string[] = [];
    const result = await jobicy.fetch(async (url) => {
      urls.push(url);
      return {
        jobs: [
          {
            id: url.includes('apac') ? 1 : 2,
            url: `https://jobicy.com/jobs/${url.includes('apac') ? 1 : 2}-role`,
            jobTitle: 'Support Lead',
            companyName: url.includes('apac') ? 'Kite' : 'Canonical',
            jobGeo: url.includes('apac') ? 'APAC' : 'Anywhere',
            jobType: ['Part-Time'],
            pubDate: '2026-10-23T13:48:16+00:00',
            jobDescription: '<p>Help customers across time zones get the most from our product.</p>',
          },
        ],
      };
    });
    expect(urls.map((u) => new URL(u).searchParams.get('geo'))).toEqual(['apac', 'anywhere']);
    expect(result.jobs.map((j) => j.location)).toEqual(['Remote (APAC)', 'Remote (Anywhere)']);
    expect(result.jobs[0]).toMatchObject({ employmentType: 'part_time', externalUrl: 'https://jobicy.com/jobs/1-role' });
  });

  it('Remote OK: skips the legal notice and jobs closed to India', async () => {
    const result = await remoteOk.fetch(async () => [
      { legal: 'API Terms of Service' },
      {
        id: '1',
        url: 'https://remoteOK.com/remote-jobs/1',
        position: 'Senior Go Developer',
        company: 'Lemon',
        location: 'Worldwide',
        salary_min: 50000,
        salary_max: 0,
        date: '2026-10-22T12:58:28+00:00',
        tags: ['golang'],
        description: '<p>Build backend services for clients around the world.</p>',
      },
      { id: '2', url: 'https://remoteok.com/remote-jobs/2', position: 'Nurse', company: 'Care', location: 'United States' },
    ]);
    expect(result.jobs).toHaveLength(1);
    expect(result.jobs[0]).toMatchObject({
      source: 'remoteok',
      location: 'Remote (Worldwide)',
      salaryMin: 50000,
      salaryMax: 50000,
      salaryCurrency: 'USD',
      tags: ['golang'],
    });
  });

  it('groups the daily imports so each fits the time limit', () => {
    expect(enabledProviders('jobs', {}).map((p) => p.id)).toEqual(['remotive', 'himalayas', 'jobicy', 'remoteok']);
    expect(enabledProviders('jobs', { ADZUNA_APP_ID: 'i', ADZUNA_APP_KEY: 'k' }).map((p) => p.id)).toContain('adzuna');
    expect(enabledProviders('companies', {}).map((p) => p.id)).toEqual(['greenhouse', 'lever', 'ashby']);
  });
});

function job(id: string, over: Partial<IngestJob> = {}): IngestJob {
  return {
    source: 'remotive',
    externalId: id,
    externalUrl: `https://remotive.com/remote-jobs/x-${id}`,
    title: `Job ${id}`,
    companyName: 'Orbit',
    logoUrl: null,
    descriptionMd: '',
    summary: null,
    location: 'Remote',
    workplace: 'remote',
    employmentType: 'full_time',
    salaryMin: null,
    salaryMax: null,
    salaryCurrency: null,
    salaryPeriod: null,
    publishedAt: '2026-10-19T00:00:00.000Z',
    tags: [],
    ...over,
  };
}

function fakeDeps(existing: ExistingJob[]) {
  const upserted: IngestJob[] = [];
  const closed: string[] = [];
  const logs: RunLog[] = [];
  const linked = new Map<string, string[]>();
  const deps: IngestDeps = {
    get: async () => ({}),
    now: () => new Date('2026-10-20T00:00:00Z'),
    existing: async () => existing,
    upsert: async (jobs) => {
      upserted.push(...jobs);
      return jobs.map((j) => ({ id: `db-${j.externalId}`, source: j.source, externalId: j.externalId }));
    },
    linkSkills: async (m) => {
      for (const [k, v] of m) linked.set(k, v);
    },
    close: async (ids) => {
      closed.push(...ids);
    },
    log: async (l) => {
      logs.push(l);
    },
  };
  return { deps, upserted, closed, logs, linked };
}

const provider = (jobs: IngestJob[], complete = true): Provider => ({
  id: 'remotive',
  label: 'Remotive',
  fetch: async () => ({ jobs, complete }),
});

describe('runIngest', () => {
  it('inserts new jobs, updates known ones and closes jobs gone from a complete feed', async () => {
    const existing: ExistingJob[] = [
      { id: 'db-1', source: 'remotive', externalId: '1', title: 'Job 1', companyName: 'Orbit', status: 'published', publishedAt: '2026-10-18T00:00:00Z' },
      { id: 'db-old', source: 'remotive', externalId: 'gone', title: 'Gone', companyName: 'Orbit', status: 'published', publishedAt: '2026-10-18T00:00:00Z' },
    ];
    const f = fakeDeps(existing);
    const [log] = await runIngest(f.deps, [provider([job('1'), job('2', { tags: ['Flutter'] })])]);
    expect(log).toMatchObject({ fetched: 2, inserted: 1, updated: 1, closed: 1, skipped: 0, error: null });
    expect(f.closed).toEqual(['db-old']);
    expect(f.linked.get('db-2')).toEqual(['Flutter']);
  });

  it('skips stale jobs, repeats and copies of another provider\'s live job', async () => {
    const existing: ExistingJob[] = [
      { id: 'db-a', source: 'adzuna', externalId: 'a', title: 'Flutter Dev', companyName: 'Orbit Ltd', status: 'published', publishedAt: '2026-10-19T00:00:00Z' },
    ];
    const f = fakeDeps(existing);
    const [log] = await runIngest(f.deps, [
      provider([
        job('1', { publishedAt: '2026-08-01T00:00:00Z' }), // older than 30 days
        job('2'),
        job('2'), // same id twice
        job('3', { title: 'Flutter Dev', companyName: 'Orbit' }), // already from Adzuna
      ]),
    ]);
    expect(f.upserted.map((j) => j.externalId)).toEqual(['2']);
    expect(log).toMatchObject({ skipped: 3, inserted: 1 });
  });

  it('partial feeds only expire jobs by age', async () => {
    const existing: ExistingJob[] = [
      { id: 'db-recent', source: 'remotive', externalId: 'r', title: 'R', companyName: 'O', status: 'published', publishedAt: '2026-10-15T00:00:00Z' },
      { id: 'db-aged', source: 'remotive', externalId: 'a', title: 'A', companyName: 'O', status: 'published', publishedAt: '2026-09-01T00:00:00Z' },
    ];
    const f = fakeDeps(existing);
    await runIngest(f.deps, [provider([job('new')], false)]);
    expect(f.closed).toEqual(['db-aged']);
  });

  it('logs a failing provider and carries on with the next', async () => {
    const f = fakeDeps([]);
    const broken: Provider = { id: 'adzuna', label: 'Adzuna', fetch: async () => { throw new Error('api.adzuna.com answered 401'); } };
    const logs = await runIngest(f.deps, [broken, provider([job('1')])]);
    expect(logs[0]).toMatchObject({ source: 'adzuna', error: 'api.adzuna.com answered 401' });
    expect(logs[1]).toMatchObject({ source: 'remotive', inserted: 1 });
    expect(f.logs).toHaveLength(2);
  });

  it('career boards keep old open roles and close only for boards that answered', async () => {
    const existing: ExistingJob[] = [
      { id: 'db-up', source: 'greenhouse', externalId: 'up:1', title: 'A', companyName: 'Up', status: 'published', publishedAt: '2026-01-01T00:00:00Z' },
      { id: 'db-down', source: 'greenhouse', externalId: 'down:1', title: 'B', companyName: 'Down', status: 'published', publishedAt: '2026-10-01T00:00:00Z' },
    ];
    const f = fakeDeps(existing);
    const boards: Provider = {
      id: 'greenhouse',
      label: 'Greenhouse',
      maxAgeDays: null,
      fetch: async () => ({
        jobs: [job('up:2', { source: 'greenhouse', publishedAt: '2025-12-01T00:00:00Z' })],
        complete: true,
        covers: (id) => id.startsWith('up:'),
        warnings: ['down: timeout'],
      }),
    };
    const [log] = await runIngest(f.deps, [boards]);
    expect(f.upserted.map((j) => j.externalId)).toEqual(['up:2']); // old, still listed
    expect(f.closed).toEqual(['db-up']); // gone from its board; db-down untouched
    expect(log).toMatchObject({ inserted: 1, closed: 1, error: 'down: timeout' });
  });
});

describe('authorizeCron', () => {
  const req = (auth?: string) =>
    new Request('https://x/api/ingest/jobs', { headers: auth ? { authorization: auth } : {} });
  it('needs a configured secret and the matching bearer', () => {
    expect(() => authorizeCron(req('Bearer x'), undefined)).toThrow(HttpError);
    expect(() => authorizeCron(req('Bearer wrong-secret-value'), 'a-very-long-secret-1')).toThrow(HttpError);
    expect(() => authorizeCron(req(), 'a-very-long-secret-1')).toThrow(HttpError);
    expect(() => authorizeCron(req('Bearer a-very-long-secret-1'), 'a-very-long-secret-1')).not.toThrow();
  });
});
