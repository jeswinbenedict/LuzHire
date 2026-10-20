import { HttpError } from './http.js';

/** Vercel Cron sends "Authorization: Bearer $CRON_SECRET"; refuse anyone else. */
export function authorizeCron(request: Request, secret: string | undefined): void {
  if (!secret || secret.length < 16) {
    throw new HttpError(503, 'not_configured', 'Server is missing CRON_SECRET.');
  }
  if (request.headers.get('authorization') !== `Bearer ${secret}`) {
    throw new HttpError(401, 'unauthorized', 'Not allowed.');
  }
}
