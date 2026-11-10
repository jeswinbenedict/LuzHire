// Admin actions on one user (one function, to stay within the Hobby plan):
//   POST /api/admin/users/:id/role          Body: { role: "candidate" | "employer" | "admin" }
//        Updates claims + profile, signs the user out, audits.
//   POST /api/admin/users/:id/status        Body: { status: "active" | "suspended" }
//        Updates the profile, disables sign-in, signs the user out, audits.
//   POST /api/admin/users/:id/verify-email
//        Confirms the user's email when the verification email never arrived.
import { changeRole, changeStatus, verifyEmail } from '../../../_lib/accounts.js';
import { liveAccountDeps } from '../../../_lib/account-deps.js';
import { HttpError, bearerToken, handle, json, preflight, readJson } from '../../../_lib/http.js';
import { LIMITS, enforceLimit } from '../../../_lib/rate-limit.js';

export const OPTIONS = preflight;

export const POST = handle(async (request) => {
  await enforceLimit(request, LIMITS.admin);
  const parts = new URL(request.url).pathname.split('/');
  const action = parts[parts.length - 1];
  const targetUid = decodeURIComponent(parts[parts.length - 2] ?? '');
  const token = bearerToken(request);
  switch (action) {
    case 'role':
      return json(request, 200, await changeRole(liveAccountDeps(), token, targetUid, await readJson(request)));
    case 'status':
      return json(request, 200, await changeStatus(liveAccountDeps(), token, targetUid, await readJson(request)));
    case 'verify-email':
      return json(request, 200, await verifyEmail(liveAccountDeps(), token, targetUid));
    default:
      throw new HttpError(404, 'not_found', 'Unknown action.');
  }
});
