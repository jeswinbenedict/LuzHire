// Events from sources whose terms allow showing them, with a link to the
// organiser's page for registration:
//  - Codeforces: the official public API (contest.list), coding contests.
//  - Hack Club: the open-source hackathon directory's public API, keeping
//    online and hybrid hackathons and in-person ones in Asia-Pacific.
// Devpost and MLH were left out: their terms forbid republishing listings.
import { clamp, plainText } from '../ingest/normalize.js';
import type { Fetcher } from '../ingest/providers.js';

export type EventKind = 'competition' | 'hackathon';
export type EventMode = 'online' | 'hybrid' | 'in_person';

export interface ImportedEvent {
  source: string;
  externalId: string;
  kind: EventKind;
  title: string;
  organizerName: string;
  mode: EventMode;
  locationText: string | null;
  startsAt: string; // ISO
  endsAt: string | null;
  registrationDeadline: string | null;
  registrationUrl: string;
  summary: string | null;
  descriptionMd: string;
}

export interface EventProvider {
  id: string;
  label: string;
  fetch(get: Fetcher): Promise<{ events: ImportedEvent[]; complete: boolean }>;
}

type Rec = Record<string, unknown>;
const rec = (v: unknown): Rec => (v && typeof v === 'object' ? (v as Rec) : {});
const list = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const str = (v: unknown) => (typeof v === 'string' ? v : '');

const httpsUrl = (s: string): string | null => {
  try {
    const u = new URL(s.trim());
    return u.protocol === 'https:' ? u.toString() : null;
  } catch {
    return null;
  }
};

function duration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.round((seconds % 3600) / 60);
  if (h >= 48) return `${Math.round(h / 24)} days`;
  return [h ? `${h} h` : '', m ? `${m} min` : ''].filter(Boolean).join(' ');
}

/** Codeforces contests that have not started yet (the list is complete). */
export const codeforces: EventProvider = {
  id: 'codeforces',
  label: 'Codeforces',
  async fetch(get) {
    const data = rec(await get('https://codeforces.com/api/contest.list?gym=false'));
    if (data.status !== 'OK') throw new Error(`codeforces.com answered ${str(data.comment) || 'an error'}`);
    const events: ImportedEvent[] = [];
    for (const raw of list(data.result)) {
      const c = rec(raw);
      if (c.phase !== 'BEFORE' || typeof c.id !== 'number' || typeof c.startTimeSeconds !== 'number') continue;
      const title = plainText(str(c.name), 160);
      if (title.length < 4) continue;
      const seconds = typeof c.durationSeconds === 'number' ? c.durationSeconds : 0;
      const start = new Date(c.startTimeSeconds * 1000);
      const length = seconds > 0 ? duration(seconds) : null;
      events.push({
        source: 'codeforces',
        externalId: String(c.id),
        kind: 'competition',
        title,
        organizerName: 'Codeforces',
        mode: 'online',
        locationText: null,
        startsAt: start.toISOString(),
        endsAt: seconds > 0 ? new Date(start.getTime() + seconds * 1000).toISOString() : null,
        registrationDeadline: start.toISOString(),
        registrationUrl: `https://codeforces.com/contests/${c.id}`,
        summary: `Online programming contest on Codeforces${length ? `, ${length}` : ''}.`,
        descriptionMd:
          `An online competitive programming contest on Codeforces${length ? ` lasting ${length}` : ''}. ` +
          'Register on Codeforces before it starts; problems are solved in the language of your choice.',
      });
    }
    return { events, complete: true };
  },
};

/**
 * Hack Club's directory of upcoming hackathons (the list is complete). Kept:
 * online and hybrid ones, and in-person ones in Asia-Pacific or India.
 */
