// One ingestion run: fetch each provider, de-duplicate, upsert, expire, log.
import { dedupeKey, type IngestJob } from './normalize.js';
import type { Fetcher, Provider } from './providers.js';

/** Jobs older than this are not imported and are closed when found. */
export const MAX_AGE_DAYS = 30;

export interface ExistingJob {
  id: string;
  source: string;
  externalId: string;
  title: string;
  companyName: string;
  status: string;
  publishedAt: string | null;
}

export interface RunLog {
  source: string;
  fetched: number;
  inserted: number;
  updated: number;
  skipped: number;
  closed: number;
  error: string | null;
}

export interface IngestDeps {
  get: Fetcher;
  now(): Date;
  /** External jobs already stored (any status). */
  existing(): Promise<ExistingJob[]>;
  /** Inserts or updates by (external_source, external_id); returns ids. */
  upsert(jobs: IngestJob[]): Promise<{ id: string; source: string; externalId: string }[]>;
  /** Links tags to skills that already exist (never creates skills). */
  linkSkills(tagsByJobId: Map<string, string[]>): Promise<void>;
  close(ids: string[]): Promise<void>;
  log(run: RunLog): Promise<void>;
}

export async function runIngest(deps: IngestDeps, providers: Provider[]): Promise<RunLog[]> {
  const logs: RunLog[] = [];
  const existing = await deps.existing();
  const now = deps.now().getTime();
  const tooOld = (iso: string | null) =>
    iso != null && now - Date.parse(iso) > MAX_AGE_DAYS * 86_400_000;

  for (const provider of providers) {
    const log: RunLog = {
      source: provider.id,
      fetched: 0,
      inserted: 0,
      updated: 0,
      skipped: 0,
      closed: 0,
      error: null,
    };
    try {
      const { jobs, complete } = await provider.fetch(deps.get);
      log.fetched = jobs.length;

      const mine = new Map(
        existing
          .filter((e) => e.source === provider.id)
          .map((e) => [e.externalId, e] as const),
      );
      // Live jobs from other providers: a second copy would be a duplicate.
      const elsewhere = new Set(
        existing
          .filter((e) => e.source !== provider.id && e.status === 'published')
          .map((e) => dedupeKey(e.title, e.companyName)),
      );

      const keep: IngestJob[] = [];
      const seenIds = new Set<string>();
      const seenKeys = new Set<string>();
      for (const job of jobs) {
        const key = dedupeKey(job.title, job.companyName);
        if (
          tooOld(job.publishedAt) ||
          seenIds.has(job.externalId) ||
          seenKeys.has(key) ||
          (!mine.has(job.externalId) && elsewhere.has(key))
        ) {
          log.skipped++;
          continue;
        }
        seenIds.add(job.externalId);
        seenKeys.add(key);
        keep.push(job);
      }

      if (keep.length > 0) {
        const saved = await deps.upsert(keep);
        for (const job of keep) {
          if (mine.has(job.externalId)) log.updated++;
          else log.inserted++;
        }
        const idOf = new Map(saved.map((s) => [s.externalId, s.id] as const));
        const tags = new Map<string, string[]>();
        for (const job of keep) {
          const id = idOf.get(job.externalId);
          if (id && job.tags.length > 0) tags.set(id, job.tags);
        }
        if (tags.size > 0) await deps.linkSkills(tags);
      }

      // Expire: gone from a complete feed, or simply too old.
      const keptIds = new Set(keep.map((j) => j.externalId));
      const toClose = [...mine.values()]
        .filter(
          (e) =>
            e.status === 'published' &&
            ((complete && !keptIds.has(e.externalId)) ||
              (!keptIds.has(e.externalId) && tooOld(e.publishedAt))),
        )
        .map((e) => e.id);
      if (toClose.length > 0) await deps.close(toClose);
      log.closed = toClose.length;
    } catch (e) {
      log.error = e instanceof Error ? e.message.slice(0, 500) : 'Unknown error';
    }
    await deps.log(log);
    logs.push(log);
  }
  return logs;
}
