import { describe, expect, it } from 'vitest';
import {
  companyKey,
  domainFromSuggestions,
  domainFromText,
  faviconOf,
  fillLogos,
  type LogoDeps,
} from '../../api/_lib/ingest/logos.js';
import type { IngestJob } from '../../api/_lib/ingest/normalize.js';

const job = (companyName: string, over: Partial<IngestJob> = {}): IngestJob => ({
  source: 'remoteok',
  externalId: companyName,
  externalUrl: 'https://remoteok.com/remote-jobs/1',
  title: 'Engineer',
  companyName,
  logoUrl: null,
  descriptionMd: '',
  summary: null,
  location: 'Remote',
  workplace: 'remote',
  employmentType: 'full_time',
  salaryMin: null,
  salaryMax: null,
  salaryCurrency: null,
  salaryPeriod: null,
  publishedAt: '2026-10-25T00:00:00.000Z',
  tags: [],
  ...over,
});

describe('finding a company website', () => {
  it('trusts a .com named like the company, or a single exact match', () => {
    expect(
      domainFromSuggestions('SupportYourApp', [
        { name: 'SupportYourApp', domain: 'supportyourapp.com' },
        { name: 'SupportYourApp', domain: 'editorsupportyourapp.com' },
        { name: 'SupportYourApp', domain: 'supportyour.app' },
      ]),
    ).toBe('supportyourapp.com');
    expect(domainFromSuggestions('Lemon.io', [{ name: 'Lemon.io', domain: 'lemon.io' }, { name: 'lemonions', domain: 'lemonions.com' }])).toBe(
      'lemon.io',
    );
    expect(domainFromSuggestions('Aprio', [{ name: 'Aprio,', domain: 'aprio.com' }, { name: 'Apriorit', domain: 'apriorit.com' }])).toBe(
      'aprio.com',
    );
  });

  it('gives up when it is not clear-cut', () => {
    // Two same-named companies on different sites: no logo beats a wrong one.
    expect(domainFromSuggestions('Voltus', [{ name: 'Voltus', domain: 'voltus.de' }, { name: 'Voltus', domain: 'voltus.co' }])).toBeNull();
    // A different company's name, or a site that doesn't carry the name.
    expect(domainFromSuggestions('XION', [{ name: '杭州雄迈信息技术有限公司', domain: 'xiongmaitech.com' }])).toBeNull();
    expect(domainFromSuggestions('Rain', [{ name: 'Rain', domain: 'example.com' }])).toBeNull();
    expect(domainFromSuggestions('GoSaaS, Inc.', [])).toBeNull();
  });

  it('reads the company site from links in the description, skipping job boards', () => {
    expect(domainFromText('Plaid', 'See https://remoteok.com/x and https://plaid.com/legal/#privacy')).toBe('plaid.com');
    expect(domainFromText('Penumbra', 'Apply at https://jobs.lever.co/penumbrainc/1 or https://www.penumbrainc.com/pdf/')).toBe(
      'penumbrainc.com',
    );
    expect(domainFromText('Acme', 'Visit https://linkedin.com/company/acme')).toBeNull();
  });
});

describe('fillLogos', () => {
  const deps = (sites: Record<string, string>, asked: string[] = []): LogoDeps => ({
    suggest: async (name) => {
      asked.push(name);
      return sites[name] ? [{ name, domain: sites[name]! }] : [];
    },
    imageOk: async (url) => !url.includes('broken.example'),
  });

  it('reuses stored logos, looks each new company up once, and remembers it', async () => {
    const known = new Map([[companyKey('Toptal'), 'https://logo/toptal.png']]);
    const asked: string[] = [];
    const jobs = [job('Toptal'), job('Plaid'), job('Plaid', { externalId: 'p2' }), job('Nobody Knows')];
    await fillLogos(jobs, known, deps({ Plaid: 'plaid.com' }, asked));
    expect(jobs.map((j) => j.logoUrl)).toEqual([
      'https://logo/toptal.png',
      faviconOf('plaid.com'),
      faviconOf('plaid.com'),
      null, // the app shows its initials
    ]);
    expect(asked.sort()).toEqual(['Nobody Knows', 'Plaid']);
    expect(known.get(companyKey('Plaid'))).toBe(faviconOf('plaid.com'));
  });

  it('keeps a feed logo, and skips a site whose icon does not load', async () => {
    const jobs = [job('Feedco', { logoUrl: 'https://cdn.example/feed.png' }), job('Broken', { descriptionMd: '' })];
    const known = new Map<string, string>();
    await fillLogos(jobs, known, deps({ Broken: 'broken.example' }));
    expect(jobs.map((j) => j.logoUrl)).toEqual(['https://cdn.example/feed.png', null]);
    expect(known.get(companyKey('Feedco'))).toBe('https://cdn.example/feed.png');
  });

  it('stops looking up when its time budget is used up', async () => {
    const asked: string[] = [];
    const slow: LogoDeps = {
      suggest: async (name) => {
        asked.push(name);
        await new Promise((r) => setTimeout(r, 30));
        return [];
      },
      imageOk: async () => true,
    };
    await fillLogos(Array.from({ length: 40 }, (_, i) => job(`Company ${i}`)), new Map(), slow, 40);
    expect(asked.length).toBeLessThan(40);
  });
});
