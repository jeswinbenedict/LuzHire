// Career news from RSS/Atom feeds whose terms allow showing linked
// headlines. Only the title, a short excerpt, the feed's own image and a link
// back are kept; the article itself stays on the publisher's site.
import { clamp, decodeEntities, htmlToMarkdown, plainText } from '../ingest/normalize.js';

export interface NewsFeed {
  id: string;
  label: string;
  url: string;
  /** Starting relevance: feeds about careers start higher than general ones. */
  base: number;
}

export const FEEDS: NewsFeed[] = [
  // Remote work and careers, from the job board LuzHire already imports.
  { id: 'remotive', label: 'Remotive', url: 'https://remotive.com/blog/feed', base: 0.5 },
  // Community posts tagged #career: anyone can tag, so a post still needs a
  // career keyword.
  { id: 'devto', label: 'DEV Community', url: 'https://dev.to/feed/tag/career', base: 0.35 },
  // Mostly tutorials: only career and learning-path posts get through.
  { id: 'freecodecamp', label: 'freeCodeCamp', url: 'https://www.freecodecamp.org/news/rss/', base: 0.1 },
];

/** Items scoring below this are off-topic and never stored. */
export const MIN_RELEVANCE = 0.5;
/** Older items are not imported (and are pruned after 60 days). */
export const MAX_AGE_DAYS = 45;
export const MAX_PER_FEED = 20;

export interface FeedItem {
  title: string;
  link: string;
  description: string;
  publishedAt: string | null;
  imageUrl: string | null;
  categories: string[];
}

export interface NewsItem {
  source: string;
  url: string;
  title: string;
  summary: string | null;
  imageUrl: string | null;
  publishedAt: string;
  categories: string[];
  relevance: number;
}

// ---------------------------------------------------------------- parsing

const cdata = (s: string) => s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1');

function tag(block: string, name: string): string | null {
  const m = block.match(new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, 'i'));
  return m ? cdata(m[1]!).trim() : null;
}

function attr(block: string, name: string, attribute: string): string | null {
  const m = block.match(new RegExp(`<${name}\\s[^>]*${attribute}="([^"]+)"`, 'i'));
  return m ? decodeEntities(m[1]!) : null;
}

const httpsUrl = (s: string | null): string | null => {
  if (!s) return null;
  try {
    const u = new URL(s.trim());
    return u.protocol === 'https:' ? u.toString() : null;
  } catch {
    return null;
  }
};

/** RSS 2.0 `<item>`s or Atom `<entry>`s, with untrusted text left raw. */
export function parseFeed(xml: string): FeedItem[] {
  const blocks = xml.match(/<item[\s>][\s\S]*?<\/item>/gi) ?? xml.match(/<entry[\s>][\s\S]*?<\/entry>/gi) ?? [];
  const items: FeedItem[] = [];
  for (const b of blocks) {
    const title = tag(b, 'title');
    const link = httpsUrl(tag(b, 'link') || attr(b, 'link', 'href'));
    if (!title || !link) continue;
    const description = tag(b, 'description') ?? tag(b, 'summary') ?? tag(b, 'content') ?? '';
    const date = tag(b, 'pubDate') ?? tag(b, 'published') ?? tag(b, 'updated') ?? tag(b, 'dc:date');
    const parsed = date ? Date.parse(date) : NaN;
    const content = tag(b, 'content:encoded') ?? '';
    const image = httpsUrl(
      attr(b, 'media:content', 'url') ??
        attr(b, 'media:thumbnail', 'url') ??
        (/<enclosure\s[^>]*type="image\//i.test(b) ? attr(b, 'enclosure', 'url') : null) ??
        (content.match(/<img\s[^>]*src="([^"]+)"/i)?.[1] ?? null),
    );
    const categories = [...b.matchAll(/<category(?:\s[^>]*)?>([\s\S]*?)<\/category>/gi)]
      .map((m) => plainText(cdata(m[1]!), 60).toLowerCase())
      .filter(Boolean);
    items.push({
      title,
      link,
      description,
      publishedAt: Number.isFinite(parsed) ? new Date(parsed).toISOString() : null,
      imageUrl: image,
      categories,
    });
  }
  return items;
}

// ---------------------------------------------------------------- relevance

const CAREER_WORDS = [
  'career', 'job', 'jobs', 'hiring', 'hire', 'interview', 'resume', 'résumé', 'cv', 'cover letter',
  'salary', 'salaries', 'internship', 'intern', 'fresher', 'graduate', 'campus', 'placement',
  'recruit*', 'layoff*', 'remote work', 'work from home', 'remote job',
  'promotion', 'negotiat*', 'freelanc*', 'portfolio', 'linkedin', 'onboarding', 'workplace',
  'upskill', 'reskill', 'certification', 'bootcamp', 'learn to code', 'roadmap', 'job market',
  'job search', 'employer', 'employee', 'manager', 'mentor', 'soft skills', 'networking',
];

const TOPICS: { slug: string; words: string[] }[] = [
  { slug: 'interviews', words: ['interview', 'resume', 'résumé', 'cv', 'cover letter', 'portfolio', 'linkedin'] },
  { slug: 'remote-work', words: ['remote', 'work from home', 'async', 'digital nomad', 'hybrid', 'rto', 'office'] },
  { slug: 'skills', words: ['learn', 'course', 'certification', 'upskill', 'reskill', 'bootcamp', 'roadmap', 'skills'] },
  { slug: 'hiring-trends', words: ['hiring', 'layoff', 'job market', 'trend', 'salary', 'salaries', 'report', 'ai'] },
];

/** Whole-word match; a trailing `*` matches any ending ("recruit*"). */
const has = (text: string, word: string) => {
  const stem = word.endsWith('*');
  const w = (stem ? word.slice(0, -1) : word).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`(^|[^a-z])${w}${stem ? '' : '(?![a-z])'}`, 'i').test(text);
};

