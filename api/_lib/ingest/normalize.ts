// Pure helpers that turn provider data into LuzHire's job shape.

export type EmploymentType = 'full_time' | 'part_time' | 'contract' | 'internship' | 'temporary';
export type Workplace = 'onsite' | 'remote' | 'hybrid';
export type SalaryPeriod = 'hour' | 'month' | 'year';

/** One job as every adapter hands it to the ingest run. */
export interface IngestJob {
  source: string; // provider id, e.g. "remotive"
  externalId: string;
  externalUrl: string;
  title: string;
  companyName: string;
  logoUrl: string | null;
  descriptionMd: string;
  summary: string | null;
  location: string | null;
  workplace: Workplace;
  employmentType: EmploymentType;
  salaryMin: number | null;
  salaryMax: number | null;
  salaryCurrency: string | null;
  salaryPeriod: SalaryPeriod | null;
  publishedAt: string; // ISO
  tags: string[];
}

const ENTITIES: Record<string, string> = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', ndash: '–', mdash: '—',
  rsquo: '’', lsquo: '‘', rdquo: '”', ldquo: '“', hellip: '…', bull: '•', euro: '€', pound: '£', rupee: '₹',
};

export function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, code: string) => {
    if (code[0] === '#') {
      const n = code[1]?.toLowerCase() === 'x' ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10);
      return Number.isFinite(n) && n > 0 && n < 0x110000 ? String.fromCodePoint(n) : m;
    }
    return ENTITIES[code.toLowerCase()] ?? m;
  });
}

/**
 * Untrusted provider HTML → the small Markdown subset the app renders
 * (headings, bullets, paragraphs, **bold**). Scripts, styles, links and any
 * other markup are dropped, so nothing executable survives.
 */
