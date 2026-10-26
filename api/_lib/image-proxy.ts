// Same-origin copies of third-party job logos. Flutter web draws images on a
// canvas, which needs CORS; providers such as Remotive and Himalayas send none (and no
// caching), so the app loads their logos through /api/img instead.
// Not an open proxy: only listed hosts, raster images only, and a redirect
// is followed only from a host in REDIRECTS to its own storage host.

export const IMAGE_HOSTS = new Set([
  'remotive.com',
  'www.remotive.com',
  'cdn.hashnode.com',
  'cdn-images.himalayas.app',
  // News covers and Jobicy logos send CORS headers, but the site's CSP keeps
  // fetch() (which Flutter web uses for images) to LuzHire's own hosts.
  'media2.dev.to',
  'jobicy.com',
  // Company logos for career-board jobs (Google's favicon service).
  't1.gstatic.com',
  // Hackathon logos and banners (Hack Club's directory).
  'dash.hackathons.hackclub.com',
]);

/**
 * Hosts whose image links redirect (once) to short-lived storage URLs, and
 * the only host each may redirect to.
 */
export const REDIRECTS: Record<string, string> = {
  'dash.hackathons.hackclub.com': 'hackathons-hackclub.s3.amazonaws.com',
};

const TYPES = new Set(['image/png', 'image/jpeg', 'image/gif', 'image/webp']);
/** Room for event banners (up to 1920 × 1080). */
export const MAX_IMAGE_BYTES = 3_000_000;

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
    // One hop, and only to the storage host this source is known to use.
    if (res.status >= 300 && res.status < 400) {
      const target = res.headers.get('location');
      const next = target ? new URL(target, url) : null;
      if (!next || next.protocol !== 'https:' || next.hostname !== REDIRECTS[url.hostname]) {
        return deny(404, 'Image unavailable.');
      }
      res = await get(next.toString());
      if (res.status >= 300 && res.status < 400) return deny(404, 'Image unavailable.');
    }
  } catch {
    return deny(502, 'Image unavailable.');
  }
  const type = (res.headers.get('content-type') ?? '').split(';')[0]!.trim().toLowerCase();
  const declared = Number(res.headers.get('content-length') ?? '0');
  if (!res.ok || !TYPES.has(type) || declared > MAX_IMAGE_BYTES) {
    return deny(404, 'Image unavailable.');
  }
  let bytes: Uint8Array;
  try {
    bytes = new Uint8Array(await res.arrayBuffer());
  } catch {
    // Timed out or cut off while downloading.
    return deny(502, 'Image unavailable.');
  }
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
