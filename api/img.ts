// GET /api/img?u=<https URL> — a cached same-origin copy of an allowed
// provider's job logo (see api/_lib/image-proxy.ts).
import { proxyImage } from './_lib/image-proxy.js';

export async function GET(request: Request): Promise<Response> {
  const raw = new URL(request.url).searchParams.get('u');
  const result = await proxyImage(raw, (url) =>
    fetch(url, {
      // Redirects come back to proxyImage, which follows only allowed ones.
      redirect: 'manual',
      signal: AbortSignal.timeout(10_000), // banners can be a few MB
      headers: { 'User-Agent': 'LuzHire job portal (college project)', Accept: 'image/*' },
    }),
  );
  return new Response(result.body as BodyInit, { status: result.status, headers: result.headers });
}
