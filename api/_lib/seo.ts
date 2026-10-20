// Server-rendered SEO for job pages: the app's own index.html with the job's
// title, description, canonical URL, Open Graph tags and (for LuzHire's own
// jobs only) schema.org JobPosting markup. Pure functions, so they can be
// unit-tested without a server.

export interface SeoJob {
  slug: string;
  title: string;
  companyName: string;
  source: 'native' | 'external';
  externalSource: string | null;
  status: string;
  summary: string | null;
  descriptionMd: string;
  employmentType: string;
  workplace: string;
  location: string | null;
  salaryMin: number | null;
  salaryMax: number | null;
  salaryCurrency: string | null;
  salaryPeriod: string | null;
  publishedAt: string | null;
  deadline: string | null;
  company: { name: string; website: string | null; logoUrl: string | null } | null;
}

export function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** JSON safe to place inside <script> (no "</script>" breakout). */
export function jsonForScript(value: unknown): string {
  return JSON.stringify(value)
    .replace(/</g, '\\u003c')
    .replace(/>/g, '\\u003e')
    .replace(/&/g, '\\u0026')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

function plain(md: string): string {
  return md.replace(/^#+\s*/gm, '').replace(/^-\s+/gm, '• ').replace(/\*\*/g, '');
}

export function describe(job: SeoJob): string {
  const base = (job.summary ?? plain(job.descriptionMd)).replace(/\s+/g, ' ').trim();
  const where = job.location ? ` · ${job.location}` : '';
  const text = base || `${job.title} at ${job.companyName}${where}`;
  return text.length > 160 ? `${text.slice(0, 157).trimEnd()}…` : text;
}

const EMPLOYMENT: Record<string, string> = {
  full_time: 'FULL_TIME',
  part_time: 'PART_TIME',
  contract: 'CONTRACTOR',
  internship: 'INTERN',
  temporary: 'TEMPORARY',
};
const UNIT: Record<string, string> = { hour: 'HOUR', month: 'MONTH', year: 'YEAR' };

/** schema.org JobPosting (Google for Jobs). Only for LuzHire's own jobs. */
export function jobPosting(job: SeoJob, origin: string): Record<string, unknown> | null {
  if (job.source !== 'native' || job.status !== 'published' || !job.publishedAt) return null;
  const html = escapeHtml(plain(job.descriptionMd) || job.summary || job.title)
    .split(/\n{2,}/)
    .map((p) => `<p>${p.replace(/\n/g, '<br>')}</p>`)
    .join('');
  const posting: Record<string, unknown> = {
    '@context': 'https://schema.org/',
    '@type': 'JobPosting',
    title: job.title,
    description: html,
    datePosted: job.publishedAt.slice(0, 10),
    employmentType: EMPLOYMENT[job.employmentType] ?? 'OTHER',
    identifier: { '@type': 'PropertyValue', name: 'LuzHire', value: job.slug },
    url: `${origin}/jobs/${job.slug}`,
    directApply: true,
    hiringOrganization: {
      '@type': 'Organization',
      name: job.company?.name ?? job.companyName,
      ...(job.company?.website ? { sameAs: job.company.website } : {}),
      ...(job.company?.logoUrl ? { logo: job.company.logoUrl } : {}),
    },
  };
  if (job.deadline) posting.validThrough = `${job.deadline}T23:59:59+05:30`;
  if (job.workplace === 'remote') {
    posting.jobLocationType = 'TELECOMMUTE';
    posting.applicantLocationRequirements = { '@type': 'Country', name: 'India' };
  } else {
    posting.jobLocation = {
      '@type': 'Place',
      address: {
        '@type': 'PostalAddress',
        addressLocality: (job.location ?? '').split(',')[0]?.trim() || 'India',
        addressCountry: 'IN',
      },
    };
  }
  if (job.salaryCurrency && job.salaryPeriod && (job.salaryMin != null || job.salaryMax != null)) {
    posting.baseSalary = {
      '@type': 'MonetaryAmount',
      currency: job.salaryCurrency,
      value: {
        '@type': 'QuantitativeValue',
        ...(job.salaryMin != null ? { minValue: job.salaryMin } : {}),
        ...(job.salaryMax != null ? { maxValue: job.salaryMax } : {}),
        unitText: UNIT[job.salaryPeriod] ?? 'YEAR',
      },
    };
  }
  return posting;
}

export interface PageMeta {
  title: string;
  description: string;
  canonical: string;
  /** noindex: closed jobs and external listings (their providers' terms). */
  index: boolean;
  jsonLd: Record<string, unknown> | null;
  /** Plain content for crawlers/no-JS readers. */
  noscript: string;
}

/** Puts [meta] into the app's index.html (replacing its title/description). */
export function injectMeta(indexHtml: string, meta: PageMeta): string {
  const head = [
    `<title>${escapeHtml(meta.title)}</title>`,
    `<meta name="description" content="${escapeHtml(meta.description)}">`,
    `<link rel="canonical" href="${escapeHtml(meta.canonical)}">`,
    meta.index ? '' : '<meta name="robots" content="noindex">',
    `<meta property="og:type" content="website">`,
    `<meta property="og:site_name" content="LuzHire">`,
    `<meta property="og:title" content="${escapeHtml(meta.title)}">`,
    `<meta property="og:description" content="${escapeHtml(meta.description)}">`,
    `<meta property="og:url" content="${escapeHtml(meta.canonical)}">`,
    '<meta name="twitter:card" content="summary">',
    meta.jsonLd
      ? `<script type="application/ld+json">${jsonForScript(meta.jsonLd)}</script>`
      : '',
  ]
    .filter(Boolean)
    .join('\n  ');
  let html = indexHtml
    .replace(/<title>[\s\S]*?<\/title>/i, '')
    .replace(/<meta\s+name="description"[^>]*>/i, '');
  html = html.replace(/<\/head>/i, `  ${head}\n</head>`);
  return html.replace(/<body([^>]*)>/i, `<body$1>\n  <noscript>${meta.noscript}</noscript>`);
}

export function jobMeta(job: SeoJob | null, slug: string, origin: string): {
  status: number;
  meta: PageMeta;
} {
  const canonical = `${origin}/jobs/${encodeURIComponent(slug)}`;
  if (!job) {
    return {
      status: 404,
      meta: {
        title: 'Job not found · LuzHire',
        description: 'This job is not on LuzHire. Browse verified jobs instead.',
        canonical,
        index: false,
        jsonLd: null,
        noscript: '<h1>Job not found</h1><p><a href="/jobs">Browse jobs on LuzHire</a></p>',
      },
    };
  }
  const live = job.status === 'published';
  const title = `${job.title} at ${job.companyName} · LuzHire`;
  const description = describe(job);
  const source =
    job.source === 'external' && job.externalSource
      ? `<p>Listed on ${escapeHtml(job.externalSource)}.</p>`
      : '';
  return {
    status: live ? 200 : 410,
    meta: {
      title: live ? title : `${job.title} (closed) · LuzHire`,
      description: live ? description : 'This job is no longer accepting applications.',
      canonical,
      index: live && job.source === 'native',
      jsonLd: live ? jobPosting(job, origin) : null,
      noscript:
        `<h1>${escapeHtml(job.title)}</h1><p>${escapeHtml(job.companyName)}` +
        `${job.location ? ` · ${escapeHtml(job.location)}` : ''}</p>` +
        `<p>${escapeHtml(live ? description : 'This job is closed.')}</p>${source}` +
        '<p><a href="/jobs">Browse jobs on LuzHire</a></p>',
    },
  };
}

export interface SitemapEntry {
  path: string;
  lastmod?: string | null;
}

export function sitemapXml(origin: string, entries: SitemapEntry[]): string {
  const urls = entries
    .map(
      (e) =>
        `  <url><loc>${escapeHtml(origin + e.path)}</loc>` +
        `${e.lastmod ? `<lastmod>${escapeHtml(e.lastmod.slice(0, 10))}</lastmod>` : ''}</url>`,
    )
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`;
}

/** Fallback shell if index.html cannot be fetched (still boots the app). */
export const FALLBACK_INDEX =
  '<!DOCTYPE html><html lang="en"><head><base href="/"><meta charset="UTF-8">' +
  '<meta name="viewport" content="width=device-width, initial-scale=1">' +
  '<link rel="icon" type="image/svg+xml" href="favicon.svg"><title>LuzHire</title></head>' +
  '<body><script src="flutter_bootstrap.js" async></script></body></html>';