/**
 * 0–1: how much an item is about careers and work. Only the title and text
 * count: a feed's own tags (DEV's "career") would match every post.
 */
export function relevanceOf(item: FeedItem, feed: NewsFeed): number {
  const text = `${plainText(item.title, 300)} ${plainText(item.description, 2000)}`;
  const hits = CAREER_WORDS.filter((w) => has(text, w)).length;
  return Math.min(1, Math.round((feed.base + hits * 0.15) * 100) / 100);
}

const ENGLISH_WORDS = new Set([
  'the', 'and', 'to', 'of', 'a', 'in', 'for', 'is', 'you', 'your', 'how',
  'with', 'what', 'why', 'it', 'on', 'are', 'this', 'that', 'be', 'or',
]);

/**
 * LuzHire is in English: Latin letters, and common English words in the
 * title and opening text (Indonesian or Spanish also use Latin letters).
 */
export function isEnglish(title: string, text = ''): boolean {
  const letters = [...title].filter((c) => /\p{L}/u.test(c));
  if (letters.length === 0) return false;
  const latin = letters.filter((c) => /[a-z]/i.test(c)).length;
  if (latin / letters.length < 0.9) return false;
  const words = `${title} ${text.slice(0, 300)}`.toLowerCase().match(/[a-z']+/g) ?? [];
  return words.filter((w) => ENGLISH_WORDS.has(w)).length >= 2;
}

/** LuzHire's news categories for an item (always at least one). */
export function topicsOf(item: FeedItem): string[] {
  const text = `${plainText(item.title, 300)} ${plainText(item.description, 2000)} ${item.categories.join(' ')}`;
  const found = TOPICS.filter((t) => t.words.some((w) => has(text, w))).map((t) => t.slug);
  return found.length > 0 ? found.slice(0, 2) : ['career-tips'];
}

/** Feed items → news rows worth showing, newest first, capped per feed. */
export function toNews(items: FeedItem[], feed: NewsFeed, now: Date): NewsItem[] {
  const oldest = now.getTime() - MAX_AGE_DAYS * 86_400_000;
  const out: NewsItem[] = [];
  for (const item of items) {
    const published = item.publishedAt ? Date.parse(item.publishedAt) : now.getTime();
    if (published < oldest || published > now.getTime() + 86_400_000) continue;
    const relevance = relevanceOf(item, feed);
    if (relevance < MIN_RELEVANCE) continue;
    if (!isEnglish(plainText(item.title, 300), plainText(item.description, 600))) continue;
    const excerpt = plainText(htmlToMarkdown(item.description, 4000).replace(/\*\*|^#+ |^- /gm, ''), 280);
    out.push({
      source: feed.id,
      url: item.link,
      title: plainText(item.title, 200),
      summary: excerpt.length >= 20 ? excerpt : null,
      imageUrl: item.imageUrl,
      publishedAt: new Date(published).toISOString(),
      categories: topicsOf(item),
      relevance,
    });
  }
  return out
    .sort((a, b) => b.publishedAt.localeCompare(a.publishedAt))
    .slice(0, MAX_PER_FEED)
    .map((n) => ({ ...n, title: clamp(n.title, 200) }));
}

// ---------------------------------------------------------------- run

export interface NewsRunLog {
  source: string;
  fetched: number;
  inserted: number;
  updated: number;
  skipped: number;
  closed: number;
  error: string | null;
}

export interface NewsDeps {
  getText(url: string): Promise<string>;
  now(): Date;
  /** Inserts new items by URL and leaves existing ones (and admin curation) alone; returns how many were new. */
  insert(items: NewsItem[]): Promise<number>;
  /** Deletes headlines older than [days] that are not featured; returns how many. */
  prune(days: number): Promise<number>;
  log(run: NewsRunLog): Promise<void>;
}

export async function runNewsIngest(deps: NewsDeps, feeds: NewsFeed[] = FEEDS): Promise<NewsRunLog[]> {
  const logs: NewsRunLog[] = [];
  const now = deps.now();
  for (const feed of feeds) {
    const log: NewsRunLog = { source: `news:${feed.id}`, fetched: 0, inserted: 0, updated: 0, skipped: 0, closed: 0, error: null };
    try {
      const items = parseFeed(await deps.getText(feed.url));
      log.fetched = items.length;
      const keep = toNews(items, feed, now);
      log.skipped = items.length - keep.length;
      log.inserted = keep.length > 0 ? await deps.insert(keep) : 0;
    } catch (e) {
      log.error = clamp(e instanceof Error ? e.message : String(e), 300);
    }
    logs.push(log);
    await deps.log(log);
  }
  await deps.prune(60);
  return logs;
}
