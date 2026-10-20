// POST /api/auth/bootstrap
// Body: { role: "candidate" | "employer", displayName?: string }
// Header: Authorization: Bearer <Firebase ID token>
// Sets custom claims (role=authenticated, app_role) and creates the profile.
import { bootstrapAccount } from '../_lib/accounts.js';
import { liveAccountDeps } from '../_lib/account-deps.js';
import { bearerToken, handle, json, preflight, readJson } from '../_lib/http.js';
import { LIMITS, enforceLimit } from '../_lib/rate-limit.js';

export const OPTIONS = preflight;

export const POST = handle(async (request) => {
  await enforceLimit(request, LIMITS.bootstrap);
  const token = bearerToken(request);
  const body = await readJson<{ role?: unknown; displayName?: unknown }>(request);
  const result = await bootstrapAccount(liveAccountDeps(), token, body);
  return json(request, 200, result);
});
