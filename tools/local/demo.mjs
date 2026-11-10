// LuzHire offline demo: one command per step (docs/OFFLINE_DEMO.md).
//
//   npm run demo:setup   once, WITH internet: Docker images, app build, data
//   npm run demo         any time, offline: database + the three modules
//   npm run demo:reset   back to the fresh demo data (offline)
import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { DATA_DIR, MODULES, ROOT, WEB_DIR, supabaseEnv } from './config.mjs';
import { seedAccounts, uploadResumes } from './seed.mjs';

const step = (title) => console.log(`\n▸ ${title}`);

function run(cmd, args, opts = {}) {
  const r = spawnSync(cmd, args, { cwd: ROOT, stdio: 'inherit', shell: process.platform === 'win32', ...opts });
  if (r.status !== 0) {
    console.error(`\n✗ "${cmd} ${args.join(' ')}" failed.`);
    process.exit(r.status ?? 1);
  }
}

function startDatabase() {
  step('Starting the local database (Docker)');
  const docker = spawnSync('docker', ['info'], { stdio: 'ignore', shell: process.platform === 'win32' });
  if (docker.status !== 0) {
    console.error('✗ Docker is not running. Open Docker Desktop, wait until it says "running", then try again.');
    process.exit(1);
  }
  run('npx', ['supabase', 'start']);
}

function resetData() {
  step('Loading the demo data (migrations + seed)');
  // Right after `supabase start` the first reset can fail while containers
  // settle; one retry is enough.
  const args = ['supabase', 'db', 'reset', '--local'];
  const first = spawnSync('npx', args, { cwd: ROOT, stdio: 'inherit', shell: process.platform === 'win32' });
  if (first.status !== 0) {
    console.log('  retrying…');
    run('npx', ['supabase', 'start']);
    run('npx', args);
  }
}

async function seedSignIns(env) {
  step('Creating the demo sign-ins and resume files');
  await seedAccounts(env);
  await uploadResumes(env);
}

function buildApp(env) {
  step('Building the app for the offline demo (a few minutes)');
  const demoEnv = {
    APP_ENV: 'demo',
    SUPABASE_URL: env.API_URL,
    SUPABASE_PUBLISHABLE_KEY: env.PUBLISHABLE_KEY || env.ANON_KEY,
    API_BASE_URL: '',
    AUTH_PROVIDER: 'local',
  };
  mkdirSync(join(ROOT, 'app', 'env'), { recursive: true });
  writeFileSync(join(ROOT, 'app', 'env', 'demo.json'), JSON.stringify(demoEnv, null, 2));
  // FLUTTER=<path to flutter(.bat)> when flutter is not on the PATH.
  run(process.env.FLUTTER || 'flutter', [
    'build', 'web', '--wasm', '--release', '--no-web-resources-cdn',
    '--dart-define-from-file=env/demo.json', '--output', WEB_DIR,
  ], { cwd: join(ROOT, 'app') });
}

function serve() {
  step('Starting the modules');
  run('node', [join(ROOT, 'tools', 'local', 'server.mjs')]);
}

const command = process.argv[2] ?? 'start';
mkdirSync(DATA_DIR, { recursive: true });

if (command === 'setup') {
  startDatabase();
  resetData();
  const env = supabaseEnv();
  await seedSignIns(env);
  buildApp(env);
  console.log('\n✓ Ready. Start the demo any time (no internet needed) with: npm run demo');
  console.log(MODULES.map((m) => `  ${m.label.padEnd(10)} http://localhost:${m.port}`).join('\n'));
} else if (command === 'reset') {
  startDatabase();
  resetData();
  await seedSignIns(supabaseEnv());
  console.log('\n✓ Demo data is fresh again. Start with: npm run demo');
} else if (command === 'start') {
  startDatabase();
  serve();
} else {
  console.error(`Unknown command "${command}". Use setup, start or reset.`);
  process.exit(1);
}
