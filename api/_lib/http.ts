// Shared HTTP helpers for Vercel Functions (Web Request/Response API).
import { logServerError } from './error-log.js';

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

/** Origins allowed to call the API cross-origin (local Flutter dev servers). */
function allowedOrigins(): string[] {
  return (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
}

export function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get('origin');
  if (!origin) return {};
  const allowed = allowedOrigins();
  const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  const ok = allowed.includes(origin) || (isLocalhost && process.env.VERCEL_ENV !== 'production');
  if (!ok) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '600',
    Vary: 'Origin',
  };
}

export function preflight(request: Request): Response {
  return new Response(null, { status: 204, headers: corsHeaders(request) });
}

export function json(request: Request, status: number, body: unknown): Response {
  return Response.json(body, {
    status,
    headers: { 'Cache-Control': 'no-store', ...corsHeaders(request) },
  });
}

/** Wraps a handler: maps HttpError to JSON, hides unexpected errors. */
export function handle(fn: (request: Request) => Promise<Response>) {
  return async (request: Request): Promise<Response> => {
    try {
      return await fn(request);
    } catch (e) {
      if (e instanceof HttpError) {
        const res = json(request, e.status, { error: { code: e.code, message: e.message } });
        if (e.status === 429) res.headers.set('Retry-After', '60');
        return res;
      }
      console.error(e);
      await logServerError(request, e);
      return json(request, 500, { error: { code: 'internal', message: 'Something went wrong.' } });
    }
  };
}

export async function readJson<T>(request: Request): Promise<T> {
  try {
    return (await request.json()) as T;
  } catch {
    throw new HttpError(400, 'bad_json', 'Request body must be JSON.');
  }
}

export function bearerToken(request: Request): string {
  const header = request.headers.get('authorization') ?? '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match?.[1]) throw new HttpError(401, 'unauthenticated', 'Sign in first.');
  return match[1];
}
