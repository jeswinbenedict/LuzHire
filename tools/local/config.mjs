// Shared settings for the offline demo scripts (docs/OFFLINE_DEMO.md).
import { execSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
/** The demo build of the Flutter app (same code, local config). */
export const WEB_DIR = join(ROOT, 'app', 'build', 'demo');
export const DATA_DIR = join(ROOT, 'tools', 'local', '.data');
export const USERS_FILE = join(DATA_DIR, 'users.json');

/** One port per module; each signs in one role. */
export const MODULES = [
  { name: 'candidate', label: 'Candidate', port: 8081 },
  { name: 'recruiter', label: 'Recruiter', port: 8082 },
  { name: 'admin', label: 'Admin', port: 8083 },
];

/** Local Supabase URLs and keys from `supabase status` (Docker). */
export function supabaseEnv() {
  let out;
  try {
    out = execSync('npx supabase status -o env', { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch {
    throw new Error('The local database is not running. Start Docker Desktop, then run "npm run demo".');
  }
  const env = {};
  for (const line of out.split(/\r?\n/)) {
    const m = line.match(/^([A-Z_]+)="?(.*?)"?$/);
    if (m) env[m[1]] = m[2];
  }
  for (const key of ['API_URL', 'SERVICE_ROLE_KEY', 'JWT_SECRET']) {
    if (!env[key]) throw new Error(`supabase status did not report ${key}.`);
  }
  return env;
}
