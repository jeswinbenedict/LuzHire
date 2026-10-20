import { describe, expect, it, beforeEach } from 'vitest';
import { bootstrapAccount, changeRole, changeStatus, type AccountDeps, type VerifiedToken } from '../../api/_lib/accounts.js';
import { HttpError, corsHeaders } from '../../api/_lib/http.js';

type Call = [string, ...unknown[]];

function fakeDeps(tokens: Record<string, VerifiedToken>) {
  const calls: Call[] = [];
  const deps: AccountDeps = {
    async verifyIdToken(t) {
      const tok = tokens[t];
      if (!tok) throw Object.assign(new Error('bad token'), { code: 'auth/argument-error' });
      return tok;
    },
    async setClaims(uid, claims) { calls.push(['setClaims', uid, claims]); },
    async ensureProfile(p) { calls.push(['ensureProfile', p]); },
    async updateProfileRole(uid, role) { calls.push(['updateProfileRole', uid, role]); },
    async setDisabled(uid, disabled) { calls.push(['setDisabled', uid, disabled]); },
    async updateProfileStatus(uid, status) { calls.push(['updateProfileStatus', uid, status]); },
    async revokeSessions(uid) { calls.push(['revokeSessions', uid]); },
    async audit(e) { calls.push(['audit', e]); },
  };
  return { deps, calls };
}

async function expectHttp(p: Promise<unknown>, status: number, code: string) {
  await expect(p).rejects.toBeInstanceOf(HttpError);
  await p.catch((e: HttpError) => {
    expect(e.status).toBe(status);
    expect(e.code).toBe(code);
  });
}

describe('bootstrapAccount', () => {
  const tokens = {
    fresh: { uid: 'u1', email: 'Asha@Example.com', name: 'Asha Verma' },
    existing: { uid: 'u2', email: 'r@example.com', app_role: 'employer' },
    noEmail: { uid: 'u3' },
  };

  it('sets claims and creates the profile for a new candidate', async () => {
    const { deps, calls } = fakeDeps(tokens);
    const result = await bootstrapAccount(deps, 'fresh', { role: 'candidate' });
    expect(result).toEqual({ appRole: 'candidate', refreshToken: true });
    expect(calls).toEqual([
      ['setClaims', 'u1', { role: 'authenticated', app_role: 'candidate' }],
      ['ensureProfile', { id: 'u1', role: 'candidate', email: 'asha@example.com', display_name: 'Asha Verma' }],
    ]);
  });

  it('prefers the display name the user typed', async () => {
    const { deps, calls } = fakeDeps(tokens);
    await bootstrapAccount(deps, 'fresh', { role: 'employer', displayName: '  Meera  ' });
    expect(calls[1]).toEqual([
      'ensureProfile',
      { id: 'u1', role: 'employer', email: 'asha@example.com', display_name: 'Meera' },
    ]);
  });

  it('never grants admin through sign-up', async () => {
    const { deps, calls } = fakeDeps(tokens);
    await expectHttp(bootstrapAccount(deps, 'fresh', { role: 'admin' }), 400, 'invalid_role');
    expect(calls).toEqual([]);
  });

  it('keeps an existing role and does not touch claims (idempotent)', async () => {
    const { deps, calls } = fakeDeps(tokens);
    const result = await bootstrapAccount(deps, 'existing', { role: 'candidate' });
    expect(result).toEqual({ appRole: 'employer', refreshToken: false });
    expect(calls.map((c) => c[0])).toEqual(['ensureProfile']);
  });

  it('rejects invalid tokens and accounts without email', async () => {
    const { deps } = fakeDeps(tokens);
    await expectHttp(bootstrapAccount(deps, 'nope', { role: 'candidate' }), 401, 'invalid_token');
    await expectHttp(bootstrapAccount(deps, 'noEmail', { role: 'candidate' }), 400, 'email_required');
  });

  it('reports server misconfiguration instead of blaming the token', async () => {
    const { deps } = fakeDeps(tokens);
    deps.verifyIdToken = async () => {
      throw new HttpError(503, 'not_configured', 'Server is missing FIREBASE_SERVICE_ACCOUNT.');
    };
    await expectHttp(bootstrapAccount(deps, 'x', { role: 'candidate' }), 503, 'not_configured');
    deps.verifyIdToken = async () => {
      throw new SyntaxError('Unexpected token in JSON');
    };
    await expect(bootstrapAccount(deps, 'x', { role: 'candidate' })).rejects.toThrow(SyntaxError);
  });
});

