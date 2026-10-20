// Provider adapters. Each returns normalised jobs and whether the result is
// the provider's complete current list (then missing jobs can be closed).
import {
  clamp,
  employmentTypeOf,
  htmlToMarkdown,
  parseSalary,
  plainText,
  summaryOf,
  type IngestJob,
} from './normalize.js';

export type Fetcher = (url: string) => Promise<unknown>;

export interface ProviderResult {
  jobs: IngestJob[];
  /** True when `jobs` is everything the provider currently lists. */
  complete: boolean;
}

export interface Provider {
  id: string;
  /** Shown on cards and detail pages ("Listed on …", attribution). */
  label: string;
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

function toIso(v: string): string {
  const t = Date.parse(v.endsWith('Z') || /[+-]\d\d:?\d\d$/.test(v) ? v : `${v}Z`);
  return Number.isFinite(t) ? new Date(t).toISOString() : new Date().toISOString();
}
