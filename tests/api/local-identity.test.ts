import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { LocalIdentity } from '../../api/_lib/local-identity.js';

const SECRET = 'super-secret-jwt-token-with-at-least-32-characters-long';

function store(now = () => 1_000_000) {
  const file = join(mkdtempSync(join(tmpdir(), 'luz-id-')), 'users.json');
  return new LocalIdentity(file, SECRET, now);
}

const claimsOf = (token: string) =>
  JSON.parse(Buffer.from(token.split('.')[1]!, 'base64url').toString('utf8')) as Record<string, unknown>;

describe('LocalIdentity', () => {
  it('signs up, signs in and issues tokens Supabase accepts (role claim, HS256)', async () => {
    const id = store();
    const user = id.signUp('Tom@Example.com', 'password-1', 'Tom');
    await id.setCustomUserClaims(user.uid, { role: 'authenticated', app_role: 'candidate' });
    const signedIn = id.signIn('tom@example.com', 'password-1');
    const token = id.issueToken(signedIn);
    expect(claimsOf(token)).toMatchObject({ sub: user.uid, role: 'authenticated', app_role: 'candidate', aud: 'authenticated', email_verified: true });
    await expect(id.verifyIdToken(token)).resolves.toMatchObject({ uid: user.uid, app_role: 'candidate', email: 'tom@example.com' });
  });

  it('rejects wrong passwords, duplicate emails and weak passwords with Firebase codes', () => {
    const id = store();
    id.signUp('a@b.co', 'password-1', 'A');
    expect(() => id.signIn('a@b.co', 'wrong-pass')).toThrow(expect.objectContaining({ code: 'auth/invalid-credential' }));
    expect(() => id.signUp('a@b.co', 'password-2', 'A')).toThrow(expect.objectContaining({ code: 'auth/email-already-in-use' }));
    expect(() => id.signUp('c@b.co', 'short', 'C')).toThrow(expect.objectContaining({ code: 'auth/weak-password' }));
  });

  it('rejects tampered, expired, revoked and suspended tokens', async () => {
    let now = 1_000_000;
    const id = store(() => now);
    const user = id.signUp('a@b.co', 'password-1', 'A');
    const token = id.issueToken(user);
    const [h, , s] = token.split('.');
    const forged = `${h}.${Buffer.from(JSON.stringify({ ...claimsOf(token), app_role: 'admin' })).toString('base64url')}.${s}`;
    await expect(id.verifyIdToken(forged)).rejects.toMatchObject({ code: 'auth/invalid-id-token' });

    now += 1;
    await id.revokeRefreshTokens(user.uid);
    await expect(id.verifyIdToken(token)).rejects.toMatchObject({ code: 'auth/id-token-revoked' });

    const fresh = id.issueToken(id.getUser(user.uid)!);
    await id.updateUser(user.uid, { disabled: true });
    await expect(id.verifyIdToken(fresh)).rejects.toMatchObject({ code: 'auth/user-disabled' });
    expect(() => id.signIn('a@b.co', 'password-1')).toThrow(expect.objectContaining({ code: 'auth/user-disabled' }));

    await id.updateUser(user.uid, { disabled: false });
    now += 3601;
    await expect(id.verifyIdToken(fresh)).rejects.toMatchObject({ code: 'auth/id-token-expired' });
  });

  it('lets an admin confirm an email', async () => {
    const id = store();
    const user = id.upsertUser({ email: 'x@y.co', password: 'password-1', displayName: 'X', emailVerified: false });
    await id.updateUser(user.uid, { emailVerified: true });
    expect(id.getUser(user.uid)?.emailVerified).toBe(true);
  });
});
