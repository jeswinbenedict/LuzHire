import { describe, expect, it } from 'vitest';
import { entriesFromCspReport } from '../../api/_lib/csp-report.js';

describe('CSP reports', () => {
  it('turns a report into an error-log entry without query strings', () => {
    const [entry] = entriesFromCspReport(
      {
        'csp-report': {
          'document-uri': 'https://luzhire.vercel.app/jobs?q=private+search',
          'effective-directive': 'script-src-elem',
          'blocked-uri': 'https://cdn.example.com/lib.js?token=abc123',
          disposition: 'report',
          'source-file': 'https://luzhire.vercel.app/main.dart.mjs',
          'line-number': 12,
        },
      },
      'Mozilla/5.0',
    );
    expect(entry).toEqual({
      source: 'web',
      message: 'CSP report-only: script-src-elem https://cdn.example.com/lib.js',
      detail: 'source: https://luzhire.vercel.app/main.dart.mjs:12',
      route: '/jobs',
      release: null,
      user_agent: 'Mozilla/5.0',
    });
  });

  it('handles keyword sources, data URLs and enforced blocks', () => {
    const msg = (blocked: string, disposition = 'enforce') =>
      entriesFromCspReport(
        { 'csp-report': { 'document-uri': 'https://x/', 'violated-directive': 'script-src', 'blocked-uri': blocked, disposition } },
        null,
      )[0]!.message;
    expect(msg('eval')).toBe('CSP blocked: script-src eval');
    expect(msg('data:image/png;base64,AAAA')).toBe('CSP blocked: script-src data:');
  });

  it('ignores anything that is not a CSP report', () => {
    expect(entriesFromCspReport(null, null)).toEqual([]);
    expect(entriesFromCspReport({ hello: 1 }, null)).toEqual([]);
  });
});
