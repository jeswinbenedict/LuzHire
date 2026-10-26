// Production wiring for the events import (service role; bypasses RLS).
import { getJson } from '../ingest/live.js';
import { supabaseAdmin } from '../services.js';
import type { EventDeps, ImportedEvent, StoredEvent } from './feeds.js';

export function liveEventDeps(): EventDeps {
  const db = supabaseAdmin();
  const fail = (what: string, error: { message: string } | null) => {
    if (error) throw new Error(`${what}: ${error.message}`);
  };
  return {
    get: getJson,
    now: () => new Date(),
    async existing() {
      const { data, error } = await db
        .from('events')
        .select('id, external_source, external_id, status, starts_at')
        .not('external_source', 'is', null);
      fail('existing events', error);
      return (data ?? []).map(
        (r): StoredEvent => ({
          id: r.id as string,
          source: r.external_source as string,
          externalId: r.external_id as string,
          status: r.status as string,
          startsAt: r.starts_at as string,
        }),
      );
    },
    async upsert(events: ImportedEvent[]) {
      const rows = events.map((e) => ({
        external_source: e.source,
        external_id: e.externalId,
        kind: e.kind,
        status: 'published',
        title: e.title,
        organizer_name: e.organizerName,
        mode: e.mode,
        location_text: e.locationText,
        starts_at: e.startsAt,
        ends_at: e.endsAt,
        registration_deadline: e.registrationDeadline,
        registration_url: e.registrationUrl,
        summary: e.summary,
        description_md: e.descriptionMd,
        logo_url: e.logoUrl,
        banner_url: e.bannerUrl,
      }));
      const { error } = await db.from('events').upsert(rows, { onConflict: 'external_source,external_id' });
      fail('events upsert', error);
    },
    async cancel(ids) {
      const { error } = await db.from('events').update({ status: 'cancelled' }).in('id', ids);
      fail('events cancel', error);
    },
    async log(run) {
      const { error } = await db.from('ingest_runs').insert({ ...run, finished_at: new Date().toISOString() });
      fail('log', error);
    },
  };
}
