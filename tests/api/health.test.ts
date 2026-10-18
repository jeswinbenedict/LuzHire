import { describe, expect, it } from 'vitest';
import { GET } from '../../api/health.js';

describe('GET /api/health', () => {
  it('returns ok and is not cached', async () => {
    const res = GET();
    expect(res.status).toBe(200);
    expect(res.headers.get('Cache-Control')).toBe('no-store');
    const body = (await res.json()) as { status: string; service: string };
    expect(body.status).toBe('ok');
    expect(body.service).toBe('luzhire-api');
  });
});
