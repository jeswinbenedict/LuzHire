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
import { adzuna, remotive, type Provider } from '../../api/_lib/ingest/providers.js';
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
