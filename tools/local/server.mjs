// LuzHire offline demo server (docs/OFFLINE_DEMO.md).
//
// Serves the Flutter web build on one port per module and, on every port,
// the same /api functions that run on Vercel (loaded straight from api/),
// plus /local-auth for offline sign-in. Data lives in the local Supabase
// (Docker), so all three modules share one database.
//
//   node tools/local/server.mjs        (normally via `npm run demo`)
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';
import { DATA_DIR, MODULES, ROOT, WEB_DIR, USERS_FILE, supabaseEnv } from './config.mjs';

// Node runs the API from a JavaScript build of api/ (TypeScript compiled by
// tsc, as Vercel does), refreshed on every start.
const API_DIR = join(DATA_DIR, 'build', 'api');
const tsc = spawnSync('npx', ['tsc', '-p', 'tsconfig.json', '--noEmit', 'false', '--outDir', join(DATA_DIR, 'build')], {
  cwd: ROOT,
  stdio: 'inherit',
  shell: process.platform === 'win32',
});
if (tsc.status !== 0) {
  console.error('Compiling api/ failed.');
  process.exit(1);
}

const env = supabaseEnv();
Object.assign(process.env, {
  SUPABASE_URL: env.API_URL,
  SUPABASE_SERVICE_ROLE_KEY: env.SERVICE_ROLE_KEY,
  LUZ_LOCAL_AUTH: '1',
  LUZ_LOCAL_USERS: USERS_FILE,
  LUZ_LOCAL_JWT_SECRET: env.JWT_SECRET,
  VERCEL_ENV: 'development',
});

const { localIdentity } = await import(pathToFileURL(join(API_DIR, '_lib', 'services.js')).href);
const identity = localIdentity();

