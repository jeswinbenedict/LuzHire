// Lazily-initialised server clients. Secrets come only from Vercel env vars:
//   FIREBASE_SERVICE_ACCOUNT   Firebase service-account JSON (raw, or base64 of it)
//   SUPABASE_URL               https://<ref>.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY  service role key (bypasses RLS — server only!)
import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { HttpError } from './http.js';

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new HttpError(503, 'not_configured', `Server is missing ${name}.`);
  return value;
}

/** Accepts the service-account JSON as-is or base64-encoded. */
export function parseServiceAccount(value: string): Record<string, unknown> {
  const raw = value.trim();
  const text = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
  try {
    const parsed: unknown = JSON.parse(text);
    if (parsed && typeof parsed === 'object' && 'private_key' in parsed && 'client_email' in parsed) {
      return parsed as Record<string, unknown>;
    }
  } catch {
    // fall through
  }
  throw new HttpError(
    503,
    'not_configured',
    'FIREBASE_SERVICE_ACCOUNT is not a valid service-account JSON (raw or base64).',
  );
}

function firebaseApp(): App {
  return (
    getApps()[0] ??
    initializeApp({
      credential: cert(parseServiceAccount(required('FIREBASE_SERVICE_ACCOUNT'))),
    })
  );
}

let auth: Auth | undefined;
export function firebaseAuth(): Auth {
  auth ??= getAuth(firebaseApp());
  return auth;
}

let messaging: Messaging | undefined;
export function firebaseMessaging(): Messaging {
  messaging ??= getMessaging(firebaseApp());
  return messaging;
}

let db: SupabaseClient | undefined;
export function supabaseAdmin(): SupabaseClient {
  db ??= createClient(required('SUPABASE_URL'), required('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return db;
}
