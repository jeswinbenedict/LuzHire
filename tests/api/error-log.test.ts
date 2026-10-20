import { describe, expect, it } from 'vitest';
import { entryFromReport, logServerError, scrub, type ErrorEntry } from '../../api/_lib/error-log.js';
import { handle } from '../../api/_lib/http.js';

describe('error log', () => {
  it('keeps personal data and tokens out of the log', () => {
    expect(scrub('Failed for asha.rao@example.com with Bearer eyJhbGciOiJSUzI1NiIs.eyJzdWIiOiJ1c2VyLTEi.c2lnbmF0dXJlLXZhbHVl', 500)).toBe(
      'Failed for [email] with [token]',
    );
    expect(scrub('x'.repeat(600), 500)).toHaveLength(500);
    expect(scrub(42, 10)).toBeNull();
  });

  it('accepts app reports and drops query strings and bad input', () => {
    expect(
      entryFromReport(
        { source: 'web', message: 'TypeError: null', route: '/jobs?q=secret+search', release: 'd8a3e80' },
        'Mozilla/5.0',
      ),
    ).toEqual({
      source: 'web',
      message: 'TypeError: null',
      detail: null,
      route: '/jobs',
      release: 'd8a3e80',
      user_agent: 'Mozilla/5.0',
    });
    expect(entryFromReport({ source: 'api', message: 'forged' }, null)).toBeNull();
    expect(entryFromReport({ source: 'desktop', message: 'x' }, null)).toBeNull();
    expect(entryFromReport({ source: 'web', message: '   ' }, null)).toBeNull();
    expect(entryFromReport('nope', null)).toBeNull();
  });

  it('records unexpected API errors without failing the response', async () => {
    const logged: ErrorEntry[] = [];
    await logServerError(new Request('https://x/api/auth/bootstrap', { method: 'POST' }), new TypeError('boom'), async (e) => {
      logged.push(e);
    });
    expect(logged[0]).toMatchObject({ source: 'api', message: 'TypeError: boom', route: 'POST /api/auth/bootstrap' });

    await expect(
      logServerError(new Request('https://x/a'), new Error('x'), async () => {
        throw new Error('db down');
      }),
    ).resolves.toBeUndefined();

    const res = await handle(async () => {
      throw new Error('unexpected');
    })(new Request('https://x/api/y'));
    expect(res.status).toBe(500);
  });
});
