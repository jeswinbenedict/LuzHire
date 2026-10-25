// Logos for imported companies whose feed sends none (Remote OK, some
// Himalayas companies). The logo is the company website's icon, so the job is
// to find the website, in this order:
//   1. a logo already stored for the same company (from any feed);
//   2. a link to the company's own site in the job description;
//   3. a name lookup, accepted only for one exact name match.
// Every icon is checked to exist before it is used. Companies with no
// findable website keep no logo and the app shows their initials.
import { dedupeKey, type IngestJob } from './normalize.js';

export interface LogoDeps {
  /** Company name → candidate {name, domain} pairs (Clearbit autocomplete). */
  suggest(name: string): Promise<{ name: string; domain: string }[]>;
  /** Whether [url] answers 200 with an image. */
  imageOk(url: string): Promise<boolean>;
}

/** Same key the ingest run uses to spot one company across feeds. */
export const companyKey = (name: string) => dedupeKey('', name).slice(1);

/** The site icon (up to 128 px) for a domain, via Google's favicon service. */
export function faviconOf(domain: string): string {
  return (
    'https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON' +
    `&fallback_opts=TYPE,SIZE,URL&url=https://${domain}&size=128`
  );
}

const SUFFIXES = /\b(inc|llc|ltd|limited|pvt|private|corp|corporation|co|company|gmbh|plc|group|holdings)\b/g;

/** Lower-case letters and digits of the name without legal suffixes. */
function compact(name: string): string {
  return name
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(SUFFIXES, ' ')
    .replace(/\s+/g, '');
}

/** The first word of the name worth matching (4+ letters), or the whole. */
function mainWord(name: string): string {
  const words = name
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(SUFFIXES, ' ')
    .split(/\s+/)
    .filter(Boolean);
  return words.find((w) => w.length >= 4) ?? words.join('');
}

/** "jobs.acme.co.uk" → "acme" (the label a company's name shows up in). */
function siteLabel(host: string): string {
  const parts = host.toLowerCase().replace(/^www\./, '').split('.');
  const short = parts.length >= 3 && parts[parts.length - 2]!.length <= 3;
  return parts[parts.length - (short ? 3 : 2)] ?? '';
}

/** A host is the company's own when its site label carries the name. */
function hostMatches(host: string, company: string): boolean {
  const label = siteLabel(host).replace(/-/g, '');
  const whole = compact(company);
  const word = mainWord(company);
  return label.length >= 3 && (label === whole || label.includes(whole) || (word.length >= 4 && label.includes(word)));
}

/** Job boards, applicant trackers and the like: never a company's site. */
const NOT_COMPANY =
  /(^|\.)(remoteok|himalayas|jobicy|remotive|adzuna|linkedin|indeed|glassdoor|greenhouse|lever|ashbyhq|workable|smartrecruiters|bamboohr|breezy|recruitee|teamtailor|personio|workday|myworkdayjobs|icims|jobvite|google|youtube|twitter|x|facebook|instagram|medium|github|bit|notion)\.[a-z.]+$/i;

/** The company's own domain if the description links to it. */
export function domainFromText(company: string, text: string): string | null {
  for (const m of text.matchAll(/https?:\/\/([a-z0-9.-]+\.[a-z]{2,})/gi)) {
    const host = m[1]!.toLowerCase().replace(/^www\./, '');
    if (!NOT_COMPANY.test(host) && hostMatches(host, company)) {
      const label = siteLabel(host);
      return host.slice(host.indexOf(label));
    }
  }
  return null;
}

/**
 * The domain for a name lookup's results, or null when it is not clear-cut
 * (a wrong company's logo is worse than initials): a .com named exactly
 * like the company ("supportyourapp.com" for SupportYourApp), or else the
 * one exact name match. Several same-named companies on different sites
 * ("Voltus": voltus.de, voltus.co) give no logo.
 */
export function domainFromSuggestions(company: string, results: { name: string; domain: string }[]): string | null {
  const exact = results.filter((r) => compact(r.name) === compact(company) && hostMatches(r.domain, company));
  const named = exact.filter((r) => siteLabel(r.domain).replace(/-/g, '') === compact(company));
  const dotCom = named.find((r) => r.domain.toLowerCase().endsWith('.com'));
  if (dotCom) return dotCom.domain.toLowerCase();
  return exact.length === 1 ? exact[0]!.domain.toLowerCase() : null;
}

/**
 * Most companies looked up in one run (each is a lookup plus an icon check,
 * well under a second). High enough that companies with no findable site,
 * which are tried again every run, never crowd out new ones.
 */
export const MAX_LOOKUPS = 150;
/** Time for lookups, so the import stays inside the 60 s function limit. */
export const LOOKUP_BUDGET_MS = 15_000;

/**
 * Gives jobs without a logo their company's logo. [known] maps company keys
 * to logos already stored and learns every logo found, so a company is only
 * looked up once and keeps its logo on later runs.
 */
export async function fillLogos(
  jobs: IngestJob[],
  known: Map<string, string>,
  deps: LogoDeps | undefined,
  budgetMs = LOOKUP_BUDGET_MS,
): Promise<void> {
  const missing = new Map<string, IngestJob[]>();
  for (const job of jobs) {
    const key = companyKey(job.companyName);
    if (job.logoUrl) {
      if (!known.has(key)) known.set(key, job.logoUrl);
      continue;
    }
    const stored = known.get(key);
    if (stored) job.logoUrl = stored;
    else missing.set(key, [...(missing.get(key) ?? []), job]);
  }
  if (!deps || missing.size === 0) return;

  // A fresh order every run: if the lookup service turns some requests
  // away, different companies get the early turns next time, and each run
  // keeps what it found (stored logos are reused), so the rest shrinks.
  const queue = shuffled([...missing.values()]).slice(0, MAX_LOOKUPS);
  const stopAt = Date.now() + budgetMs;
  const worker = async () => {
    for (let group = queue.shift(); group && Date.now() < stopAt; group = queue.shift()) {
      const company = group[0]!.companyName;
      try {
        let domain = null as string | null;
        for (const j of group) domain ??= domainFromText(company, j.descriptionMd);
        domain ??= domainFromSuggestions(company, await deps.suggest(company));
        if (!domain) continue;
        const logo = faviconOf(domain);
        if (!(await deps.imageOk(logo))) continue;
        known.set(companyKey(company), logo);
        for (const j of group) j.logoUrl = logo;
      } catch {
        // No logo this time; the app shows the company's initials.
      }
    }
  };
  // Few at a time: the four feeds import side by side, and the lookup
  // service turns bursts away.
  await Promise.all(Array.from({ length: LOOKUP_CONCURRENCY }, worker));
}

/** Lookups in flight per feed (four feeds run at once). */
export const LOOKUP_CONCURRENCY = 2;

function shuffled<T>(items: T[]): T[] {
  for (let i = items.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [items[i], items[j]] = [items[j]!, items[i]!];
  }
  return items;
}
