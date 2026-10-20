// Content-Security-Policy violation reports (the CSP header's report-uri).
// Each becomes an error-log entry so admins see what the policy blocked
// (or, in report-only mode, would block). URLs are reduced to origin + path.
import type { ErrorEntry } from './error-log.js';

function stripUrl(raw: unknown): string {
  if (typeof raw !== 'string' || !raw) return 'unknown';
  // Keywords such as "inline", "eval" or "wasm-eval" are not URLs.
  if (!/^[a-z][a-z0-9+.-]*:/i.test(raw)) return raw.slice(0, 60);
  try {
    const u = new URL(raw);
    if (u.protocol === 'data:' || u.protocol === 'blob:') return u.protocol;
    return `${u.origin}${u.pathname}`.slice(0, 200);
  } catch {
    return 'invalid-url';
  }
}

/** Reads a report-uri body ({"csp-report": {...}}) into log entries. */
export function entriesFromCspReport(body: unknown, userAgent: string | null): ErrorEntry[] {
  if (!body || typeof body !== 'object') return [];
  const r = (body as Record<string, unknown>)['csp-report'];
  if (!r || typeof r !== 'object') return [];
  const report = r as Record<string, unknown>;
  const directive = String(report['effective-directive'] ?? report['violated-directive'] ?? 'unknown')
    .split(' ')[0]!
    .slice(0, 40);
  const blocked = stripUrl(report['blocked-uri']);
  const mode = report['disposition'] === 'report' ? 'report-only' : 'blocked';
  let route: string | null = null;
  try {
    route = new URL(String(report['document-uri'])).pathname.slice(0, 200);
  } catch {
    route = null;
  }
  const source = stripUrl(report['source-file']);
  return [
    {
      source: 'web',
      message: `CSP ${mode}: ${directive} ${blocked}`.slice(0, 500),
      detail: source === 'unknown' ? null : `source: ${source}:${String(report['line-number'] ?? '')}`,
      route,
      release: null,
      user_agent: userAgent ? userAgent.slice(0, 300) : null,
    },
  ];
}
