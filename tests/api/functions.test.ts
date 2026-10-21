import { readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

// Every .ts file in api/ (outside api/_lib) becomes a Vercel Function, and
// the Hobby plan refuses a deployment with more than 12 of them.
const HOBBY_FUNCTION_LIMIT = 12;

function functionFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return name === '_lib' ? [] : functionFiles(path);
    return name.endsWith('.ts') ? [path] : [];
  });
}

describe('Vercel Functions', () => {
  it(`stay within the Hobby plan's ${HOBBY_FUNCTION_LIMIT}`, () => {
    const files = functionFiles(join(__dirname, '..', '..', 'api'));
    expect(files.length, files.join('\n')).toBeLessThanOrEqual(HOBBY_FUNCTION_LIMIT);
  });
});
