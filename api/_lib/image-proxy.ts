// Same-origin copies of third-party job logos. Flutter web draws images on a
// canvas, which needs CORS; providers such as Remotive and Himalayas send none (and no
// caching), so the app loads their logos through /api/img instead.
// Not an open proxy: only listed hosts, no redirects, raster images only.

export const IMAGE_HOSTS = new Set([
  'remotive.com',
  'www.remotive.com',
  'cdn.hashnode.com',
  'cdn-images.himalayas.app',
  // News covers and Jobicy logos send CORS headers, but the site's CSP keeps
  // fetch() (which Flutter web uses for images) to LuzHire's own hosts.
  'media2.dev.to',
  'jobicy.com',
]);

const TYPES = new Set(['image/png', 'image/jpeg', 'image/gif', 'image/webp']);
export const MAX_IMAGE_BYTES = 1_000_000;

export type ImageFetcher = (url: string) => Promise<Response>;

export interface ProxyResult {
  status: number;
  body: Uint8Array | string;
  headers: Record<string, string>;
}

const deny = (status: number, message: string): ProxyResult => ({
  status,
  body: message,
  headers: {
    'Content-Type': 'text/plain; charset=utf-8',
    // Misses are cached briefly so a broken logo is not refetched per view.
    'Cache-Control': status === 400 || status === 403 ? 'public, max-age=3600' : 'public, max-age=300, s-maxage=300',
  },
});

/** The allowed upstream URL for a ?u= value, or null. */
export function allowedImageUrl(raw: string | null): URL | null {
  if (!raw || raw.length > 500) return null;
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' || url.username || url.password || url.port) return null;
  return IMAGE_HOSTS.has(url.hostname) ? url : null;
}

export async function proxyImage(raw: string | null, get: ImageFetcher): Promise<ProxyResult> {
  const url = allowedImageUrl(raw);
  if (!url) return deny(403, 'Image host not allowed.');
  let res: Response;
  try {
    res = await get(url.toString());
  } catch {
    return deny(502, 'Image unavailable.');
  }
  const type = (res.headers.get('content-type') ?? '').split(';')[0]!.trim().toLowerCase();
  const declared = Number(res.headers.get('content-length') ?? '0');
  if (!res.ok || !TYPES.has(type) || declared > MAX_IMAGE_BYTES) {
    return deny(404, 'Image unavailable.');
  }
  const bytes = new Uint8Array(await res.arrayBuffer());
  if (bytes.byteLength === 0 || bytes.byteLength > MAX_IMAGE_BYTES) return deny(404, 'Image unavailable.');
  return {
    status: 200,
    body: bytes,
    headers: {
      'Content-Type': type,
      'Cache-Control': 'public, max-age=86400, s-maxage=604800, stale-while-revalidate=86400',
      'Content-Security-Policy': "default-src 'none'; sandbox",
      'X-Content-Type-Options': 'nosniff',
    },
  };
}
