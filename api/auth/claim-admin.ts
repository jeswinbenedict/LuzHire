// POST /api/auth/claim-admin   Header: Authorization: Bearer <Firebase ID token>
// Makes the caller an admin if their verified email is in ADMIN_EMAILS
// (comma-separated, set in Vercel by the project owner).
import { claimAdmin } from '../_lib/accounts.js';
import { liveAccountDeps } from '../_lib/account-deps.js';
import { bearerToken, handle, json, preflight } from '../_lib/http.js';
import { LIMITS, enforceLimit } from '../_lib/rate-limit.js';

export const OPTIONS = preflight;

export const POST = handle(async (request) => {
  await enforceLimit(request, LIMITS.claimAdmin);
  const allowed = (process.env.ADMIN_EMAILS ?? '').split(',');
  const result = await claimAdmin(liveAccountDeps(), bearerToken(request), allowed);
  return json(request, 200, result);
});