describe('changeRole', () => {
  const tokens = {
    admin: { uid: 'a1', email: 'a@example.com', app_role: 'admin' },
    employer: { uid: 'e1', email: 'e@example.com', app_role: 'employer' },
  };
  let ctx: ReturnType<typeof fakeDeps>;
  beforeEach(() => { ctx = fakeDeps(tokens); });

  it('lets an admin change a role, signs the user out and audits it', async () => {
    const result = await changeRole(ctx.deps, 'admin', 'u9', { role: 'employer' });
    expect(result).toEqual({ uid: 'u9', appRole: 'employer' });
    expect(ctx.calls.map((c) => c[0])).toEqual(['setClaims', 'updateProfileRole', 'revokeSessions', 'audit']);
    expect(ctx.calls[3]?.[1]).toMatchObject({ actor_id: 'a1', target_id: 'u9', action: 'profiles.role_change' });
  });

  it('refuses non-admins', async () => {
    await expectHttp(changeRole(ctx.deps, 'employer', 'u9', { role: 'admin' }), 403, 'forbidden');
    expect(ctx.calls).toEqual([]);
  });

  it('refuses changing your own role and unknown roles', async () => {
    await expectHttp(changeRole(ctx.deps, 'admin', 'a1', { role: 'candidate' }), 400, 'own_role');
    await expectHttp(changeRole(ctx.deps, 'admin', 'u9', { role: 'superuser' }), 400, 'invalid_role');
  });
});

describe('changeStatus', () => {
  const tokens = {
    admin: { uid: 'a1', email: 'a@example.com', app_role: 'admin' },
    employer: { uid: 'e1', email: 'e@example.com', app_role: 'employer' },
  };
  let ctx: ReturnType<typeof fakeDeps>;
  beforeEach(() => { ctx = fakeDeps(tokens); });

  it('suspends: blocks writes, disables sign-in, signs out and audits', async () => {
    const result = await changeStatus(ctx.deps, 'admin', 'u9', { status: 'suspended' });
    expect(result).toEqual({ uid: 'u9', status: 'suspended' });
    expect(ctx.calls.map((c) => c[0])).toEqual([
      'updateProfileStatus', 'setDisabled', 'revokeSessions', 'audit',
    ]);
    expect(ctx.calls[1]).toEqual(['setDisabled', 'u9', true]);
    expect(ctx.calls[3]?.[1]).toMatchObject({ action: 'profiles.suspend', target_id: 'u9' });
  });

  it('reactivates without signing anyone out', async () => {
    await changeStatus(ctx.deps, 'admin', 'u9', { status: 'active' });
    expect(ctx.calls.map((c) => c[0])).toEqual(['updateProfileStatus', 'setDisabled', 'audit']);
    expect(ctx.calls[1]).toEqual(['setDisabled', 'u9', false]);
  });

  it('refuses non-admins, self-suspension and unknown statuses', async () => {
    await expectHttp(changeStatus(ctx.deps, 'employer', 'u9', { status: 'suspended' }), 403, 'forbidden');
    await expectHttp(changeStatus(ctx.deps, 'admin', 'a1', { status: 'suspended' }), 400, 'own_status');
    await expectHttp(changeStatus(ctx.deps, 'admin', 'u9', { status: 'deleted' }), 400, 'invalid_status');
    expect(ctx.calls).toEqual([]);
  });
});

describe('CORS', () => {
  it('allows localhost only outside production, plus configured origins', () => {
    const req = (origin: string) => new Request('https://x/api', { headers: { origin } });
    delete process.env.VERCEL_ENV;
    process.env.ALLOWED_ORIGINS = 'https://staging.luzhire.app';
    expect(corsHeaders(req('http://localhost:5173'))['Access-Control-Allow-Origin']).toBe('http://localhost:5173');
    expect(corsHeaders(req('https://staging.luzhire.app'))['Access-Control-Allow-Origin']).toBe('https://staging.luzhire.app');
    expect(corsHeaders(req('https://evil.example'))).toEqual({});
    process.env.VERCEL_ENV = 'production';
    expect(corsHeaders(req('http://localhost:5173'))).toEqual({});
    delete process.env.VERCEL_ENV;
  });
});
