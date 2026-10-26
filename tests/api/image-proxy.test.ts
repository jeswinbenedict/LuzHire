import { describe, expect, it } from 'vitest';
import { MAX_IMAGE_BYTES, allowedImageUrl, proxyImage } from '../../api/_lib/image-proxy.js';

const png = (size = 10, type = 'image/png') =>
  new Response(new Uint8Array(size), { headers: { 'content-type': type, 'content-length': String(size) } });

describe('image proxy redirects', () => {
  const hop = (location: string) => new Response(null, { status: 302, headers: { location } });
  it('a download that fails part-way is a clean 502', async () => {
    const broken = new Response(new ReadableStream({ pull(c) { c.error(new Error('timeout')); } }), { headers: { 'content-type': 'image/png' } });
    expect((await proxyImage('https://remotive.com/a', async () => broken)).status).toBe(502);
  });

  it('follows one redirect from Hack Club to its storage, and nothing else', async () => {
    const asked: string[] = [];
    const ok = await proxyImage('https://dash.hackathons.hackclub.com/rails/active_storage/x/icon.png', async (url) => {
      asked.push(url);
      return url.includes('s3.amazonaws.com') ? png(1200) : hop('https://hackathons-hackclub.s3.amazonaws.com/abc?X-Amz-Expires=300');
    });
    expect(ok.status).toBe(200);
    expect(asked).toHaveLength(2);
    // Elsewhere, or from a host with no known storage: refused.
    expect((await proxyImage('https://dash.hackathons.hackclub.com/x.png', async () => hop('https://evil.example/x.png'))).status).toBe(404);
    expect((await proxyImage('https://remotive.com/a', async () => hop('https://hackathons-hackclub.s3.amazonaws.com/a'))).status).toBe(404);
  });
});

describe('image proxy', () => {
  it('only accepts https URLs on listed hosts', () => {
    expect(allowedImageUrl('https://remotive.com/job/7/logo')?.hostname).toBe('remotive.com');
    expect(allowedImageUrl('https://media2.dev.to/dynamic/image/width=1200/cover.png')?.hostname).toBe('media2.dev.to');
    expect(allowedImageUrl('https://jobicy.com/data/logo.png')?.hostname).toBe('jobicy.com');
    for (const bad of [
      null,
      'http://remotive.com/job/7/logo',
      'https://evil.example/x.png',
      'https://remotive.com.evil.example/x.png',
      'https://user:pw@remotive.com/x.png',
      'https://remotive.com:8443/x.png',
      'file:///etc/passwd',
      'not a url',
    ]) {
      expect(allowedImageUrl(bad)).toBeNull();
    }
  });

  it('serves allowed raster images with long caching and a locked-down CSP', async () => {
    const r = await proxyImage('https://remotive.com/job/7/logo', async () => png(39_513));
    expect(r.status).toBe(200);
    expect((r.body as Uint8Array).byteLength).toBe(39_513);
    expect(r.headers['Content-Type']).toBe('image/png');
    expect(r.headers['Cache-Control']).toContain('s-maxage=604800');
    expect(r.headers['Content-Security-Policy']).toBe("default-src 'none'; sandbox");
  });

  it('refuses other hosts, SVG, HTML, huge files and upstream failures', async () => {
    let called = false;
    expect((await proxyImage('https://evil.example/a.png', async () => ((called = true), png()))).status).toBe(403);
    expect(called).toBe(false);
    expect((await proxyImage('https://remotive.com/a', async () => png(10, 'image/svg+xml'))).status).toBe(404);
    expect((await proxyImage('https://remotive.com/a', async () => png(10, 'text/html'))).status).toBe(404);
    expect((await proxyImage('https://remotive.com/a', async () => png(MAX_IMAGE_BYTES + 1))).status).toBe(404);
    expect((await proxyImage('https://remotive.com/a', async () => new Response('x', { status: 500 }))).status).toBe(404);
    expect((await proxyImage('https://remotive.com/a', async () => { throw new Error('redirect'); })).status).toBe(502);
  });
});
