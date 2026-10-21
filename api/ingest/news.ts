// GET /api/ingest/news — imports career headlines from the feeds in
// api/_lib/news/feeds.ts. Called once a day by Vercel Cron (vercel.json),
// which sends "Authorization: Bearer $CRON_SECRET". Anyone else is refused.
import { authorizeCron } from '../_lib/cron.js';
import { handle, json } from '../_lib/http.js';
import { runNewsIngest } from '../_lib/news/feeds.js';
import { liveNewsDeps } from '../_lib/news/live.js';

export const maxDuration = 60;

export const GET = handle(async (request) => {
  authorizeCron(request, process.env.CRON_SECRET);
  const runs = await runNewsIngest(liveNewsDeps());
  return json(request, 200, { runs });
});
