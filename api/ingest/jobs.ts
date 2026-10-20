// GET /api/ingest/jobs — imports jobs from the enabled providers.
// Called once a day by Vercel Cron (vercel.json), which sends
// "Authorization: Bearer $CRON_SECRET". Anyone else is refused.
import { authorizeCron } from '../_lib/cron.js';
import { handle, json } from '../_lib/http.js';
import { enabledProviders, liveIngestDeps } from '../_lib/ingest/live.js';
import { runIngest } from '../_lib/ingest/run.js';

export const maxDuration = 60;

export const GET = handle(async (request) => {
  authorizeCron(request, process.env.CRON_SECRET);
  const logs = await runIngest(liveIngestDeps(), enabledProviders());
  return json(request, 200, { runs: logs });
});
