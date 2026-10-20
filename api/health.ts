// GET /api/health — liveness probe for uptime monitors and CI smoke tests.
// GET /api/health?deep=1 also checks that the database answers; it is cached
// for 30 s at the edge so it cannot be used to load the database.
import { supabaseAdmin } from './_lib/services.js';

export type DbProbe = () => Promise<void>;

const liveProbe: DbProbe = async () => {
  const { error } = await supabaseAdmin()
    .from('jobs')
    .select('id', { head: true, count: 'planned' })
    .limit(1);
  if (error) throw new Error(error.message);
};

export async function healthResponse(request?: Request, probe: DbProbe = liveProbe): Promise<Response> {
  const base = {
    service: 'luzhire-api',
    commit: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? 'local',
    time: new Date().toISOString(),
  };
  const deep = request ? new URL(request.url).searchParams.get('deep') === '1' : false;
  if (!deep) {
    return Response.json({ status: 'ok', ...base }, { headers: { 'Cache-Control': 'no-store' } });
  }
  const started = Date.now();
  let database: 'ok' | 'error' = 'ok';
  try {
    await probe();
  } catch (e) {
    console.error('health: database check failed:', e instanceof Error ? e.message : e);
    database = 'error';
  }
  return Response.json(
    { status: database === 'ok' ? 'ok' : 'degraded', database, databaseMs: Date.now() - started, ...base },
    {
      status: database === 'ok' ? 200 : 503,
      headers: { 'Cache-Control': 'public, max-age=0, s-maxage=30' },
    },
  );
}

// Only the request is taken from the runtime (it may pass extra arguments).
export const GET = (request: Request): Promise<Response> => healthResponse(request);
