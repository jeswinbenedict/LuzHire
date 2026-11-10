// Wiring of AccountDeps: the identity provider (Firebase Admin, or the
// offline demo's local store) + Supabase service role.
import type { AccountDeps } from './accounts.js';
import { HttpError } from './http.js';
import { identity, supabaseAdmin } from './services.js';

function check(error: { message: string } | null, what: string): void {
  if (error) {
    console.error(`${what} failed:`, error.message);
    throw new HttpError(502, 'database_error', 'Could not save your account. Try again.');
  }
}

export function liveAccountDeps(): AccountDeps {
  return {
    verifyIdToken: (token) => identity().verifyIdToken(token, true),
    setClaims: (uid, claims) => identity().setCustomUserClaims(uid, claims),
    revokeSessions: (uid) => identity().revokeRefreshTokens(uid),
    async setDisabled(uid, disabled) {
      await identity().updateUser(uid, { disabled });
    },
    async setEmailVerified(uid) {
      await identity().updateUser(uid, { emailVerified: true });
    },
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
    async updateProfileStatus(uid, status) {
      const { error } = await supabaseAdmin()
        .from('profiles')
        .update({ account_status: status })
        .eq('id', uid);
      check(error, 'updateProfileStatus');
    },
    async audit(entry) {
      const { error } = await supabaseAdmin()
        .from('audit_logs')
        .insert({ ...entry, actor_role: 'admin', target_table: 'profiles' });
      check(error, 'audit');
    },
  };
}
