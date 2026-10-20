// GET /api/img?u=<https URL> — a cached same-origin copy of an allowed
// provider's job logo (see api/_lib/image-proxy.ts).
import { proxyImage } from './_lib/image-proxy.js';

export async function GET(request: Request): Promise<Response> {
  const raw = new URL(request.url).searchParams.get('u');
  const result = await proxyImage(raw, (url) =>
    fetch(url, {
      redirect: 'error',
      signal: AbortSignal.timeout(5000),
      headers: { 'User-Agent': 'LuzHire job portal (college project)', Accept: 'image/*' },
    }),
  );
  return new Response(result.body as BodyInit, { status: result.status, headers: result.headers });
}
