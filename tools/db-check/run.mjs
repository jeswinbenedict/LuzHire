// Validates supabase/migrations, seed.sql and supabase/tests/database/*.test.sql
// in PGlite (Postgres in WebAssembly), with no Docker needed.
//   npm run db:check            migrations + seed + tests
//   npm run db:check -- --no-seed
// CI additionally runs the real `supabase test db` against Docker Postgres.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const sb = join(root, 'supabase');
const read = (p) => readFileSync(p, 'utf8');
const withSeed = !process.argv.includes('--no-seed');

const db = new PGlite({ extensions: { pg_trgm } });
let failures = 0;

async function run(label, sql) {
  try {
    await db.exec(sql);
    console.log(`  ✓ ${label}`);
  } catch (e) {
    failures++;
    console.error(`  ✗ ${label}\n    ${e.message}${e.position ? ` (at char ${e.position})` : ''}`);
    try { await db.exec('rollback'); } catch { /* not in a transaction */ }
  }
}

console.log('Platform stubs');
await run('supabase stubs', read(join(here, 'supabase-stubs.sql')));
await run('pgTAP shim', read(join(here, 'pgtap-shim.sql')));

console.log('Migrations');
const migDir = join(sb, 'migrations');
for (const f of readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort()) {
  await run(f, read(join(migDir, f)));
}

if (withSeed && existsSync(join(sb, 'seed.sql'))) {
  console.log('Seed');
  await run('seed.sql', read(join(sb, 'seed.sql')));
}

console.log('Tests');
const testDir = join(sb, 'tests', 'database');
const testFiles = existsSync(testDir)
  ? readdirSync(testDir).filter((f) => f.endsWith('.test.sql')).sort()
  : [];
let passed = 0;
let failed = 0;
for (const f of testFiles) {
  const sql = read(join(testDir, f))
    .replace(/create\s+extension\s+if\s+not\s+exists\s+pgtap[^;]*;/gi, '')
    .replace(/^\s*begin\s*;/im, 'begin; set local search_path = public, extensions, tap;');
  let results;
  try {
    results = await db.exec(sql);
  } catch (e) {
    failures++;
    console.error(`  ✗ ${f}: ${e.message}`);
    try { await db.exec('rollback'); } catch { /* ignore */ }
    continue;
  }
  const lines = results
    .flatMap((r) => r.rows)
    .flatMap((row) => Object.values(row))
    .filter((v) => typeof v === 'string' && /^(ok|not ok|1\.\.)/.test(v));
  const planLine = lines.find((l) => l.startsWith('1..'));
  const planned = planLine ? Number(planLine.slice(3)) : null;
  const tests = lines.filter((l) => !l.startsWith('1..'));
  const bad = tests.filter((l) => l.startsWith('not ok'));
  const planOk = planned === null || planned === tests.length;
  passed += tests.length - bad.length;
  failed += bad.length + (planOk ? 0 : 1);
  console.log(`  ${bad.length || !planOk ? '✗' : '✓'} ${f}: ${tests.length - bad.length}/${tests.length}` +
    (planOk ? '' : ` (planned ${planned})`));
  for (const b of bad) console.error(`      ${b}`);
}

console.log(`\n${passed} assertions passed, ${failed} failed, ${failures} errors.`);
await db.close();
process.exit(failed || failures ? 1 : 0);
