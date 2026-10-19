// Production wiring of AccountDeps: Firebase Admin + Supabase service role.
import type { AccountDeps } from './accounts.js';
import { HttpError } from './http.js';
import { firebaseAuth, supabaseAdmin } from './services.js';

function check(error: { message: string } | null, what: string): void {
  if (error) {
    console.error(`${what} failed:`, error.message);
    throw new HttpError(502, 'database_error', 'Could not save your account. Try again.');
  }
}

export function liveAccountDeps(): AccountDeps {
  return {
    verifyIdToken: (token) => firebaseAuth().verifyIdToken(token, true),
    setClaims: (uid, claims) => firebaseAuth().setCustomUserClaims(uid, claims),
    revokeSessions: (uid) => firebaseAuth().revokeRefreshTokens(uid),
    async ensureProfile(profile) {
      const { error } = await supabaseAdmin()
        .from('profiles')
        .upsert(profile, { onConflict: 'id', ignoreDuplicates: true });
      check(error, 'ensureProfile');
    },
    async updateProfileRole(uid, role) {
      const { error } = await supabaseAdmin().from('profiles').update({ role }).eq('id', uid);
      check(error, 'updateProfileRole');
    },
    async audit(entry) {
      const { error } = await supabaseAdmin()
        .from('audit_logs')
        .insert({ ...entry, actor_role: 'admin', target_table: 'profiles' });
      check(error, 'audit');
    },
  };
}
