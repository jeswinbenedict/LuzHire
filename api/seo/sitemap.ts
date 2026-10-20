// GET /sitemap.xml (rewritten here): public pages, LuzHire's own published
// jobs and verified companies. External listings are left out (providers'
// terms) and are noindex on their pages.
import { supabaseAdmin } from '../_lib/services.js';
import { sitemapXml, type SitemapEntry } from '../_lib/seo.js';

export async function GET(request: Request): Promise<Response> {
  const origin = new URL(request.url).origin;
  const entries: SitemapEntry[] = [{ path: '/' }, { path: '/jobs' }, { path: '/companies' }];
  try {
    const db = supabaseAdmin();
    const [jobs, companies] = await Promise.all([
      db
        .from('jobs')
        .select('slug, updated_at')
        .eq('status', 'published')
        .eq('source', 'native')
        .order('published_at', { ascending: false })
        .limit(5000),
      db
        .from('companies')
        .select('slug, updated_at')
        .eq('verification', 'verified')
        .limit(5000),
    ]);
    for (const j of jobs.data ?? []) {
      entries.push({ path: `/jobs/${j.slug as string}`, lastmod: j.updated_at as string });
    }
    for (const c of companies.data ?? []) {
      entries.push({ path: `/companies/${c.slug as string}`, lastmod: c.updated_at as string });
    }
  } catch (e) {
    console.error('sitemap', e);
  }
  return new Response(sitemapXml(origin, entries), {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, max-age=0, s-maxage=3600',
    },
  });
}
