import { describe, expect, it } from 'vitest';
import {
  codeforces,
  hackclub,
  runEventsIngest,
  type EventDeps,
  type EventProvider,
  type EventRunLog,
  type ImportedEvent,
  type StoredEvent,
} from '../../api/_lib/events/feeds.js';

describe('event sources', () => {
  it('Codeforces: upcoming contests only, with their length and page', async () => {
    const urls: string[] = [];
    const { events, complete } = await codeforces.fetch(async (url) => {
      urls.push(url);
      return {
        status: 'OK',
        result: [
          { id: 2280, name: 'Codeforces Round (Div. 2)', phase: 'BEFORE', durationSeconds: 9000, startTimeSeconds: 1793_000_000 },
          { id: 2270, name: 'Educational Round', phase: 'FINISHED', durationSeconds: 7200, startTimeSeconds: 1790_000_000 },
          { id: 2281, name: 'ICPC 2026 Online Challenge', phase: 'BEFORE', durationSeconds: 1209600, startTimeSeconds: 1793_100_000 },
        ],
      };
    });
    expect(urls).toEqual(['https://codeforces.com/api/contest.list?gym=false']);
    expect(complete).toBe(true);
    expect(events.map((e) => e.externalId)).toEqual(['2280', '2281']);
    expect(events[0]).toMatchObject({
      source: 'codeforces',
      kind: 'competition',
      mode: 'online',
      organizerName: 'Codeforces',
      startsAt: new Date(1793_000_000 * 1000).toISOString(),
      endsAt: new Date((1793_000_000 + 9000) * 1000).toISOString(),
      registrationDeadline: new Date(1793_000_000 * 1000).toISOString(),
      registrationUrl: 'https://codeforces.com/contests/2280',
      summary: 'Online programming contest on Codeforces, 2 h 30 min.',
    });
    expect(events[1]!.summary).toContain('14 days');
  });

  it('Codeforces: an API error is reported, not imported', async () => {
    await expect(codeforces.fetch(async () => ({ status: 'FAILED', comment: 'Call limit exceeded' }))).rejects.toThrow('Call limit exceeded');
  });

  it('Hack Club: online and hybrid hackathons, in person only nearby', async () => {
    const { events } = await hackclub.fetch(async () => [
      { id: 'a', name: 'Build for Earth', website: 'https://earth.example.org', start: '2026-11-08T10:00:00Z', end: '2026-11-09T10:00:00Z', virtual: true },
      { id: 'b', name: 'Teens Hack Houston', website: 'https://tripleh.example', start: '2026-11-14T12:00:00Z', end: '2026-11-21T23:00:00Z', city: 'Houston', state: 'Texas', country: 'United States', hybrid: true },
      { id: 'c', name: 'Mango Hacks', website: 'https://mango.example', start: '2026-12-05T16:00:00Z', city: 'Pleasanton', country: 'United States' },
      { id: 'd', name: 'Hack Bengaluru', website: 'https://hackblr.example', start: '2026-12-01T04:00:00Z', city: 'Bengaluru', country: 'India', countryCode: 'IN' },
      { id: 'e', name: 'Unsafe', website: 'http://insecure.example', start: '2026-12-01T04:00:00Z', virtual: true },
    ]);
    expect(events.map((e) => [e.externalId, e.mode, e.locationText])).toEqual([
      ['a', 'online', null],
      ['b', 'hybrid', 'Houston, Texas, United States'],
      ['d', 'in_person', 'Bengaluru, India'],
    ]);
    expect(events[0]).toMatchObject({ kind: 'hackathon', registrationUrl: 'https://earth.example.org/', registrationDeadline: null });
    expect(events[1]!.summary).toContain('online and in Houston');
  });
});

describe('runEventsIngest', () => {
  const ev = (source: string, id: string): ImportedEvent => ({
    source,
    externalId: id,
    kind: 'competition',
    title: `Contest ${id}`,
    organizerName: 'Codeforces',
    mode: 'online',
    locationText: null,
    startsAt: '2026-11-07T14:35:00.000Z',
    endsAt: null,
    registrationDeadline: null,
    registrationUrl: `https://codeforces.com/contests/${id}`,
    summary: null,
    descriptionMd: '',
  });

  function deps(stored: StoredEvent[]) {
    const upserted: ImportedEvent[] = [];
    const cancelled: string[] = [];
    const logs: EventRunLog[] = [];
    const d: EventDeps = {
      get: async () => ({}),
      now: () => new Date('2026-10-25T00:00:00Z'),
      existing: async () => stored,
      upsert: async (e) => {
        upserted.push(...e);
      },
      cancel: async (ids) => {
        cancelled.push(...ids);
      },
      log: async (l) => {
        logs.push(l);
      },
    };
    return { d, upserted, cancelled, logs };
  }

  it('adds new events, updates known ones and cancels future ones that were called off', async () => {
    const stored: StoredEvent[] = [
      { id: 'db-1', source: 'codeforces', externalId: '1', status: 'published', startsAt: '2026-11-01T00:00:00Z' },
      { id: 'db-gone', source: 'codeforces', externalId: 'gone', status: 'published', startsAt: '2026-11-02T00:00:00Z' },
      { id: 'db-past', source: 'codeforces', externalId: 'past', status: 'published', startsAt: '2026-10-01T00:00:00Z' },
    ];
    const f = deps(stored);
    const provider: EventProvider = { id: 'codeforces', label: 'Codeforces', fetch: async () => ({ events: [ev('codeforces', '1'), ev('codeforces', '2')], complete: true }) };
    const [log] = await runEventsIngest(f.d, [provider]);
    expect(f.upserted.map((e) => e.externalId)).toEqual(['1', '2']);
    expect(f.cancelled).toEqual(['db-gone']); // the past one just drops off the page
    expect(log).toMatchObject({ source: 'events:codeforces', fetched: 2, inserted: 1, updated: 1, closed: 1, error: null });
  });

  it('a failing source is logged and the others still import', async () => {
    const f = deps([]);
    const broken: EventProvider = { id: 'hackclub', label: 'Hack Club', fetch: async () => { throw new Error('hackathons.hackclub.com answered 503'); } };
    const ok: EventProvider = { id: 'codeforces', label: 'Codeforces', fetch: async () => ({ events: [ev('codeforces', '9')], complete: true }) };
    const logs = await runEventsIngest(f.d, [broken, ok]);
    expect(logs[0]).toMatchObject({ source: 'events:hackclub', error: 'hackathons.hackclub.com answered 503' });
    expect(logs[1]).toMatchObject({ source: 'events:codeforces', inserted: 1 });
  });
});
