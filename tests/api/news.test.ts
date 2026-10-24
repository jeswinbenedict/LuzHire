import { describe, expect, it } from 'vitest';
import {
  FEEDS,
  apiImages,
  isEnglish,
  pageImageOf,
  pageImages,
  parseFeed,
  relevanceOf,
  runNewsIngest,
  toNews,
  topicsOf,
  type FeedItem,
  type NewsDeps,
  type NewsItem,
  type NewsRunLog,
} from '../../api/_lib/news/feeds.js';

const NOW = new Date('2026-10-21T06:00:00Z');
const devto = FEEDS.find((f) => f.id === 'devto')!;
const fcc = FEEDS.find((f) => f.id === 'freecodecamp')!;

const RSS = `<?xml version="1.0"?><rss><channel><title>Feed</title>
<item>
  <title><![CDATA[ How to Negotiate Your First Salary ]]></title>
  <link>https://www.freecodecamp.org/news/negotiate-salary/</link>
  <description><![CDATA[ <p>Most <strong>freshers</strong> accept the first offer. Here is how to prepare for the interview &amp; the salary talk.</p><script>x()</script> ]]></description>
  <category><![CDATA[ Career ]]></category>
  <pubDate>Tue, 20 Oct 2026 16:36:05 +0000</pubDate>
  <media:content url="https://cdn.hashnode.com/uploads/covers/a.png" medium="image" />
</item>
<item>
  <title>How Neural Networks Work</title>
  <link>https://www.freecodecamp.org/news/neural-networks/</link>
  <description>A straight line equation is a good place to start.</description>
  <pubDate>Tue, 20 Oct 2026 12:00:00 +0000</pubDate>
</item>
<item>
  <title>Insecure link</title>
  <link>http://example.com/a</link>
</item>
</channel></rss>`;

const ATOM = `<feed><entry><title>Remote work in 2026</title><link href="https://remotive.com/blog/remote-2026/"/>
<summary>Remote jobs and hiring trends this year.</summary><updated>2026-10-19T20:26:09Z</updated></entry></feed>`;

describe('parseFeed', () => {
  it('reads RSS items with CDATA, categories and the feed image', () => {
    const items = parseFeed(RSS);
    expect(items).toHaveLength(2); // the http:// link is dropped
    expect(items[0]).toMatchObject({
      title: 'How to Negotiate Your First Salary',
      link: 'https://www.freecodecamp.org/news/negotiate-salary/',
      publishedAt: '2026-10-20T16:36:05.000Z',
      imageUrl: 'https://cdn.hashnode.com/uploads/covers/a.png',
      categories: ['career'],
    });
  });

  it('reads Atom entries', () => {
    expect(parseFeed(ATOM)).toEqual([
      {
        title: 'Remote work in 2026',
        link: 'https://remotive.com/blog/remote-2026/',
        description: 'Remote jobs and hiring trends this year.',
        publishedAt: '2026-10-19T20:26:09.000Z',
        imageUrl: null,
        categories: [],
      },
    ]);
  });

  it('returns nothing for something that is not a feed', () => {
    expect(parseFeed('<html><body>Not a feed</body></html>')).toEqual([]);
  });
});

describe('relevance and topics', () => {
  const item = (title: string, description = '', categories: string[] = []): FeedItem => ({
    title,
    link: 'https://x.test/a',
    description,
    publishedAt: null,
    imageUrl: null,
    categories,
  });

  it('keeps career posts and drops off-topic tutorials', () => {
    expect(relevanceOf(item('How to Negotiate Your First Salary', 'interview tips for freshers'), fcc)).toBeGreaterThanOrEqual(0.5);
    expect(relevanceOf(item('How Neural Networks Work', 'A straight line equation.'), fcc)).toBeLessThan(0.5);
  });

  it('matches whole words, so "ai" is not found inside "aim"', () => {
    expect(topicsOf(item('We aim higher'))).toEqual(['career-tips']);
    expect(topicsOf(item('AI is changing hiring'))).toEqual(['hiring-trends']);
  });

  it('files posts under LuzHire topics', () => {
    expect(topicsOf(item('Ace the interview', 'Polish your resume'))).toEqual(['interviews']);
    expect(topicsOf(item('Remote work is here to stay'))).toEqual(['remote-work']);
  });
});

