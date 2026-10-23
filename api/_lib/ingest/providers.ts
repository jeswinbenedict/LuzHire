// Provider adapters. Each returns normalised jobs and whether the result is
// the provider's complete current list (then missing jobs can be closed).
import { ASHBY_BOARDS, GREENHOUSE_BOARDS, LEVER_BOARDS, inIndia, type Board } from './boards.js';
import {
  clamp,
  employmentTypeOf,
  htmlToMarkdown,
  parseSalary,
  plainText,
  summaryOf,
  type EmploymentType,
  type IngestJob,
  type SalaryPeriod,
  type Workplace,
} from './normalize.js';

export type Fetcher = (url: string) => Promise<unknown>;

export interface ProviderResult {
  jobs: IngestJob[];
  /** True when `jobs` is everything the provider currently lists. */
  complete: boolean;
  /**
   * With `complete`: the stored jobs that list speaks for (e.g. only the
   * boards that answered). Others are left alone. Default: all.
   */
  covers?: (externalId: string) => boolean;
  /** Problems that did not stop the run (one board of many failing). */
  warnings?: string[];
}

export interface Provider {
  id: string;
  /** Shown on cards and detail pages ("Listed on …", attribution). */
  label: string;
  /**
   * Jobs older than this are skipped and expired. null: the feed is the
   * employer's own board, so a listed job is open however old it is.
   * Default: MAX_AGE_DAYS.
   */
  maxAgeDays?: number | null;
  fetch(get: Fetcher): Promise<ProviderResult>;
}

function str(v: unknown): string {
  return typeof v === 'string' ? v : '';
}

function baseJob(fields: Partial<IngestJob> & Pick<IngestJob, 'source' | 'externalId' | 'externalUrl' | 'title' | 'companyName' | 'publishedAt'>, html: string): IngestJob {
  const descriptionMd = htmlToMarkdown(html);
  return {
    logoUrl: null,
    location: null,
    workplace: 'onsite',
    employmentType: 'full_time',
    salaryMin: null,
    salaryMax: null,
    salaryCurrency: null,
    salaryPeriod: null,
    tags: [],
    ...fields,
    title: clamp(fields.title, 160),
    companyName: clamp(fields.companyName, 160),
    descriptionMd,
    summary: summaryOf(descriptionMd),
  };
}

/**
 * Remotive (https://remotive.com): worldwide remote jobs. Terms: at most a
 * few calls a day, link back and name Remotive, and do not pass the jobs to
 * Google Jobs (external pages are noindex, without JobPosting markup).
 */
