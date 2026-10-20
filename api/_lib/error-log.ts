// First-party error log (public.app_errors): app crashes reported by
// clients and unexpected API errors. Best effort: logging never fails the
// request that triggered it.
import { supabaseAdmin } from './services.js';

export type ErrorSource = 'web' | 'android' | 'ios' | 'api';
const SOURCES = new Set<ErrorSource>(['web', 'android', 'ios', 'api']);

export interface ErrorEntry {
  source: ErrorSource;
  message: string;
  detail: string | null;
  route: string | null;
  release: string | null;
  user_agent: string | null;
}

const EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const BEARER = /\b(Bearer\s+)?eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/g;

/** Trims, caps and strips emails and tokens (no personal data in logs). */
export function scrub(value: unknown, max: number): string | null {
  if (typeof value !== 'string') return null;
  const text = value.replace(BEARER, '[token]').replace(EMAIL, '[email]').trim();
  return text ? text.slice(0, max) : null;
}

/** Validates a client report; null when it is not worth storing. */
export function entryFromReport(body: unknown, userAgent: string | null): ErrorEntry | null {
  if (!body || typeof body !== 'object') return null;
  const b = body as Record<string, unknown>;
  const source = b.source as ErrorSource;
  const message = scrub(b.message, 500);
  if (!SOURCES.has(source) || source === 'api' || !message) return null;
  const route = scrub(b.route, 200);
  return {
    source,
    message,
    detail: scrub(b.detail, 4000),
    // Paths only: never query strings (they can hold search terms).
    route: route ? route.split('?')[0]! : null,
    release: scrub(b.release, 40),
    user_agent: scrub(userAgent, 300),
  };
}

export type ErrorSink = (entry: ErrorEntry) => Promise<void>;

export const liveErrorSink: ErrorSink = async (entry) => {
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) return;
  const db = supabaseAdmin();
  const { error } = await db.from('app_errors').insert(entry);
  if (error) throw new Error(error.message);
  // Roughly 1 call in 50 also clears entries older than 30 days.
  if (Math.random() < 0.02) await db.rpc('prune_app_errors');
};

/** Records an unexpected API error (called by handle()). */
export async function logServerError(
  request: Request,
  error: unknown,
  sink: ErrorSink = liveErrorSink,
): Promise<void> {
  try {
    const e = error instanceof Error ? error : new Error(String(error));
    await sink({
      source: 'api',
      message: scrub(`${e.name}: ${e.message}`, 500) ?? 'Error',
      detail: scrub(e.stack ?? null, 4000),
      route: `${request.method} ${new URL(request.url).pathname}`.slice(0, 200),
      release: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? null,
      user_agent: null,
    });
  } catch (sinkError) {
    console.error('error log failed:', sinkError instanceof Error ? sinkError.message : sinkError);
  }
}
