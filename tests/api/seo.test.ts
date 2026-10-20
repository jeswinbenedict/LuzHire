import { describe, expect, it } from 'vitest';
import {
  FALLBACK_INDEX,
  injectMeta,
  jobMeta,
  jobPosting,
  jsonForScript,
  sitemapXml,
  type SeoJob,
} from '../../api/_lib/seo.js';

const origin = 'https://luzhire.vercel.app';

const INDEX =
  '<!DOCTYPE html><html><head><base href="/">' +
  '<meta name="description" content="Default description">' +
  '<title>LuzHire</title></head><body><script src="flutter_bootstrap.js" async></script></body></html>';

function job(over: Partial<SeoJob> = {}): SeoJob {
  return {
    slug: 'flutter-developer-1a2b3c4d',
    title: 'Flutter Developer',
    companyName: 'Nimbus Labs',
    source: 'native',
    externalSource: null,
    status: 'published',
    summary: 'Build the LuzHire mobile app with a small, friendly team.',
    descriptionMd: '## The team\nWe build tools.\n\n- Ship features',
    employmentType: 'full_time',
    workplace: 'hybrid',
    location: 'Bengaluru, IN',
    salaryMin: 1200000,
    salaryMax: 1800000,
    salaryCurrency: 'INR',
    salaryPeriod: 'year',
    publishedAt: '2026-10-19T09:00:00Z',
    deadline: '2026-11-30',
    company: { name: 'Nimbus Labs', website: 'https://nimbus.example', logoUrl: null },
    ...over,
  };
}

describe('job pages', () => {
  it('a live native job gets meta, canonical and JobPosting markup', () => {
    const { status, meta } = jobMeta(job(), 'flutter-developer-1a2b3c4d', origin);
    expect(status).toBe(200);
    expect(meta.index).toBe(true);
    const html = injectMeta(INDEX, meta);
    expect(html).toContain('<title>Flutter Developer at Nimbus Labs · LuzHire</title>');
    expect(html).toContain('<link rel="canonical" href="https://luzhire.vercel.app/jobs/flutter-developer-1a2b3c4d">');
    expect(html).not.toContain('Default description');
    expect(html.match(/<title>/g)).toHaveLength(1);
    expect(html).toContain('application/ld+json');
    expect(html).not.toContain('noindex');
    expect(html).toContain('<noscript><h1>Flutter Developer</h1>');
    expect(html).toContain('flutter_bootstrap.js'); // the app still boots
  });

  it('JobPosting carries salary, location, type and validity', () => {
    const p = jobPosting(job(), origin)!;
    expect(p).toMatchObject({
      '@type': 'JobPosting',
      title: 'Flutter Developer',
      datePosted: '2026-10-19',
      validThrough: '2026-11-30T23:59:59+05:30',
      employmentType: 'FULL_TIME',
      hiringOrganization: { name: 'Nimbus Labs', sameAs: 'https://nimbus.example' },
      jobLocation: { address: { addressLocality: 'Bengaluru', addressCountry: 'IN' } },
      baseSalary: { currency: 'INR', value: { minValue: 1200000, maxValue: 1800000, unitText: 'YEAR' } },
    });
    expect(jobPosting(job({ workplace: 'remote' }), origin)).toMatchObject({
      jobLocationType: 'TELECOMMUTE',
    });
  });

  it('external listings are noindex and never get JobPosting (providers\' terms)', () => {
    const { status, meta } = jobMeta(
      job({ source: 'external', externalSource: 'remotive' }),
      'x',
      origin,
    );
    expect(status).toBe(200);
    expect(meta.index).toBe(false);
    expect(meta.jsonLd).toBeNull();
    expect(injectMeta(INDEX, meta)).toContain('<meta name="robots" content="noindex">');
  });

  it('closed jobs answer 410 and unknown ones 404, both noindex', () => {
    const closed = jobMeta(job({ status: 'closed' }), 'flutter-developer-1a2b3c4d', origin);
    expect(closed.status).toBe(410);
    expect(closed.meta.index).toBe(false);
    expect(closed.meta.jsonLd).toBeNull();
    const missing = jobMeta(null, 'nope', origin);
    expect(missing.status).toBe(404);
    expect(injectMeta(FALLBACK_INDEX, missing.meta)).toContain('Job not found');
  });

  it('escapes untrusted text everywhere', () => {
    const evil = job({ title: '</script><script>alert(1)</script>', companyName: '"><img src=x onerror=alert(1)>' });
    const html = injectMeta(INDEX, jobMeta(evil, 'x', origin).meta);
    expect(html).not.toContain('<script>alert(1)</script>');
    expect(html).not.toContain('<img src=x');
    expect(jsonForScript({ t: '</script>' })).toBe('{"t":"\\u003c/script\\u003e"}');
  });
});

describe('sitemap', () => {
  it('lists URLs with lastmod dates', () => {
    const xml = sitemapXml(origin, [
      { path: '/' },
      { path: '/jobs/a-1', lastmod: '2026-10-19T09:00:00Z' },
    ]);
    expect(xml).toContain('<loc>https://luzhire.vercel.app/</loc>');
    expect(xml).toContain('<url><loc>https://luzhire.vercel.app/jobs/a-1</loc><lastmod>2026-10-19</lastmod></url>');
    expect(xml.startsWith('<?xml')).toBe(true);
  });
});
