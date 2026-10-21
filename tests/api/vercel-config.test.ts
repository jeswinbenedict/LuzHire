import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const config = JSON.parse(readFileSync(join(__dirname, '..', '..', 'vercel.json'), 'utf8')) as {
  rewrites: { source: string; destination: string }[];
};

describe('vercel.json rewrites', () => {
  // /jobs/:slug goes to the SEO function, which answers 404 for slugs that
  // are not jobs. App pages under /jobs/ must be routed to the app first.
  it('serves app pages under /jobs/ before the job SEO rule', () => {
    const sources = config.rewrites.map((r) => r.source);
    const seo = sources.indexOf('/jobs/:slug');
    expect(seo).toBeGreaterThan(-1);
    for (const page of ['/jobs/map']) {
      const i = sources.indexOf(page);
      expect(i, `${page} needs its own rewrite`).toBeGreaterThan(-1);
      expect(i).toBeLessThan(seo);
      expect(config.rewrites[i]!.destination).toBe('/index.html');
    }
  });
});
