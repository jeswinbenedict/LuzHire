// GET /api/ingest/jobs — imports jobs from job boards and feeds.
// GET /api/ingest/companies — imports India roles from company career boards.
// GET /api/ingest/news — imports career headlines (api/_lib/news/feeds.ts).
// One function for both: the Hobby plan allows 12 functions per deployment.
// Called once a day each by Vercel Cron (vercel.json), which sends
// "Authorization: Bearer $CRON_SECRET". Anyone else is refused.
import { authorizeCron } from '../_lib/cron.js';
import { HttpError, handle, json } from '../_lib/http.js';
import { enabledProviders, liveIngestDeps } from '../_lib/ingest/live.js';
import { runIngest } from '../_lib/ingest/run.js';
import { runNewsIngest } from '../_lib/news/feeds.js';
import { liveNewsDeps } from '../_lib/news/live.js';

export const maxDuration = 60;

export const GET = handle(async (request) => {
  authorizeCron(request, process.env.CRON_SECRET);
  const source = new URL(request.url).pathname.split('/').pop();
  if (source === 'jobs' || source === 'companies') {
    return json(request, 200, { runs: await runIngest(liveIngestDeps(), enabledProviders(source)) });
  }
  if (source === 'news') {
    return json(request, 200, { runs: await runNewsIngest(liveNewsDeps()) });
  }
  throw new HttpError(404, 'not_found', 'Unknown import.');
});
