// POST /api/admin/users/:id/role   Body: { role: "candidate" | "employer" | "admin" }
// Admin only. Updates Firebase claims + profile, signs the user out, audits.
import { changeRole } from '../../../_lib/accounts.js';
import { liveAccountDeps } from '../../../_lib/account-deps.js';
import { bearerToken, handle, json, preflight, readJson } from '../../../_lib/http.js';
import { LIMITS, enforceLimit } from '../../../_lib/rate-limit.js';

export const OPTIONS = preflight;

export const POST = handle(async (request) => {
  await enforceLimit(request, LIMITS.admin);
  // /api/admin/users/<id>/role
  const parts = new URL(request.url).pathname.split('/');
  const targetUid = decodeURIComponent(parts[parts.length - 2] ?? '');
  const body = await readJson<{ role?: unknown }>(request);
  const result = await changeRole(liveAccountDeps(), bearerToken(request), targetUid, body);
  return json(request, 200, result);
});
