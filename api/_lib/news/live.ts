// Production wiring for the news import (service role; bypasses RLS).
import { supabaseAdmin } from '../services.js';
import type { NewsDeps, NewsItem } from './feeds.js';

export function liveNewsDeps(): NewsDeps {
  const db = supabaseAdmin();
  const fail = (what: string, error: { message: string } | null) => {
    if (error) throw new Error(`${what}: ${error.message}`);
  };
  return {
    async getText(url) {
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'LuzHire job portal (college project) - luzhire.vercel.app',
          // Feeds, image APIs and article pages (for their preview images).
          Accept: 'application/rss+xml, application/atom+xml, application/xml, text/xml, application/json, text/html;q=0.8',
        },
        signal: AbortSignal.timeout(10_000),
      });
      if (!res.ok) throw new Error(`${new URL(url).host} answered ${res.status}`);
      return res.text();
    },
    now: () => new Date(),
    async insert(items: NewsItem[]) {
      const rows = items.map((n) => ({
        kind: 'headline',
        source: n.source,
        url: n.url,
        title: n.title,
        summary: n.summary,
        image_url: n.imageUrl,
        published_at: n.publishedAt,
        categories: n.categories,
        relevance: n.relevance,
      }));
      // ignoreDuplicates: items already stored keep any admin curation
      // (featured, hidden).
      const { data, error } = await db
        .from('news_articles')
        .upsert(rows, { onConflict: 'url', ignoreDuplicates: true })
        .select('id');
      fail('news insert', error);
      return data?.length ?? 0;
    },
    async prune(days) {
      const before = new Date(Date.now() - days * 86_400_000).toISOString();
      const { data, error } = await db
        .from('news_articles')
        .delete()
        .eq('kind', 'headline')
        .eq('is_featured', false)
        .lt('published_at', before)
        .select('id');
      fail('news prune', error);
      return data?.length ?? 0;
    },
    async withoutImage(limit) {
      const { data, error } = await db
        .from('news_articles')
        .select('url')
        .eq('kind', 'headline')
        .is('image_url', null)
        .order('published_at', { ascending: false })
        .limit(limit);
      fail('news without image', error);
      return (data ?? []).map((r) => r.url as string).filter(Boolean);
    },
    async setImages(images) {
      let updated = 0;
      for (const [url, image] of images) {
        // Only rows still without an image: an admin's choice is kept.
        const { data, error } = await db
          .from('news_articles')
          .update({ image_url: image })
          .eq('url', url)
          .is('image_url', null)
          .select('id');
        fail('news image', error);
        updated += data?.length ?? 0;
      }
      return updated;
    },
    async log(run) {
      const { error } = await db.from('ingest_runs').insert({ ...run, finished_at: new Date().toISOString() });
      fail('log', error);
    },
  };
}
