// GET /jobs/:slug (rewritten to /api/seo/job?slug=…): the app's index.html
// with the job's title, description and JobPosting markup, and the right
// status code (404 unknown, 410 closed). The Flutter app then boots as usual.
import { supabaseAdmin } from '../_lib/services.js';
import { FALLBACK_INDEX, injectMeta, jobMeta, type SeoJob } from '../_lib/seo.js';

let cached: { html: string; at: number } | undefined;

async function indexHtml(origin: string): Promise<string> {
  if (cached && Date.now() - cached.at < 5 * 60_000) return cached.html;
  try {
    const res = await fetch(`${origin}/index.html`, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return FALLBACK_INDEX;
    const html = await res.text();
    if (!html.includes('flutter_bootstrap.js')) return FALLBACK_INDEX;
    cached = { html, at: Date.now() };
    return html;
  } catch {
    return FALLBACK_INDEX;
  }
}

// Only these states are public; drafts and pending jobs stay "not found".
const VISIBLE = new Set(['published', 'closed', 'archived', 'rejected']);

async function loadJob(slug: string): Promise<SeoJob | null> {
  if (!/^[a-z0-9-]{1,200}$/.test(slug)) return null;
  const { data, error } = await supabaseAdmin()
    .from('jobs')
    .select(
      'slug, title, company_name, source, external_source, status, summary, description_md, ' +
        'employment_type, workplace, location_text, salary_min, salary_max, salary_currency, ' +
        'salary_period, published_at, deadline, companies(name, website, logo_path)',
    )
    .eq('slug', slug)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) return null;
  const r = data as unknown as Record<string, unknown>;
  if (!VISIBLE.has(r.status as string)) return null;
  const c = r.companies as Record<string, unknown> | null;
  const supabaseUrl = process.env.SUPABASE_URL ?? '';
  return {
    slug: r.slug as string,
    title: r.title as string,
    companyName: r.company_name as string,
    source: r.source as 'native' | 'external',
    externalSource: (r.external_source as string | null) ?? null,
    status: r.status as string,
    summary: (r.summary as string | null) ?? null,
    descriptionMd: (r.description_md as string) ?? '',
    employmentType: r.employment_type as string,
    workplace: r.workplace as string,
    location: (r.location_text as string | null) ?? null,
    salaryMin: (r.salary_min as number | null) ?? null,
    salaryMax: (r.salary_max as number | null) ?? null,
    salaryCurrency: (r.salary_currency as string | null) ?? null,
    salaryPeriod: (r.salary_period as string | null) ?? null,
    publishedAt: (r.published_at as string | null) ?? null,
    deadline: (r.deadline as string | null) ?? null,
    company: c
      ? {
          name: c.name as string,
          website: (c.website as string | null) ?? null,
          logoUrl: c.logo_path
            ? `${supabaseUrl}/storage/v1/object/public/company-media/${c.logo_path as string}`
            : null,
        }
      : null,
  };
}

export async function GET(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const origin = url.origin;
  const slug = (url.searchParams.get('slug') ?? '').toLowerCase();
  let job: SeoJob | null = null;
  try {
    job = await loadJob(slug);
  } catch (e) {
    console.error('seo/job', e);
    // Never block the app: serve it without job metadata.
    return new Response(await indexHtml(origin), {
      status: 200,
      headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' },
    });
  }
  const { status, meta } = jobMeta(job, slug, origin);
  return new Response(injectMeta(await indexHtml(origin), meta), {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=0, s-maxage=300, stale-while-revalidate=600',
    },
  });
}
