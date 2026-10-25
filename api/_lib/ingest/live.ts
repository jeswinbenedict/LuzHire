// Production wiring for the ingest run (service role; bypasses RLS).
import { supabaseAdmin } from '../services.js';
import type { IngestJob } from './normalize.js';
import { adzuna, ashby, greenhouse, himalayas, jobicy, lever, remoteOk, remotive, type Provider } from './providers.js';
import type { ExistingJob, IngestDeps } from './run.js';

/**
 * The two daily imports, each sized to finish within the function's time
 * limit: job boards and feeds, and companies' own career boards (several MB
 * each).
 */
export type IngestGroup = 'jobs' | 'companies';

/** Providers of a group enabled by the environment (Adzuna needs its keys). */
export function enabledProviders(group: IngestGroup = 'jobs', env: NodeJS.ProcessEnv = process.env): Provider[] {
  if (group === 'companies') return [greenhouse(), lever(), ashby()];
  const list: Provider[] = [remotive, himalayas(), jobicy, remoteOk];
  if (env.ADZUNA_APP_ID && env.ADZUNA_APP_KEY) {
    list.push(adzuna(env.ADZUNA_APP_ID, env.ADZUNA_APP_KEY));
  }
  return list;
}

async function getJson(url: string): Promise<unknown> {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'LuzHire job portal (college project) - luzhire.vercel.app' },
    signal: AbortSignal.timeout(40_000), // some Lever boards take ~20 s
  });
  if (!res.ok) throw new Error(`${new URL(url).host} answered ${res.status}`);
  return res.json();
}

function slugifyTag(s: string): string {
  return s.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

export function liveIngestDeps(): IngestDeps {
  const db = supabaseAdmin();
  const fail = (what: string, error: { message: string } | null) => {
    if (error) throw new Error(`${what}: ${error.message}`);
  };
  return {
    get: getJson,
    now: () => new Date(),
    async existing() {
      // PostgREST returns at most 1000 rows per request, so read in pages.
      const data: Record<string, unknown>[] = [];
      for (let from = 0; ; from += 1000) {
        const { data: page, error } = await db
          .from('jobs')
          .select('id, external_source, external_id, title, company_name, status, published_at, external_logo_url')
          .eq('source', 'external')
          .order('id')
          .range(from, from + 999);
        fail('existing', error);
        data.push(...(page ?? []));
        if ((page ?? []).length < 1000) break;
      }
      return data.map(
        (r): ExistingJob => ({
          id: r.id as string,
          source: r.external_source as string,
          externalId: r.external_id as string,
          title: r.title as string,
          companyName: r.company_name as string,
          status: r.status as string,
          publishedAt: (r.published_at as string | null) ?? null,
          logoUrl: (r.external_logo_url as string | null) ?? null,
        }),
      );
    },
    async upsert(jobs: IngestJob[]) {
      const rows = jobs.map((j) => ({
        source: 'external',
        status: 'published',
        external_source: j.source,
        external_id: j.externalId,
        external_url: j.externalUrl,
        external_logo_url: j.logoUrl,
        company_name: j.companyName,
        title: j.title,
        summary: j.summary,
        description_md: j.descriptionMd,
        employment_type: j.employmentType,
        workplace: j.workplace,
        location_text: j.location,
        salary_min: j.salaryMin,
        salary_max: j.salaryMax,
        salary_currency: j.salaryCurrency,
        salary_period: j.salaryPeriod,
        published_at: j.publishedAt,
      }));
      const out: { id: string; source: string; externalId: string }[] = [];
      for (let i = 0; i < rows.length; i += 200) {
        const { data, error } = await db
          .from('jobs')
          .upsert(rows.slice(i, i + 200), { onConflict: 'external_source,external_id' })
          .select('id, external_source, external_id');
        fail('upsert', error);
        for (const r of data ?? []) {
          out.push({
            id: r.id as string,
            source: r.external_source as string,
            externalId: r.external_id as string,
          });
        }
      }
      return out;
    },
    async linkSkills(tagsByJobId) {
      const slugs = [...new Set([...tagsByJobId.values()].flat().map(slugifyTag))].filter(Boolean);
      if (slugs.length === 0) return;
      const { data, error } = await db.from('skills').select('id, slug').in('slug', slugs);
      fail('skills', error);
      const idBySlug = new Map((data ?? []).map((s) => [s.slug as string, s.id as number]));
      const links: { job_id: string; skill_id: number }[] = [];
      for (const [jobId, tags] of tagsByJobId) {
        for (const id of new Set(tags.map(slugifyTag).map((t) => idBySlug.get(t)))) {
          if (id != null) links.push({ job_id: jobId, skill_id: id });
        }
      }
      if (links.length === 0) return;
      const { error: linkError } = await db
        .from('job_skills')
        .upsert(links, { onConflict: 'job_id,skill_id', ignoreDuplicates: true });
      fail('job_skills', linkError);
    },
    async close(ids) {
      for (let i = 0; i < ids.length; i += 200) {
        const { error } = await db
          .from('jobs')
          .update({ status: 'closed' })
          .in('id', ids.slice(i, i + 200));
        fail('close', error);
      }
    },
    logos: {
      async suggest(name) {
        const res = await fetch(
          `https://autocomplete.clearbit.com/v1/companies/suggest?query=${encodeURIComponent(name)}`,
          { signal: AbortSignal.timeout(5000) },
        );
        if (!res.ok) return [];
        const rows = (await res.json()) as unknown;
        return Array.isArray(rows)
          ? rows
              .map((r) => r as { name?: unknown; domain?: unknown })
              .filter((r) => typeof r.name === 'string' && typeof r.domain === 'string')
              .map((r) => ({ name: r.name as string, domain: r.domain as string }))
          : [];
      },
      async imageOk(url) {
        const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
        await res.arrayBuffer();
        return res.ok && (res.headers.get('content-type') ?? '').startsWith('image/');
      },
    },
    async log(run) {
      const { error } = await db.from('ingest_runs').insert({
        ...run,
        finished_at: new Date().toISOString(),
      });
      fail('log', error);
    },
  };
}
