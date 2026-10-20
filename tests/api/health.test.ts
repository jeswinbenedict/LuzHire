import { describe, expect, it } from 'vitest';
import { GET, healthResponse } from '../../api/health.js';

describe('GET /api/health', () => {
  it('returns ok and is not cached', async () => {
    const res = await GET(new Request('https://x/api/health'));
    expect(res.status).toBe(200);
    expect(res.headers.get('Cache-Control')).toBe('no-store');
    const body = (await res.json()) as { status: string; service: string };
    expect(body.status).toBe('ok');
    expect(body.service).toBe('luzhire-api');
  });

  it('?deep=1 checks the database and is briefly cached at the edge', async () => {
    const ok = await healthResponse(new Request('https://x/api/health?deep=1'), async () => {});
    expect(ok.status).toBe(200);
    expect(ok.headers.get('Cache-Control')).toBe('public, max-age=0, s-maxage=30');
    expect(await ok.json()).toMatchObject({ status: 'ok', database: 'ok' });

    const down = await healthResponse(new Request('https://x/api/health?deep=1'), async () => {
      throw new Error('connection refused');
    });
    expect(down.status).toBe(503);
    expect(await down.json()).toMatchObject({ status: 'degraded', database: 'error' });
  });
});