describe('isEnglish', () => {
  it('keeps English titles and drops other scripts', () => {
    expect(isEnglish('Should a Resume Be One Page or Two?')).toBe(true);
    expect(isEnglish('Anthropic ยกหุ้น 5% ให้สาธารณะ แล้ว AI กำลังลดการจ้าง')).toBe(false);
    expect(isEnglish('2026')).toBe(false);
    expect(isEnglish('Apakah AI Mampu Menggantikan Developer', 'Banyak orang bertanya apakah AI akan')).toBe(false);
  });
});

describe('toNews', () => {
  it('keeps relevant, recent items with a plain-text excerpt', () => {
    const news = toNews(parseFeed(RSS), fcc, NOW);
    expect(news).toHaveLength(1);
    expect(news[0]).toMatchObject({
      source: 'freecodecamp',
      title: 'How to Negotiate Your First Salary',
      summary: 'Most freshers accept the first offer. Here is how to prepare for the interview & the salary talk.',
      categories: ['interviews', 'hiring-trends'],
    });
    expect(news[0]!.summary).not.toContain('<');
  });

  it('skips items older than 45 days', () => {
    const old = RSS.replaceAll('Oct 2026', 'Jul 2026');
    expect(toNews(parseFeed(old), devto, NOW)).toEqual([]);
  });
});

describe('page images', () => {
  it('reads og:image in any attribute order, then twitter:image, https only', () => {
    expect(pageImageOf('<meta property="og:image" content="https://a.example/x.png?w=1&amp;h=2">')).toBe(
      'https://a.example/x.png?w=1&h=2',
    );
    expect(pageImageOf(`<meta content='https://b.example/y.jpg' name='twitter:image'>`)).toBe('https://b.example/y.jpg');
    expect(pageImageOf('<meta property="og:image:width" content="1200">')).toBeNull();
    expect(pageImageOf('<meta property="og:image" content="http://insecure.example/z.png">')).toBeNull();
    expect(pageImageOf('<html><head><title>No image</title></head></html>')).toBeNull();
  });

  it('reads cover images from the DEV articles API, falling back to the social image', () => {
    const found = apiImages(
      JSON.stringify([
        { url: 'https://dev.to/a/one', cover_image: 'https://media2.dev.to/c.png', social_image: 'https://media2.dev.to/s.png' },
        { url: 'https://dev.to/b/two', cover_image: null, social_image: 'https://media2.dev.to/s2.png' },
        { url: 'https://dev.to/c/three', cover_image: 'http://insecure.example/x.png' },
      ]),
    );
    expect([...found]).toEqual([
      ['https://dev.to/a/one', 'https://media2.dev.to/c.png'],
      ['https://dev.to/b/two', 'https://media2.dev.to/s2.png'],
    ]);
    expect(apiImages('not json').size).toBe(0);
  });

  it('stops reading pages when its time budget is used up', async () => {
    const asked: string[] = [];
    const links = Array.from({ length: 20 }, (_, i) => `https://dev.to/u/post-${i}`);
    await pageImages(
      links,
      async (url) => {
        asked.push(url);
        await new Promise((r) => setTimeout(r, 30));
        return '<meta property="og:image" content="https://cdn.example/i.png">';
      },
      50,
    );
    expect(asked.length).toBeLessThan(20);
  });

  it('only reads pages on the sites LuzHire imports from', async () => {
    const asked: string[] = [];
    const found = await pageImages(
      ['https://dev.to/x/post', 'https://www.freecodecamp.org/news/y/', 'https://169.254.169.254/latest', 'not a url'],
      async (url) => {
        asked.push(url);
        return '<meta property="og:image" content="https://cdn.example/i.png">';
      },
    );
    expect(asked.sort()).toEqual(['https://dev.to/x/post', 'https://www.freecodecamp.org/news/y/']);
    expect(found.size).toBe(2);
  });
});

