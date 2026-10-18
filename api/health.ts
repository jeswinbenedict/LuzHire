// GET /api/health — liveness probe for uptime monitors and CI smoke tests.
export function GET(): Response {
  return Response.json(
    {
      status: 'ok',
      service: 'luzhire-api',
      commit: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? 'local',
      time: new Date().toISOString(),
    },
    { headers: { 'Cache-Control': 'no-store' } },
  );
}
