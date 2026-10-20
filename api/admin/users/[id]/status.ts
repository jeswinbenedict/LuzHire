// POST /api/admin/users/:id/status   Body: { status: "active" | "suspended" }
// Admin only. Updates the profile, disables Firebase sign-in, signs the user
// out (when suspending) and audits.
import { changeStatus } from '../../../_lib/accounts.js';
import { liveAccountDeps } from '../../../_lib/account-deps.js';
import { bearerToken, handle, json, preflight, readJson } from '../../../_lib/http.js';
import { LIMITS, enforceLimit } from '../../../_lib/rate-limit.js';

export const OPTIONS = preflight;

export const POST = handle(async (request) => {
  await enforceLimit(request, LIMITS.admin);
  // /api/admin/users/<id>/status
  const parts = new URL(request.url).pathname.split('/');
  const targetUid = decodeURIComponent(parts[parts.length - 2] ?? '');
  const body = await readJson<{ status?: unknown }>(request);
  const result = await changeStatus(liveAccountDeps(), bearerToken(request), targetUid, body);
  return json(request, 200, result);
});