describe('runNewsIngest', () => {
  function deps(feeds: Record<string, string | Error>, stored: string[] = []) {
    const inserted: NewsItem[] = [];
    const logs: NewsRunLog[] = [];
    const imaged = new Map<string, string>();
    let pruned = 0;
    const d: NewsDeps = {
      async getText(url) {
        const r = feeds[url];
        if (r instanceof Error || r === undefined) throw r ?? new Error('no feed');
        return r;
      },
      now: () => NOW,
      async insert(items) {
        inserted.push(...items);
        return items.length;
      },
      async prune() {
        pruned++;
        return 0;
      },
      async withoutImage() {
        return stored;
      },
      async setImages(images) {
        for (const [k, v] of images) imaged.set(k, v);
        return images.size;
      },
      async log(run) {
        logs.push(run);
      },
    };
    return { d, inserted, logs, imaged, pruned: () => pruned };
  }

  const page = (image: string) =>
    `<html><head><meta name="viewport" content="width=device-width"><meta content="${image}" property="og:image" /></head></html>`;
  const DEV_RSS = `<rss><channel><item><title>How to prepare for a job interview</title>
    <link>https://dev.to/asha/job-interview-tips-1a2b</link><pubDate>Tue, 20 Oct 2026 10:00:00 GMT</pubDate>
    <description>Practical interview and resume advice for your first developer job search.</description></item></channel></rss>`;

  it('saves headlines first, then gives them DEV API images, then page images', async () => {
    const post = 'https://dev.to/asha/job-interview-tips-1a2b';
    const older = 'https://dev.to/ravi/older-post-9z';
    const order: string[] = [];
    const { d, inserted, imaged } = deps(
      {
        [devto.url]: DEV_RSS,
        [devto.imageApi!]: JSON.stringify([
          { url: post, cover_image: null, social_image: 'https://media2.dev.to/social.png' },
          { url: 'https://dev.to/x/unrelated', cover_image: 'https://media2.dev.to/u.png' },
        ]),
        [older]: page('https://media2.dev.to/older.png'),
      },
      [post, older],
    );
    const insert = d.insert;
    d.insert = async (items) => {
      order.push('insert');
      return insert(items);
    };
    const setImages = d.setImages;
    d.setImages = async (m) => {
      order.push('images');
      return setImages(m);
    };
    await runNewsIngest(d, [devto]);
    expect(order).toEqual(['insert', 'images']);
    expect(inserted[0]!.imageUrl).toBeNull(); // saved before any image lookup
    expect([...imaged]).toEqual([
      [post, 'https://media2.dev.to/social.png'], // from the API, no page read
      [older, 'https://media2.dev.to/older.png'], // not in the API: its page
    ]);
  });

  it('fills in stored headlines that still have no image', async () => {
    const { d, imaged, logs } = deps(
      {
        'https://dev.to/a/old-post-1': page('https://media2.dev.to/a.png'),
        'https://dev.to/b/broken-2': new Error('dev.to answered 500'),
      },
      ['https://dev.to/a/old-post-1', 'https://dev.to/b/broken-2', 'https://evil.example/x'],
    );
    await runNewsIngest(d, []);
    expect([...imaged]).toEqual([['https://dev.to/a/old-post-1', 'https://media2.dev.to/a.png']]);
    expect(logs.at(-1)).toMatchObject({ source: 'news:images', fetched: 3, updated: 1, skipped: 2, error: null });
  });

  it('imports each feed, logs it, and a failing feed does not stop the rest', async () => {
    const { d, inserted, logs, pruned } = deps({
      [FEEDS[0]!.url]: new Error('remotive.com answered 503'),
      [devto.url]: RSS,
      [fcc.url]: RSS,
    });
    await runNewsIngest(d);
    expect(logs.map((l) => [l.source, l.fetched, l.inserted, l.error])).toEqual([
      ['news:remotive', 0, 0, 'remotive.com answered 503'],
      ['news:devto', 2, 1, null], // the tutorial has no career keyword
      ['news:freecodecamp', 2, 1, null],
    ]);
    expect(inserted.map((n) => n.source)).toEqual(['devto', 'freecodecamp']);
    expect(pruned()).toBe(1);
  });
});
