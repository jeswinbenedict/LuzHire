import { describe, expect, it } from 'vitest';
import { handle, json } from '../../api/_lib/http.js';
import { LIMITS, clientIp, enforceLimit, type RateLimiter } from '../../api/_lib/rate-limit.js';

function counter(): { limiter: RateLimiter; buckets: string[] } {
  const hits = new Map<string, number>();
  const buckets: string[] = [];
  return {
    buckets,
    limiter: async (bucket, max) => {
      buckets.push(bucket);
      const n = (hits.get(bucket) ?? 0) + 1;
      hits.set(bucket, n);
      return n <= max;
    },
  };
}

const req = (headers: Record<string, string> = {}) =>
  new Request('https://luzhire.vercel.app/api/auth/claim-admin', { method: 'POST', headers });

describe('rate limits', () => {
  it('reads the caller IP the way Vercel forwards it', () => {
    expect(clientIp(req({ 'x-real-ip': '203.0.113.7' }))).toBe('203.0.113.7');
    expect(clientIp(req({ 'x-forwarded-for': '198.51.100.2, 10.0.0.1' }))).toBe('198.51.100.2');
    expect(clientIp(req())).toBe('unknown');
  });

  it('counts per endpoint and per IP, then answers 429 with Retry-After', async () => {
    const c = counter();
    const endpoint = handle(async (request) => {
      await enforceLimit(request, LIMITS.claimAdmin, c.limiter);
      return json(request, 200, { ok: true });
    });
    const statuses: number[] = [];
    for (let i = 0; i < 6; i++) statuses.push((await endpoint(req({ 'x-real-ip': '203.0.113.7' }))).status);
    expect(statuses).toEqual([200, 200, 200, 200, 200, 429]);

    const blocked = await endpoint(req({ 'x-real-ip': '203.0.113.7' }));
    expect(blocked.headers.get('Retry-After')).toBe('60');
    expect(await blocked.json()).toEqual({
      error: { code: 'rate_limited', message: 'Too many requests. Wait a minute and try again.' },
    });
    expect((await endpoint(req({ 'x-real-ip': '198.51.100.2' }))).status).toBe(200);
    expect(c.buckets[0]).toBe('claim-admin:203.0.113.7');
  });
});
