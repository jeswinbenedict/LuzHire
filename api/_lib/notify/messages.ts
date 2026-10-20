// What a notification looks like outside the app: the deep link, the push
// payload and the transactional email (HTML + plain text). Pure functions,
// unit-tested in tests/api/notify.test.ts.
import { escapeHtml } from '../seo.js';

export type Role = 'candidate' | 'employer' | 'admin';

export interface OutgoingNotification {
  id: string;
  type: string;
  title: string;
  body: string | null;
  data: Record<string, unknown>;
  role: Role;
  displayName: string;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function id(data: Record<string, unknown>, key: string): string | null {
  const v = data[key];
  return typeof v === 'string' && UUID.test(v) ? v : null;
}

/**
 * The app path a notification opens. Mirrors notificationLink() in
 * app/lib/features/notifications/domain/notification_links.dart.
 */
export function linkFor(n: Pick<OutgoingNotification, 'type' | 'data' | 'role'>): string {
  const application = id(n.data, 'application_id');
  const job = id(n.data, 'job_id');
  if (n.role === 'candidate') {
    if (application) return `/me/applications/${application}`;
    if (n.type.startsWith('interview.')) return '/me/interviews';
    return '/me/notifications';
  }
  if (n.role === 'employer') {
    if (n.type === 'application.new' || n.type === 'application.withdrawn') {
      return job ? `/employer/pipeline?job=${job}` : '/employer/pipeline';
    }
    if (n.type.startsWith('offer.')) return '/employer/pipeline';
    if (n.type.startsWith('job.')) return job ? `/employer/jobs/${job}` : '/employer/jobs';
    if (n.type.startsWith('company.')) return '/employer/company';
    return '/employer';
  }
  return '/admin';
}

export const SETTINGS_PATH = '/account/notifications';

function actionLabel(n: Pick<OutgoingNotification, 'type' | 'role'>): string {
  if (n.type === 'application.new') return 'Review the application';
  if (n.type.startsWith('application.')) return 'View your application';
  if (n.type.startsWith('interview.')) return 'See the interview';
  if (n.type === 'offer.issued') return 'Review the offer';
  if (n.type.startsWith('offer.')) return 'Open the pipeline';
  if (n.type === 'company.invite') return 'Open the invitation';
  if (n.type.startsWith('job.')) return 'Open the job';
  if (n.type.startsWith('company.')) return 'Open your company';
  return 'Open LuzHire';
}

/** FCM message (without the target tokens). */
export function pushMessage(n: OutgoingNotification, origin: string) {
  const link = origin + linkFor(n);
  const body = n.body ?? '';
  return {
    // Web: data only. Our service worker (app/web/firebase-messaging-sw.js)
    // shows it, so a focused tab is not interrupted twice.
    data: { id: n.id, type: n.type, title: n.title, body, link },
    webpush: {
      headers: { Urgency: 'high', TTL: '86400' },
      fcmOptions: { link },
    },
    android: {
      priority: 'high' as const,
      ttl: 86_400_000,
      notification: { title: n.title, body, channelId: 'luzhire_updates', tag: n.id },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: { aps: { alert: { title: n.title, body }, sound: 'default' } },
    },
  };
}

export interface EmailContent {
  subject: string;
  html: string;
  text: string;
}

function firstName(name: string): string {
  return name.trim().split(/\s+/)[0] || 'there';
}

// Brand colours from DESIGN.md (light theme). Text on orange is ink, never white.
const C = {
  page: '#EEECE7',
  card: '#FFFFFF',
  ink: '#14110F',
  inkMuted: '#3D4148',
  muted: '#5A5F66',
  orange: '#FE8022',
  link: '#9A3F0A',
  hairline: '#DAD6CE',
};
const FONT = "'Segoe UI', Roboto, Helvetica, Arial, sans-serif";

/**
 * Transactional email: table layout with inline styles so it renders the
 * same in Gmail, Outlook (Word engine) and Apple Mail; no images, so
 * nothing breaks when images are blocked.
 */
export function renderEmail(n: OutgoingNotification, origin: string): EmailContent {
  const link = origin + linkFor(n);
  const settings = origin + SETTINGS_PATH;
  const action = actionLabel(n);
  const hello = `Hi ${firstName(n.displayName)},`;
  const body = n.body ?? '';
  const e = escapeHtml;

  const html = `<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<title>${e(n.title)}</title>
<!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
</head>
<body style="margin:0;padding:0;background-color:${C.page};">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">${e(body)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${C.page}" style="background-color:${C.page};">
<tr><td align="center" style="padding:32px 16px;">
<!--[if mso]><table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0"><tr><td><![endif]-->
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;">
<tr><td style="padding:0 8px 20px 8px;font-family:${FONT};font-size:22px;line-height:28px;font-weight:700;color:${C.ink};">LuzHire<span style="color:${C.orange};">&#8226;</span></td></tr>
<tr><td bgcolor="${C.card}" style="background-color:${C.card};border:1px solid ${C.hairline};border-radius:16px;padding:32px;">
<p style="margin:0 0 16px 0;font-family:${FONT};font-size:16px;line-height:24px;color:${C.inkMuted};">${e(hello)}</p>
<h1 style="margin:0 0 12px 0;font-family:${FONT};font-size:24px;line-height:32px;font-weight:700;color:${C.ink};">${e(n.title)}</h1>
${body ? `<p style="margin:0 0 28px 0;font-family:${FONT};font-size:16px;line-height:24px;color:${C.ink};">${e(body)}</p>` : ''}
<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
<td align="center" bgcolor="${C.orange}" style="background-color:${C.orange};border-radius:999px;padding:14px 28px;">
<a href="${e(link)}" target="_blank" style="font-family:${FONT};font-size:16px;line-height:20px;font-weight:700;color:${C.ink};text-decoration:none;display:inline-block;">${e(action)}</a>
</td></tr></table>
<p style="margin:28px 0 0 0;font-family:${FONT};font-size:13px;line-height:20px;color:${C.muted};">Button not working? Open this link:<br><a href="${e(link)}" target="_blank" style="color:${C.link};word-break:break-all;">${e(link)}</a></p>
</td></tr>
<tr><td style="padding:20px 8px 0 8px;font-family:${FONT};font-size:12px;line-height:18px;color:${C.muted};">
You received this email because you have a LuzHire account. <a href="${e(settings)}" target="_blank" style="color:${C.link};">Choose which emails you get</a>.<br>LuzHire job portal
</td></tr>
</table>
<!--[if mso]></td></tr></table><![endif]-->
</td></tr>
</table>
</body>
</html>`;

  const text = [
    hello,
    '',
    n.title,
    body,
    '',
    `${action}: ${link}`,
    '',
    '--',
    `Choose which emails you get: ${settings}`,
  ]
    .filter((line, i, all) => !(line === '' && all[i - 1] === ''))
    .join('\n');

  return { subject: n.title, html, text };
}
