// POST /api/notify/dispatch — sends push and email for new notifications.
// Called by a Supabase database webhook on notifications INSERT, which sends
// "Authorization: Bearer $NOTIFY_SECRET". Anyone else is refused. Safe to
// call repeatedly: each notification is claimed and delivered once.
import { authorizeCron } from '../_lib/cron.js';
import { handle, json } from '../_lib/http.js';
import { dispatch } from '../_lib/notify/dispatch.js';
import { dispatchConfig, liveDispatchDeps } from '../_lib/notify/live.js';

export const maxDuration = 30;

export const POST = handle(async (request) => {
  authorizeCron(request, process.env.NOTIFY_SECRET, 'NOTIFY_SECRET');
  const origin = new URL(request.url).origin;
  const summary = await dispatch(liveDispatchDeps(), dispatchConfig(origin));
  return json(request, 200, summary);
});