// ---------------------------------------------------------------- /api routing
// File-system routes like Vercel: api/admin/users/[id]/[action] etc.
function findFunction(pathname) {
  const parts = pathname.replace(/^\/api\//, '').split('/').filter(Boolean);
  const walk = (dir, i) => {
    if (i === parts.length) return null;
    const last = i === parts.length - 1;
    const exact = join(dir, parts[i] + (last ? '.js' : ''));
    if (existsSync(exact) && !parts[i].startsWith('_')) {
      if (last) return exact;
      const found = walk(exact, i + 1);
      if (found) return found;
    }
    if (!existsSync(dir)) return null;
    for (const name of readdirSafe(dir)) {
      if (!/^\[.+\]/.test(name)) continue;
      const p = join(dir, name);
      if (last && name.endsWith('.js')) return p;
      if (!last && !name.endsWith('.js')) {
        const found = walk(p, i + 1);
        if (found) return found;
      }
    }
    return null;
  };
  return walk(API_DIR, 0);
}

const readdirSafe = (d) => {
  try {
    return readdirSync(d);
  } catch {
    return [];
  }
};

const handlers = new Map();
async function apiHandler(file, method) {
  if (!handlers.has(file)) handlers.set(file, await import(pathToFileURL(file).href));
  const mod = handlers.get(file);
  return mod[method] ?? (method === 'HEAD' ? mod.GET : undefined);
}

// ---------------------------------------------------------------- /local-auth
async function localAuth(path, request) {
  const body = request.method === 'POST' ? await request.json().catch(() => ({})) : {};
  const fail = (status, code, message) => Response.json({ error: { code, message } }, { status });
  try {
    let user;
    if (path === '/local-auth/sign-in') {
      user = identity.signIn(String(body.email ?? ''), String(body.password ?? ''));
    } else if (path === '/local-auth/sign-up') {
      user = identity.signUp(String(body.email ?? ''), String(body.password ?? ''), String(body.displayName ?? ''));
    } else if (path === '/local-auth/refresh') {
      const token = (request.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
      const { uid } = await identity.renew(token);
      user = identity.getUser(uid);
    } else {
      return fail(404, 'not_found', 'Unknown endpoint.');
    }
    return Response.json({ token: identity.issueToken(user) });
  } catch (e) {
    if (typeof e?.code === 'string' && e.code.startsWith('auth/')) return fail(401, e.code, e.message);
    console.error(e);
    return fail(500, 'auth/internal', 'Local sign-in failed.');
  }
}

// ---------------------------------------------------------------- static app
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.css': 'text/css',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.otf': 'font/otf',
  '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.txt': 'text/plain', '.webmanifest': 'application/manifest+json',
};

function indexHtml(module) {
  const links = Object.fromEntries(MODULES.map((m) => [m.name, `http://localhost:${m.port}`]));
  const meta = JSON.stringify({ module: module.name, links }).replace(/'/g, '&#39;');
  return readFileSync(join(WEB_DIR, 'index.html'), 'utf8')
    // Offline: no Firebase SDK from gstatic (local sign-in replaces it).
    .replace(/\s*<script src="firebase-sdk\.js"><\/script>/, '')
    .replace(/\s*<link rel="preconnect" href="https:\/\/www\.gstatic\.com">/, '')
    .replace(/<title>[^<]*<\/title>/, `<title>LuzHire · ${module.label} (offline)</title>`)
    .replace('</head>', `  <meta name="luz-module" content='${meta}'>\n</head>`);
}

function staticFile(module, pathname) {
  const file = normalize(join(WEB_DIR, decodeURIComponent(pathname)));
  if (!file.startsWith(resolve(WEB_DIR) + sep)) return null;
  if (pathname === '/' || pathname === '/index.html' || !existsSync(file) || statSync(file).isDirectory()) {
    // SPA fallback: deep links such as /employer/pipeline load the app.
    if (extname(pathname) && pathname !== '/index.html') return null;
    return new Response(indexHtml(module), { headers: { 'content-type': TYPES['.html'], 'cache-control': 'no-store' } });
  }
  return new Response(readFileSync(file), {
    headers: { 'content-type': TYPES[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-cache' },
  });
}

// ---------------------------------------------------------------- server
async function route(module, request) {
  const url = new URL(request.url);
  if (url.pathname.startsWith('/local-auth/')) return localAuth(url.pathname, request);
  if (url.pathname.startsWith('/api/')) {
    const file = findFunction(url.pathname);
    const fn = file && (await apiHandler(file, request.method));
    if (!fn) return Response.json({ error: { code: 'not_found', message: 'Unknown API route.' } }, { status: 404 });
    return fn(request);
  }
  return staticFile(module, url.pathname) ?? new Response('Not found', { status: 404 });
}

function toRequest(req, port) {
  const url = `http://localhost:${port}${req.url}`;
  const hasBody = req.method !== 'GET' && req.method !== 'HEAD';
  return new Request(url, {
    method: req.method,
    headers: Object.entries(req.headers).flatMap(([k, v]) => (Array.isArray(v) ? v.map((x) => [k, x]) : [[k, v]])),
    body: hasBody ? req : undefined,
    duplex: hasBody ? 'half' : undefined,
  });
}

if (!existsSync(join(WEB_DIR, 'index.html'))) {
  console.error(`No app build at ${WEB_DIR}. Run "npm run demo:setup" first (needs the internet once).`);
  process.exit(1);
}

for (const module of MODULES) {
  createServer(async (req, res) => {
    let response;
    try {
      response = await route(module, toRequest(req, module.port));
    } catch (e) {
      console.error(e);
      response = Response.json({ error: { code: 'internal', message: 'Server error.' } }, { status: 500 });
    }
    res.writeHead(response.status, Object.fromEntries(response.headers));
    res.end(Buffer.from(await response.arrayBuffer()));
  }).listen(module.port, '127.0.0.1', () => {
    console.log(`  ${module.label.padEnd(10)} http://localhost:${module.port}`);
  });
}
console.log('LuzHire offline demo (Ctrl+C to stop). Modules:');