export function htmlToMarkdown(html: string, maxLength = 30000): string {
  let s = html;
  // Some feeds double-encode their HTML.
  if (/&lt;[a-z/]/i.test(s) && !/<[a-z/]/i.test(s)) s = decodeEntities(s);
  s = s
    .replace(/<(script|style|iframe|object|embed|noscript|svg)[\s\S]*?<\/\1>/gi, '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<\s*br\s*\/?>/gi, '\n')
    .replace(/<\s*h[1-6][^>]*>([\s\S]*?)<\s*\/h[1-6]\s*>/gi, (_m, t: string) => `\n\n## ${inline(t)}\n\n`)
    .replace(/<\s*li[^>]*>([\s\S]*?)<\s*\/li\s*>/gi, (_m, t: string) => `\n- ${inline(t)}\n`)
    .replace(/<\s*(strong|b)[^>]*>([\s\S]*?)<\s*\/\1\s*>/gi, (_m, _t, t: string) => `**${stripTags(t).trim()}**`)
    .replace(/<\s*\/?(p|div|ul|ol|section|article|table|tr)[^>]*>/gi, '\n\n')
    .replace(/<[^>]+>/g, '');
  s = decodeEntities(s)
    .replace(/\r/g, '')
    .replace(/[ \t ]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\*\*\s*\*\*/g, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  if (s.length > maxLength) s = `${s.slice(0, maxLength - 1).trimEnd()}…`;
  return s;
}

function stripTags(s: string): string {
  return s.replace(/<[^>]+>/g, '');
}

/** Untrusted HTML/entities → plain one-line text (titles, names). */
export function plainText(s: string, max = 160): string {
  return clamp(fixMojibake(decodeEntities(stripTags(decodeEntities(s)))).replace(/\s+/g, ' '), max);
}

/**
 * Repairs UTF-8 text that a feed decoded as Latin-1 ("Sothebyâ\u0080\u0099s" →
 * "Sotheby’s"; Remote OK sends some names like this). Only text made of
 * Latin-1 characters with UTF-8 byte pairs in it is touched, and only when it
 * decodes cleanly, so real accents ("Café") are left alone.
 */
export function fixMojibake(s: string): string {
  if (!/[Â-ô][\u0080-¿]/.test(s) || /[^\u0000-ÿ]/.test(s)) return s;
  const bytes = Uint8Array.from(s, (c) => c.charCodeAt(0));
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch {
    return s;
  }
}

function inline(s: string): string {
  return decodeEntities(stripTags(s)).replace(/\s+/g, ' ').trim();
}

/** First sentence-ish of a description, for the card summary (≤ 400). */
export function summaryOf(markdown: string): string | null {
  const text = markdown
    .split('\n')
    .map((l) => l.replace(/^(#+|-)\s*/, '').replace(/\*\*/g, '').trim())
    .find((l) => l.length >= 40);
  if (!text) return null;
  return text.length > 400 ? `${text.slice(0, 399).trimEnd()}…` : text;
}

const CURRENCY: Record<string, string> = { $: 'USD', '€': 'EUR', '£': 'GBP', '₹': 'INR' };

/**
 * Free-text salary → range, currency and period. Returns null for anything
 * it cannot read with confidence (e.g. "per task", "competitive"), so a
 * wrong period is never shown.
 */
export function parseSalary(raw: string | null | undefined): {
  min: number;
  max: number;
  currency: string;
  period: SalaryPeriod;
} | null {
  if (!raw) return null;
  const s = raw.toLowerCase().replace(/,/g, '');
  if (/task|project|equity only|commission|competitive|doe|negotiable/.test(s)) return null;
  const symbol = raw.match(/[$€£₹]/)?.[0];
  const code = s.match(/\b(usd|eur|gbp|inr|cad|aud)\b/)?.[1]?.toUpperCase();
  const currency = code ?? (symbol ? CURRENCY[symbol] : undefined);
  if (!currency) return null;
  const parts = [...s.matchAll(/(\d+(?:\.\d+)?)\s*(k|lpa|lakh|l)?\b/g)]
    .map((m) => ({ n: Number(m[1]), unit: m[2] }))
    .filter((p) => p.n > 0)
    .slice(0, 2);
  if (parts.length === 0) return null;
  // "12-18 LPA" / "$80-100k": a unit written once covers both ends.
  const shared = parts.find((p) => p.unit)?.unit;
  const scale = (unit: string | undefined) =>
    unit === 'k' ? 1000 : unit === 'lpa' || unit === 'lakh' || unit === 'l' ? 100000 : 1;
  const nums = parts.map((p) => p.n * scale(p.unit ?? shared));
  const min = Math.min(...nums);
  const max = Math.max(...nums);
  let period: SalaryPeriod;
  if (/hour|\/hr|\bhr\b|hourly/.test(s)) period = 'hour';
  else if (/month|\/mo\b|monthly/.test(s)) period = 'month';
  else if (/year|annum|\/yr|annual|yearly|lpa/.test(s) || min >= 10000) period = 'year';
  else return null; // a small number with no period is too ambiguous
  return { min, max, currency, period };
}

export function employmentTypeOf(raw: string | null | undefined): EmploymentType {
  const s = (raw ?? '').toLowerCase().replace(/[-\s]/g, '_');
  if (s.includes('part')) return 'part_time';
  if (s.includes('contract') || s.includes('freelance')) return 'contract';
  if (s.includes('intern')) return 'internship';
  if (s.includes('temp')) return 'temporary';
  return 'full_time';
}

/** Key for spotting the same job posted by two providers. */
export function dedupeKey(title: string, company: string): string {
  const norm = (v: string) =>
    v
      .toLowerCase()
      .normalize('NFKD')
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\b(inc|ltd|llc|pvt|private|limited|gmbh|co)\b/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  return `${norm(title)}|${norm(company)}`;
}

export function clamp(text: string, max: number): string {
  const t = text.trim();
  return t.length > max ? `${t.slice(0, max - 1).trimEnd()}…` : t;
}
