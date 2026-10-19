// Lazily-initialised server clients. Secrets come only from Vercel env vars:
//   FIREBASE_SERVICE_ACCOUNT   base64 of the Firebase service-account JSON
//   SUPABASE_URL               https://<ref>.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY  service role key (bypasses RLS — server only!)
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { HttpError } from './http.js';

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new HttpError(503, 'not_configured', `Server is missing ${name}.`);
  return value;
}

let auth: Auth | undefined;
export function firebaseAuth(): Auth {
  if (!auth) {
    const app =
      getApps()[0] ??
      initializeApp({
        credential: cert(JSON.parse(Buffer.from(required('FIREBASE_SERVICE_ACCOUNT'), 'base64').toString('utf8'))),
      });
    auth = getAuth(app);
  }
  return auth;
}

let db: SupabaseClient | undefined;
export function supabaseAdmin(): SupabaseClient {
  db ??= createClient(required('SUPABASE_URL'), required('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return db;
}