export const hackclub: EventProvider = {
  id: 'hackclub',
  label: 'Hack Club',
  async fetch(get) {
    const events: ImportedEvent[] = [];
    for (const raw of list(await get('https://hackathons.hackclub.com/api/events/upcoming/'))) {
      const e = rec(raw);
      const url = httpsUrl(str(e.website));
      const title = plainText(str(e.name), 160);
      const start = Date.parse(str(e.start));
      if (!str(e.id) || !url || title.length < 4 || !Number.isFinite(start)) continue;
      const place = [str(e.city), str(e.state), str(e.country)].map((p) => plainText(p, 60)).filter(Boolean);
      const nearby = e.apac === true || str(e.countryCode).toUpperCase() === 'IN';
      let mode: EventMode = e.virtual === true ? 'online' : e.hybrid === true ? 'hybrid' : 'in_person';
      if (mode === 'in_person' && !nearby) continue;
      if (mode !== 'online' && place.length === 0) mode = 'online'; // nowhere to go
      const end = Date.parse(str(e.end));
      const location = mode === 'online' ? null : clamp(place.join(', '), 120);
      const where = mode === 'online' ? 'online' : `${mode === 'hybrid' ? 'online and in ' : 'in '}${location}`;
      events.push({
        source: 'hackclub',
        externalId: str(e.id),
        kind: 'hackathon',
        title,
        organizerName: clamp(title, 120),
        mode,
        locationText: location,
        startsAt: new Date(start).toISOString(),
        endsAt: Number.isFinite(end) && end >= start ? new Date(end).toISOString() : null,
        registrationDeadline: null,
        registrationUrl: url,
        summary: clamp(`A hackathon ${where}, listed in Hack Club's hackathon directory.`, 300),
        descriptionMd:
          `${title} is a hackathon ${where}. Teams build a project over the event and present it at the end. ` +
          "See the organiser's site for themes, prizes and how to take part.",
      });
    }
    return { events, complete: true };
  },
};

export const EVENT_PROVIDERS: EventProvider[] = [codeforces, hackclub];

// ---------------------------------------------------------------- run

export interface StoredEvent {
  id: string;
  source: string;
  externalId: string;
  status: string;
  startsAt: string;
}

export interface EventRunLog {
  source: string;
  fetched: number;
  inserted: number;
  updated: number;
  skipped: number;
  closed: number;
  error: string | null;
}

export interface EventDeps {
  get: Fetcher;
  now(): Date;
  /** Imported events already stored. */
  existing(): Promise<StoredEvent[]>;
  /** Inserts or updates by (external_source, external_id). */
  upsert(events: ImportedEvent[]): Promise<void>;
  /** Marks events as cancelled. */
  cancel(ids: string[]): Promise<void>;
  log(run: EventRunLog): Promise<void>;
}

/**
 * Imports each provider. A future event that has gone from a complete list
 * was called off, so it is cancelled; past events simply drop off the page.
 */
export async function runEventsIngest(deps: EventDeps, providers: EventProvider[] = EVENT_PROVIDERS): Promise<EventRunLog[]> {
  const existing = await deps.existing();
  const now = deps.now().getTime();
  return Promise.all(
    providers.map(async (provider) => {
      const log: EventRunLog = { source: `events:${provider.id}`, fetched: 0, inserted: 0, updated: 0, skipped: 0, closed: 0, error: null };
      try {
        const { events, complete } = await provider.fetch(deps.get);
        log.fetched = events.length;
        const mine = new Map(existing.filter((e) => e.source === provider.id).map((e) => [e.externalId, e] as const));
        if (events.length > 0) await deps.upsert(events);
        for (const e of events) {
          if (mine.has(e.externalId)) log.updated++;
          else log.inserted++;
        }
        if (complete) {
          const listed = new Set(events.map((e) => e.externalId));
          const gone = [...mine.values()]
            .filter((e) => e.status === 'published' && !listed.has(e.externalId) && Date.parse(e.startsAt) > now)
            .map((e) => e.id);
          if (gone.length > 0) await deps.cancel(gone);
          log.closed = gone.length;
        }
      } catch (e) {
        log.error = clamp(e instanceof Error ? e.message : String(e), 500);
      }
      await deps.log(log);
      return log;
    }),
  );
}