export const remotive: Provider = {
  id: 'remotive',
  label: 'Remotive',
  async fetch(get) {
    const data = (await get('https://remotive.com/api/remote-jobs')) as {
      jobs?: unknown[];
      'job-count'?: unknown;
      'total-job-count'?: unknown;
    };
    const jobs: IngestJob[] = [];
    for (const raw of data.jobs ?? []) {
      const j = raw as Record<string, unknown>;
      const id = j.id;
      const url = str(j.url);
      const title = plainText(str(j.title));
      const company = plainText(str(j.company_name));
      if (id == null || !/^https:\/\/remotive\.com\//.test(url) || title.length < 2 || !company) continue;
      const salary = parseSalary(str(j.salary));
      const where = str(j.candidate_required_location).trim();
      jobs.push(
        baseJob(
          {
            source: 'remotive',
            externalId: String(id),
            externalUrl: url,
            title,
            companyName: company,
            logoUrl: /^https:\/\//.test(str(j.company_logo)) ? str(j.company_logo) : null,
            location: where ? `Remote (${clamp(where, 100)})` : 'Remote',
            workplace: 'remote',
            employmentType: employmentTypeOf(str(j.job_type)),
            salaryMin: salary?.min ?? null,
            salaryMax: salary?.max ?? null,
            salaryCurrency: salary?.currency ?? null,
            salaryPeriod: salary?.period ?? null,
            publishedAt: toIso(str(j.publication_date)),
            tags: Array.isArray(j.tags) ? j.tags.map(str).filter(Boolean).slice(0, 20) : [],
          },
          str(j.description),
        ),
      );
    }
    // The free feed may return only a sample of the full list; only then
    // can missing jobs be treated as filled (otherwise they expire by age).
    const returned = Number(data['job-count']);
    const total = Number(data['total-job-count']);
    const complete = Number.isFinite(returned) && Number.isFinite(total) && returned >= total;
    return { jobs, complete };
  },
};

/**
 * Adzuna India (https://developer.adzuna.com): needs a free app id + key.
 * Terms: label each advert "Adzuna" with a link, 250 calls a day.
 */
export function adzuna(appId: string, appKey: string, pages = 3): Provider {
  return {
    id: 'adzuna',
    label: 'Adzuna',
    async fetch(get) {
      const jobs: IngestJob[] = [];
      for (let page = 1; page <= pages; page++) {
        const url =
          `https://api.adzuna.com/v1/api/jobs/in/search/${page}` +
          `?app_id=${encodeURIComponent(appId)}&app_key=${encodeURIComponent(appKey)}` +
          '&results_per_page=50&max_days_old=14&sort_by=date&content-type=application/json';
        const data = (await get(url)) as { results?: unknown[] };
        const results = data.results ?? [];
        for (const raw of results) {
          const j = raw as Record<string, unknown>;
          const id = str(j.id) || (typeof j.id === 'number' ? String(j.id) : '');
          const link = str(j.redirect_url);
          const title = plainText(str(j.title));
          const company = plainText(str((j.company as Record<string, unknown> | undefined)?.display_name));
          if (!id || !/^https:\/\//.test(link) || title.length < 2 || !company) continue;
          const min = typeof j.salary_min === 'number' ? j.salary_min : null;
          const max = typeof j.salary_max === 'number' ? j.salary_max : null;
          const predicted = String(j.salary_is_predicted ?? '0') === '1';
          const contract = `${str(j.contract_time)} ${str(j.contract_type)}`;
          const where = str((j.location as Record<string, unknown> | undefined)?.display_name).trim();
          const hasSalary = !predicted && (min != null || max != null);
          jobs.push(
            baseJob(
              {
                source: 'adzuna',
                externalId: id,
                externalUrl: link,
                title,
                companyName: company,
                location: where || 'India',
                workplace: /remote|work from home|wfh/i.test(`${title} ${str(j.description)}`) ? 'remote' : 'onsite',
                employmentType: employmentTypeOf(contract),
                // Predicted salaries are Adzuna estimates, not the employer's.
                salaryMin: hasSalary ? (min ?? max) : null,
                salaryMax: hasSalary ? (max ?? min) : null,
                salaryCurrency: hasSalary ? 'INR' : null,
                salaryPeriod: hasSalary ? 'year' : null,
                publishedAt: toIso(str(j.created)),
                tags: [],
              },
              str(j.description),
            ),
          );
        }
        if (results.length < 50) break;
      }
      return { jobs, complete: false };
    },
  };
}

type Rec = Record<string, unknown>;

const rec = (v: unknown): Rec => (v && typeof v === 'object' ? (v as Rec) : {});
const list = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);

function workplaceOf(text: string): Workplace {
  if (/\bhybrid\b/i.test(text)) return 'hybrid';
  if (/\bremote\b|work from home|\bwfh\b/i.test(text)) return 'remote';
  return 'onsite';
}

/** Employment type from a job title (boards without a type field). */
function typeFromTitle(title: string): EmploymentType {
  if (/\bintern(ship)?\b/i.test(title)) return 'internship';
  if (/\bcontract(or|ual)?\b/i.test(title)) return 'contract';
  return 'full_time';
}

function periodOf(raw: string): SalaryPeriod | null {
  if (/hour/i.test(raw)) return 'hour';
  if (/month/i.test(raw)) return 'month';
  if (/year|annual/i.test(raw)) return 'year';
  return null;
}

/** "bengaluru" → "Bengaluru" (some boards store locations in lower case). */
const capitalise = (s: string) => s.replace(/(^|[\s,(/-])([a-z])/g, (_m, a: string, b: string) => a + b.toUpperCase());

const firstIndian = (places: string[]) => places.map((p) => plainText(p, 120)).find(inIndia) ?? 'India';

/** Large boards are several MB each, so only a few download at once. */
const BOARD_CONCURRENCY = 6;

/**
 * Reads every board of one ATS. A board's list is complete, so its missing
 * jobs are closed, but only for boards that answered this time.
 */
async function eachBoard(
  boards: Board[],
  get: Fetcher,
  read: (board: Board, get: Fetcher) => Promise<IngestJob[]>,
): Promise<ProviderResult> {
  const jobs: IngestJob[] = [];
  const answered = new Set<string>();
  const warnings: string[] = [];
  const queue = [...boards];
  const worker = async () => {
    for (let board = queue.shift(); board; board = queue.shift()) {
      try {
        jobs.push(...(await read(board, get)));
        answered.add(board.token);
      } catch (e) {
        warnings.push(`${board.token}: ${e instanceof Error ? e.message : 'failed'}`);
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(BOARD_CONCURRENCY, boards.length) }, worker));
  if (answered.size === 0 && boards.length > 0) throw new Error(`No board answered (${warnings[0]})`);
  return {
    jobs,
    complete: true,
    covers: (externalId) => answered.has(externalId.split(':')[0]!),
    warnings,
  };
}

/**
 * Greenhouse job boards (boards-api.greenhouse.io): public, no key. The
 * description comes HTML-escaped; India roles only.
 */
export function greenhouse(boards: Board[] = GREENHOUSE_BOARDS): Provider {
  return {
    id: 'greenhouse',
    label: 'Greenhouse',
    maxAgeDays: null,
    fetch: (get) =>
      eachBoard(boards, get, async (board, get) => {
        const data = await get(`https://boards-api.greenhouse.io/v1/boards/${board.token}/jobs?content=true`);
        const jobs: IngestJob[] = [];
        for (const raw of list(rec(data).jobs)) {
          const j = rec(raw);
          const where = plainText(str(rec(j.location).name), 120);
          const offices = list(j.offices).map((o) => str(rec(o).name));
          const url = str(j.absolute_url);
          const title = plainText(str(j.title));
          if (j.id == null || !/^https:\/\//.test(url) || title.length < 2) continue;
          if (!inIndia([where, ...offices].join(' '))) continue;
          jobs.push(
            baseJob(
              {
                source: 'greenhouse',
                externalId: `${board.token}:${String(j.id)}`,
                externalUrl: url,
                title,
                companyName: board.name,
                location: inIndia(where) ? where : firstIndian(offices),
                workplace: workplaceOf(`${where} ${title}`),
                employmentType: typeFromTitle(title),
                publishedAt: toIso(str(j.first_published) || str(j.updated_at)),
              },
              str(j.content),
            ),
          );
        }
        return jobs;
      }),
  };
}

const LEVER_PAGE = 100;
const LEVER_PARALLEL = 3;

/** Lever postings (api.lever.co/v0/postings): public, no key. India roles only. */
export function lever(boards: Board[] = LEVER_BOARDS): Provider {
  return {
    id: 'lever',
    label: 'Lever',
    maxAgeDays: null,
    fetch: (get) =>
      eachBoard(boards, get, async (board, get) => {
        // Lever serves slowly (~150 KB/s), so pages download side by side.
        const postings: unknown[] = [];
        for (let skip = 0; ; skip += LEVER_PAGE * LEVER_PARALLEL) {
          const pages = await Promise.all(
            Array.from({ length: LEVER_PARALLEL }, (_, i) =>
              get(`https://api.lever.co/v0/postings/${board.token}?mode=json&limit=${LEVER_PAGE}&skip=${skip + i * LEVER_PAGE}`),
            ),
          );
          postings.push(...pages.flatMap(list));
          if (list(pages[LEVER_PARALLEL - 1]).length < LEVER_PAGE) break;
        }
        const jobs: IngestJob[] = [];
        for (const raw of postings) {
          const j = rec(raw);
          const c = rec(j.categories);
          const places = [str(c.location), ...list(c.allLocations).map(str)].filter(Boolean);
          const url = str(j.hostedUrl);
          const title = plainText(str(j.text));
          if (!str(j.id) || !/^https:\/\/jobs\.lever\.co\//.test(url) || title.length < 2) continue;
          if (str(j.country) !== 'IN' && !places.some(inIndia)) continue;
          const pay = rec(j.salaryRange);
          const period = periodOf(str(pay.interval));
          const hasPay = typeof pay.min === 'number' && typeof pay.max === 'number' && !!str(pay.currency) && !!period;
          const workplace = str(j.workplaceType);
          const html = [
            str(j.description),
            ...list(j.lists).map((l) => `<h3>${str(rec(l).text)}</h3><ul>${str(rec(l).content)}</ul>`),
            str(j.additional),
          ].join('');
          jobs.push(
            baseJob(
              {
                source: 'lever',
                externalId: `${board.token}:${str(j.id)}`,
                externalUrl: url,
                title,
                companyName: board.name,
                location: capitalise(firstIndian(places)),
                workplace: workplace === 'remote' || workplace === 'hybrid' ? workplace : workplaceOf(places.join(' ')),
                employmentType: str(c.commitment) ? employmentTypeOf(str(c.commitment)) : typeFromTitle(title),
                salaryMin: hasPay ? (pay.min as number) : null,
                salaryMax: hasPay ? (pay.max as number) : null,
                salaryCurrency: hasPay ? str(pay.currency).toUpperCase() : null,
                salaryPeriod: hasPay ? period : null,
                publishedAt: typeof j.createdAt === 'number' ? new Date(j.createdAt).toISOString() : new Date().toISOString(),
              },
              html,
            ),
          );
        }
        return jobs;
      }),
  };
}

/** Ashby job boards (api.ashbyhq.com/posting-api): public, no key. India roles only. */
export function ashby(boards: Board[] = ASHBY_BOARDS): Provider {
  return {
    id: 'ashby',
    label: 'Ashby',
    maxAgeDays: null,
    fetch: (get) =>
      eachBoard(
        boards,
        get,
        async (board, get) => {
          const data = await get(`https://api.ashbyhq.com/posting-api/job-board/${board.token}?includeCompensation=true`);
          const jobs: IngestJob[] = [];
          for (const raw of list(rec(data).jobs)) {
            const j = rec(raw);
            const places = [str(j.location), ...list(j.secondaryLocations).map((s) => str(rec(s).location))].filter(Boolean);
            const country = str(rec(rec(j.address).postalAddress).addressCountry);
            const url = str(j.jobUrl);
            const title = plainText(str(j.title));
            if (j.isListed === false || !str(j.id) || !/^https:\/\/jobs\.ashbyhq\.com\//.test(url) || title.length < 2) continue;
            if (!inIndia([...places, country].join(' '))) continue;
            const kind = str(j.workplaceType).toLowerCase();
            const pay =
              j.shouldDisplayCompensationOnJobPostings === true
                ? parseSalary(str(rec(j.compensation).compensationTierSummary))
                : null;
            jobs.push(
              baseJob(
                {
                  source: 'ashby',
                  externalId: `${board.token}:${str(j.id)}`,
                  externalUrl: url,
                  title,
                  companyName: board.name,
                  location: places.some(inIndia) ? firstIndian(places) : 'India',
                  workplace: kind === 'remote' || j.isRemote === true ? 'remote' : kind === 'hybrid' ? 'hybrid' : 'onsite',
                  employmentType: employmentTypeOf(str(j.employmentType)),
                  salaryMin: pay?.min ?? null,
                  salaryMax: pay?.max ?? null,
                  salaryCurrency: pay?.currency ?? null,
                  salaryPeriod: pay?.period ?? null,
                  publishedAt: toIso(str(j.publishedAt)),
                },
                str(j.descriptionHtml),
              ),
            );
          }
          return jobs;
        },
      ),
  };
}

/**
 * Himalayas (https://himalayas.app/api): remote jobs, here the ones open to
 * people in India. Terms: credit Himalayas with a visible link, use the
 * applicationLink unchanged, and never pass the jobs on to other boards or
 * Google Jobs (external pages are noindex, without JobPosting markup). The
 * data refreshes daily; 20 jobs a page.
 */
export function himalayas(pages = 10): Provider {
  return {
    id: 'himalayas',
    label: 'Himalayas',
    async fetch(get) {
      const jobs: IngestJob[] = [];
      for (let page = 1; page <= pages; page++) {
        const results = list(rec(await get(`https://himalayas.app/jobs/api/search?country=India&page=${page}`)).jobs);
        for (const raw of results) {
          const j = rec(raw);
          const url = str(j.applicationLink);
          const title = plainText(str(j.title));
          const company = plainText(str(j.companyName));
          const id = str(j.guid) || url;
          if (!/^https:\/\/himalayas\.app\//.test(url) || title.length < 2 || !company) continue;
          const where = list(j.locationRestrictions).map(str).filter(Boolean);
          const min = typeof j.minSalary === 'number' && j.minSalary > 0 ? j.minSalary : null;
          const max = typeof j.maxSalary === 'number' && j.maxSalary > 0 ? j.maxSalary : null;
          const period = periodOf(str(j.salaryPeriod));
          const hasPay = (min != null || max != null) && !!str(j.currency) && !!period;
          const logo = str(j.companyLogo);
          jobs.push(
            baseJob(
              {
                source: 'himalayas',
                externalId: id,
                externalUrl: url,
                title,
                companyName: company,
                logoUrl: /^https:\/\//.test(logo) ? logo : null,
                location:
                  where.length === 0
                    ? 'Remote (Worldwide)'
                    : where.length <= 3
                      ? `Remote (${clamp(where.join(', '), 100)})`
                      : 'Remote (India and other countries)',
                workplace: 'remote',
                employmentType: employmentTypeOf(str(j.employmentType)),
                salaryMin: hasPay ? (min ?? max) : null,
                salaryMax: hasPay ? (max ?? min) : null,
                salaryCurrency: hasPay ? str(j.currency).toUpperCase() : null,
                salaryPeriod: hasPay ? period : null,
                publishedAt: typeof j.pubDate === 'number' ? new Date(j.pubDate * 1000).toISOString() : new Date().toISOString(),
              },
              str(j.description),
            ),
          );
        }
        if (results.length < 20) break;
      }
      return { jobs, complete: false };
    },
  };
}

/**
 * Jobicy (https://jobicy.com/jobs-rss-feed): remote jobs open in APAC or
 * anywhere. Terms: credit Jobicy with a link, and apply links go to the job's
 * Jobicy page. A pass at most once an hour; the feed covers the last 7 days.
 */
export const jobicy: Provider = {
  id: 'jobicy',
  label: 'Jobicy',
  async fetch(get) {
    const jobs: IngestJob[] = [];
    for (const geo of ['apac', 'anywhere']) {
      const data = rec(await get(`https://jobicy.com/api/v2/remote-jobs?count=100&geo=${geo}`));
      for (const raw of list(data.jobs)) {
        const j = rec(raw);
        const url = str(j.url);
        const title = plainText(str(j.jobTitle));
        const company = plainText(str(j.companyName));
        if (j.id == null || !/^https:\/\/jobicy\.com\//.test(url) || title.length < 2 || !company) continue;
        const logo = str(j.companyLogo);
        const where = plainText(str(j.jobGeo), 100);
        const min = typeof j.annualSalaryMin === 'number' ? j.annualSalaryMin : null;
        const max = typeof j.annualSalaryMax === 'number' ? j.annualSalaryMax : null;
        const hasPay = (min != null || max != null) && !!str(j.salaryCurrency);
        jobs.push(
          baseJob(
            {
              source: 'jobicy',
              externalId: String(j.id),
              externalUrl: url,
              title,
              companyName: company,
              logoUrl: /^https:\/\//.test(logo) ? logo : null,
              location: where ? `Remote (${where})` : 'Remote',
              workplace: 'remote',
              employmentType: employmentTypeOf(list(j.jobType).map(str).join(' ')),
              salaryMin: hasPay ? (min ?? max) : null,
              salaryMax: hasPay ? (max ?? min) : null,
              salaryCurrency: hasPay ? str(j.salaryCurrency).toUpperCase() : null,
              salaryPeriod: hasPay ? 'year' : null,
              publishedAt: toIso(str(j.pubDate)),
            },
            str(j.jobDescription),
          ),
        );
      }
    }
    return { jobs, complete: false };
  },
};

/** Remote OK locations a candidate in India can apply from. */
const OPEN_TO_INDIA = /^\s*$|worldwide|anywhere|global|^\s*remote\s*$|india|asia|apac/i;

/**
 * Remote OK (https://remoteok.com/api): remote jobs, keeping those open
 * worldwide or in Asia. Terms: link back to the job on Remote OK (followed
 * links) and name Remote OK as the source; never use their logo.
 */
export const remoteOk: Provider = {
  id: 'remoteok',
  label: 'Remote OK',
  async fetch(get) {
    const jobs: IngestJob[] = [];
    // The first entry is the API's legal notice, not a job.
    for (const raw of list(await get('https://remoteok.com/api'))) {
      const j = rec(raw);
      const url = str(j.url);
      const title = plainText(str(j.position));
      const company = plainText(str(j.company));
      const where = plainText(str(j.location), 100);
      if (j.id == null || !/^https:\/\/remoteok\.com\//i.test(url) || title.length < 2 || !company) continue;
      if (!OPEN_TO_INDIA.test(where)) continue;
      const min = typeof j.salary_min === 'number' && j.salary_min > 0 ? j.salary_min : null;
      const max = typeof j.salary_max === 'number' && j.salary_max > 0 ? j.salary_max : null;
      const hasPay = min != null || max != null;
      jobs.push(
        baseJob(
          {
            source: 'remoteok',
            externalId: String(j.id),
            externalUrl: url,
            title,
            companyName: company,
            location: where && !/^remote$/i.test(where) ? `Remote (${where})` : 'Remote',
            workplace: 'remote',
            employmentType: typeFromTitle(title),
            salaryMin: hasPay ? (min ?? max) : null,
            salaryMax: hasPay ? (max ?? min) : null,
            salaryCurrency: hasPay ? 'USD' : null,
            salaryPeriod: hasPay ? 'year' : null,
            publishedAt: toIso(str(j.date)),
            tags: list(j.tags).map(str).filter(Boolean).slice(0, 20),
          },
          str(j.description),
        ),
      );
    }
    return { jobs, complete: false };
  },
};

function toIso(v: string): string {
  const t = Date.parse(v.endsWith('Z') || /[+-]\d\d:?\d\d$/.test(v) ? v : `${v}Z`);
  return Number.isFinite(t) ? new Date(t).toISOString() : new Date().toISOString();
}
