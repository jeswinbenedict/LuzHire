// POST /api/csp-report — browsers send Content-Security-Policy violations
// here (report-uri in vercel.json). Stored in the admin error log.
import { entriesFromCspReport } from './_lib/csp-report.js';
import { liveErrorSink } from './_lib/error-log.js';
import { handle } from './_lib/http.js';
import { LIMITS, enforceLimit } from './_lib/rate-limit.js';

export const POST = handle(async (request) => {
  await enforceLimit(request, LIMITS.csp);
  let body: unknown = null;
  try {
    // Sent as application/csp-report, which is JSON.
    body = JSON.parse(await request.text());
  } catch {
    body = null;
  }
  for (const entry of entriesFromCspReport(body, request.headers.get('user-agent'))) {
    try {
      await liveErrorSink(entry);
    } catch (e) {
      console.error('csp report insert failed:', e instanceof Error ? e.message : e);
    }
  }
  return new Response(null, { status: 204 });
});
