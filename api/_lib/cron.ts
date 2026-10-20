import { HttpError } from './http.js';

/**
 * Server-to-server calls (Vercel Cron, the Supabase webhook) send
 * "Authorization: Bearer <secret>"; refuse anyone else.
 */
export function authorizeCron(
  request: Request,
  secret: string | undefined,
  name = 'CRON_SECRET',
): void {
  if (!secret || secret.length < 16) {
    throw new HttpError(503, 'not_configured', `Server is missing ${name}.`);
  }
  if (request.headers.get('authorization') !== `Bearer ${secret}`) {
    throw new HttpError(401, 'unauthorized', 'Not allowed.');
  }
}
