// Account rules, kept free of I/O so they can be unit-tested with fakes.
import { HttpError } from './http.js';

export type AppRole = 'candidate' | 'employer' | 'admin';
const SELF_SERVICE_ROLES: readonly AppRole[] = ['candidate', 'employer'];
const ALL_ROLES: readonly AppRole[] = ['candidate', 'employer', 'admin'];

/** Subset of a verified Firebase ID token we rely on. */
export interface VerifiedToken {
  uid: string;
  email?: string;
  name?: string;
  email_verified?: boolean;
  app_role?: string;
}

export interface AccountDeps {
  verifyIdToken(token: string): Promise<VerifiedToken>;
  /** Replaces the user's custom claims. */
  setClaims(uid: string, claims: Record<string, unknown>): Promise<void>;
  /** Inserts the profile row if it does not exist yet. */
  ensureProfile(profile: { id: string; role: AppRole; email: string; display_name: string }): Promise<void>;
  updateProfileRole(uid: string, role: AppRole): Promise<void>;
  revokeSessions(uid: string): Promise<void>;
  audit(entry: { actor_id: string; action: string; target_id: string; diff: unknown }): Promise<void>;
}

/** Claims every LuzHire user carries (Supabase needs role=authenticated). */
export function claimsFor(appRole: AppRole) {
  return { role: 'authenticated', app_role: appRole };
}

function isRole(value: unknown, allowed: readonly AppRole[]): value is AppRole {
  return typeof value === 'string' && (allowed as readonly string[]).includes(value);
}

/**
 * POST /api/auth/bootstrap — first call after sign-up / first social sign-in.
 * Sets the role claims and creates the profile. Idempotent: a user who
 * already has a role keeps it (roles change only through an admin).
 */
export async function bootstrapAccount(
  deps: AccountDeps,
  idToken: string,
  body: { role?: unknown; displayName?: unknown },
): Promise<{ appRole: AppRole; refreshToken: boolean }> {
  const token = await verify(deps, idToken);
  if (!token.email) {
    throw new HttpError(400, 'email_required', 'Your account needs an email address.');
  }
  const email = token.email.toLowerCase();
  const fallbackName = typeof token.name === 'string' && token.name.trim() ? token.name.trim() : email.split('@')[0]!;
  const displayName = (typeof body.displayName === 'string' && body.displayName.trim()
    ? body.displayName.trim()
    : fallbackName
  ).slice(0, 120);

  if (isRole(token.app_role, ALL_ROLES)) {
    await deps.ensureProfile({ id: token.uid, role: token.app_role, email, display_name: displayName });
    return { appRole: token.app_role, refreshToken: false };
  }

  if (!isRole(body.role, SELF_SERVICE_ROLES)) {
    throw new HttpError(400, 'invalid_role', 'Choose either "candidate" or "employer".');
  }
  await deps.setClaims(token.uid, claimsFor(body.role));
  await deps.ensureProfile({ id: token.uid, role: body.role, email, display_name: displayName });
  return { appRole: body.role, refreshToken: true };
}

/** POST /api/admin/users/:id/role — admins change someone's role. */
export async function changeRole(
  deps: AccountDeps,
  idToken: string,
  targetUid: string,
  body: { role?: unknown },
): Promise<{ uid: string; appRole: AppRole }> {
  const caller = await verify(deps, idToken);
  if (caller.app_role !== 'admin') {
    throw new HttpError(403, 'forbidden', 'Only admins can change roles.');
  }
  if (!targetUid || targetUid.length > 128) {
    throw new HttpError(400, 'invalid_user', 'Unknown user.');
  }
  if (targetUid === caller.uid) {
    throw new HttpError(400, 'own_role', 'You cannot change your own role.');
  }
  if (!isRole(body.role, ALL_ROLES)) {
    throw new HttpError(400, 'invalid_role', 'Role must be candidate, employer or admin.');
  }
  await deps.setClaims(targetUid, claimsFor(body.role));
  await deps.updateProfileRole(targetUid, body.role);
  // Force the user to sign in again so the new role takes effect everywhere.
  await deps.revokeSessions(targetUid);
  await deps.audit({
    actor_id: caller.uid,
    action: 'profiles.role_change',
    target_id: targetUid,
    diff: { app_role: body.role },
  });
  return { uid: targetUid, appRole: body.role };
}

async function verify(deps: AccountDeps, idToken: string): Promise<VerifiedToken> {
  try {
    return await deps.verifyIdToken(idToken);
  } catch (error) {
    // Only a token Firebase rejected (auth/* codes) is the caller's fault.
    // Missing config (503) and other failures must not look like "sign in again".
    if (error instanceof HttpError) throw error;
    const code = (error as { code?: unknown } | null)?.code;
    if (typeof code === 'string' && code.startsWith('auth/')) {
      throw new HttpError(401, 'invalid_token', 'Your session is invalid. Sign in again.');
    }
    throw error;
  }
}
