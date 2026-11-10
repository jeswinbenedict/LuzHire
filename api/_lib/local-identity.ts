// Offline identity provider for the local demo (docs/OFFLINE_DEMO.md).
// Stands in for Firebase Auth when LUZ_LOCAL_AUTH=1: accounts live in a JSON
// file, passwords are scrypt hashes, and ID tokens are HS256 JWTs signed with
// the local Supabase JWT secret, so local PostgREST, Realtime and Storage
// accept them exactly as the cloud project accepts Firebase tokens.
// Never enabled on Vercel (see identity() in services.ts).
import { createHmac, randomBytes, randomUUID, scryptSync, timingSafeEqual } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import type { VerifiedToken } from './accounts.js';

export interface LocalUser {
  uid: string;
  email: string;
  displayName: string;
  passwordHash: string;
  emailVerified: boolean;
  disabled: boolean;
  claims: Record<string, unknown>;
  /** Tokens issued before this time (seconds) are rejected. */
  validAfter: number;
}

/** Same `auth/...` codes as Firebase, so callers map errors the same way. */
export class LocalAuthError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}

const TOKEN_TTL_SECONDS = 60 * 60;

export function hashPassword(password: string): string {
  const salt = randomBytes(16).toString('hex');
  return `${salt}:${scryptSync(password, salt, 32).toString('hex')}`;
}

function passwordMatches(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(':');
  if (!salt || !hash) return false;
  const actual = scryptSync(password, salt, 32);
  const expected = Buffer.from(hash, 'hex');
  return expected.length === actual.length && timingSafeEqual(actual, expected);
}

const b64url = (data: Buffer | string) => Buffer.from(data).toString('base64url');

export class LocalIdentity {
  constructor(
    private readonly file: string,
    private readonly secret: string,
    private readonly now: () => number = () => Math.floor(Date.now() / 1000),
  ) {
    if (secret.length < 32) throw new Error('The local JWT secret must be at least 32 characters.');
  }

  // ---------------------------------------------------------------- store
  private load(): LocalUser[] {
    if (!existsSync(this.file)) return [];
    return JSON.parse(readFileSync(this.file, 'utf8')) as LocalUser[];
  }

  private save(users: LocalUser[]): void {
    mkdirSync(dirname(this.file), { recursive: true });
    writeFileSync(this.file, JSON.stringify(users, null, 2));
  }

  private update(uid: string, change: (u: LocalUser) => void): LocalUser {
    const users = this.load();
    const user = users.find((u) => u.uid === uid);
    if (!user) throw new LocalAuthError('auth/user-not-found', 'No user with this id.');
    change(user);
    this.save(users);
    return user;
  }

  getUser(uid: string): LocalUser | undefined {
    return this.load().find((u) => u.uid === uid);
  }

  /** Creates (or replaces) an account; used by sign-up and the demo seed. */
  upsertUser(input: {
    uid?: string;
    email: string;
    password: string;
    displayName: string;
    emailVerified?: boolean;
    claims?: Record<string, unknown>;
  }): LocalUser {
    const users = this.load();
    const email = input.email.trim().toLowerCase();
    const existing = users.findIndex((u) => u.email === email || u.uid === input.uid);
    const user: LocalUser = {
      uid: input.uid ?? `local-${randomUUID()}`,
      email,
      displayName: input.displayName.trim(),
      passwordHash: hashPassword(input.password),
      emailVerified: input.emailVerified ?? true,
      disabled: false,
      claims: input.claims ?? {},
      validAfter: 0,
    };
    if (existing >= 0) users[existing] = user;
    else users.push(user);
    this.save(users);
    return user;
  }

