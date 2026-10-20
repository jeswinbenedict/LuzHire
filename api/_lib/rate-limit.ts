// Per-caller rate limits for the API, counted in Postgres
// (public.rate_limit_hit) because Vercel Functions keep no state.
import { HttpError } from './http.js';
import { supabaseAdmin } from './services.js';

/** Returns true while the caller is within the limit. */
export type RateLimiter = (bucket: string, max: number, windowSeconds: number) => Promise<boolean>;

/** The caller's IP as Vercel reports it (first hop of x-forwarded-for). */
export function clientIp(request: Request): string {
  const real = request.headers.get('x-real-ip')?.trim();
  if (real) return real;
  const forwarded = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  return forwarded || 'unknown';
}

export interface Limit {
  /** Short name of the endpoint, e.g. "bootstrap". */
  name: string;
  max: number;
  windowSeconds: number;
}

export const LIMITS = {
  bootstrap: { name: 'bootstrap', max: 20, windowSeconds: 60 },
  claimAdmin: { name: 'claim-admin', max: 5, windowSeconds: 600 },
  admin: { name: 'admin', max: 60, windowSeconds: 60 },
  telemetry: { name: 'telemetry', max: 10, windowSeconds: 60 },
  csp: { name: 'csp', max: 60, windowSeconds: 60 },
} satisfies Record<string, Limit>;

/** Throws 429 once [request]'s IP is over [limit]. */
export async function enforceLimit(
  request: Request,
  limit: Limit,
  limiter: RateLimiter = liveRateLimiter,
): Promise<void> {
  const ok = await limiter(`${limit.name}:${clientIp(request)}`, limit.max, limit.windowSeconds);
  if (!ok) {
    throw new HttpError(429, 'rate_limited', 'Too many requests. Wait a minute and try again.');
  }
}

/**
 * Fails open: if the counter cannot be reached the request goes ahead
 * (the endpoints still check tokens), so an outage never locks users out.
 */
export const liveRateLimiter: RateLimiter = async (bucket, max, windowSeconds) => {
  try {
    const { data, error } = await supabaseAdmin().rpc('rate_limit_hit', {
      bucket: bucket.slice(0, 200),
      max_hits: max,
      window_seconds: windowSeconds,
    });
    if (error) throw new Error(error.message);
    return data !== false;
  } catch (e) {
    console.error('rate limit check failed (allowing):', e instanceof Error ? e.message : e);
    return true;
  }
};
