// POST /api/telemetry/error — the app reports a crash (no sign-in needed,
// rate-limited per IP). Body: { source, message, detail?, route?, release? }.
import { entryFromReport, liveErrorSink } from '../_lib/error-log.js';
import { handle, json, preflight, readJson } from '../_lib/http.js';
import { LIMITS, enforceLimit } from '../_lib/rate-limit.js';

export const OPTIONS = preflight;

export const POST = handle(async (request) => {
  await enforceLimit(request, LIMITS.telemetry);
  const entry = entryFromReport(await readJson(request), request.headers.get('user-agent'));
  if (entry) {
    try {
      await liveErrorSink(entry);
    } catch (e) {
      console.error('telemetry insert failed:', e instanceof Error ? e.message : e);
    }
  }
  // Always 202: a reporting failure must never cause another error report.
  return json(request, 202, { ok: true });
});