  // ---------------------------------------------------------------- sign-in
  signUp(email: string, password: string, displayName: string): LocalUser {
    const normalized = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) {
      throw new LocalAuthError('auth/invalid-email', 'Enter a valid email address.');
    }
    if (password.length < 8) {
      throw new LocalAuthError('auth/weak-password', 'Choose a stronger password.');
    }
    if (this.load().some((u) => u.email === normalized)) {
      throw new LocalAuthError('auth/email-already-in-use', 'This email is registered.');
    }
    // No mail server offline: local accounts start confirmed.
    return this.upsertUser({ email: normalized, password, displayName, emailVerified: true });
  }

  signIn(email: string, password: string): LocalUser {
    const user = this.load().find((u) => u.email === email.trim().toLowerCase());
    if (!user || !passwordMatches(password, user.passwordHash)) {
      throw new LocalAuthError('auth/invalid-credential', 'Email or password is incorrect.');
    }
    if (user.disabled) throw new LocalAuthError('auth/user-disabled', 'This account is suspended.');
    return user;
  }

  // ---------------------------------------------------------------- tokens
  issueToken(user: LocalUser): string {
    const iat = this.now();
    const payload = {
      ...user.claims,
      iss: 'luzhire-local',
      aud: 'authenticated',
      sub: user.uid,
      email: user.email,
      email_verified: user.emailVerified,
      name: user.displayName,
      iat,
      exp: iat + TOKEN_TTL_SECONDS,
    };
    const head = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
    const body = b64url(JSON.stringify(payload));
    const sig = createHmac('sha256', this.secret).update(`${head}.${body}`).digest('base64url');
    return `${head}.${body}.${sig}`;
  }

  /** Mirrors firebase-admin verifyIdToken(token, checkRevoked = true). */
  async verifyIdToken(token: string): Promise<VerifiedToken> {
    return this.check(token, 0);
  }

  /**
   * A fresh token for a session: the old token may have expired up to a week
   * ago (the app was closed), but must still be genuine and not revoked.
   */
  renew(token: string): Promise<VerifiedToken> {
    return this.check(token, 7 * 24 * 60 * 60);
  }

  private async check(token: string, graceSeconds: number): Promise<VerifiedToken> {
    const parts = token.split('.');
    if (parts.length !== 3) throw new LocalAuthError('auth/argument-error', 'Malformed token.');
    const [head, body, sig] = parts as [string, string, string];
    const expected = createHmac('sha256', this.secret).update(`${head}.${body}`).digest();
    const actual = Buffer.from(sig, 'base64url');
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
      throw new LocalAuthError('auth/invalid-id-token', 'Bad signature.');
    }
    const claims = JSON.parse(Buffer.from(body, 'base64url').toString('utf8')) as Record<string, unknown>;
    if (typeof claims.exp !== 'number' || claims.exp + graceSeconds < this.now()) {
      throw new LocalAuthError('auth/id-token-expired', 'Token expired.');
    }
    const user = this.getUser(String(claims.sub));
    if (!user) throw new LocalAuthError('auth/user-not-found', 'Unknown user.');
    if (user.disabled) throw new LocalAuthError('auth/user-disabled', 'Account suspended.');
    if (typeof claims.iat !== 'number' || claims.iat < user.validAfter) {
      throw new LocalAuthError('auth/id-token-revoked', 'Session revoked.');
    }
    return {
      uid: user.uid,
      email: user.email,
      name: user.displayName,
      email_verified: user.emailVerified,
      app_role: typeof claims.app_role === 'string' ? claims.app_role : undefined,
    };
  }

  // ---------------------------------------------------------------- admin (firebase-admin shape)
  async setCustomUserClaims(uid: string, claims: Record<string, unknown> | null): Promise<void> {
    this.update(uid, (u) => (u.claims = claims ?? {}));
  }

  async revokeRefreshTokens(uid: string): Promise<void> {
    // Tokens issued in this same second stay valid, as in Firebase.
    this.update(uid, (u) => (u.validAfter = this.now()));
  }

  async updateUser(uid: string, change: { disabled?: boolean; emailVerified?: boolean }): Promise<void> {
    this.update(uid, (u) => {
      if (change.disabled !== undefined) u.disabled = change.disabled;
      if (change.emailVerified !== undefined) u.emailVerified = change.emailVerified;
    });
  }
}
