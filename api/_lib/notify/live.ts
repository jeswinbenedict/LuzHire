// Production wiring of DispatchDeps: Supabase (service role), Firebase Cloud
// Messaging and SMTP email. Settings come only from Vercel env vars:
//   SMTP_USER, SMTP_PASSWORD   mailbox that sends (e.g. a Gmail address and
//                              its 16-character app password)
//   SMTP_HOST, SMTP_PORT       optional, default smtp.gmail.com:465
//   EMAIL_FROM                 optional, default "LuzHire <SMTP_USER>"
import nodemailer from 'nodemailer';
import { HttpError } from '../http.js';
import { firebaseAuth, firebaseMessaging, supabaseAdmin } from '../services.js';
import { pendingFromRow, type DispatchConfig, type DispatchDeps } from './dispatch.js';

type Env = Record<string, string | undefined>;

export function emailConfigured(env: Env = process.env): boolean {
  return Boolean(env.SMTP_USER && env.SMTP_PASSWORD);
}

export function dispatchConfig(origin: string, env: Env = process.env): DispatchConfig {
  return {
    origin,
    pushEnabled: Boolean(env.FIREBASE_SERVICE_ACCOUNT),
    emailEnabled: emailConfigured(env),
  };
}

/** FCM error codes that mean the token will never work again. */
const GONE = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function check(error: { message: string } | null, what: string): void {
  if (error) {
    console.error(`${what} failed:`, error.message);
    throw new HttpError(502, 'database_error', `${what} failed.`);
  }
}

export function liveDispatchDeps(env: Env = process.env): DispatchDeps {
  let transport: ReturnType<typeof nodemailer.createTransport> | undefined;
  const mailer = () => {
    const port = Number(env.SMTP_PORT ?? 465);
    transport ??= nodemailer.createTransport({
      host: env.SMTP_HOST || 'smtp.gmail.com',
      port,
      secure: port === 465,
      pool: true,
      maxConnections: 3,
      auth: { user: env.SMTP_USER, pass: env.SMTP_PASSWORD },
    });
    return transport;
  };
  const verified = new Map<string, Promise<boolean>>();

  return {
    async claim(max) {
      const { data, error } = await supabaseAdmin().rpc('claim_notification_deliveries', {
        max_count: max,
      });
      check(error, 'claim_notification_deliveries');
      return ((data ?? []) as Record<string, unknown>[]).map(pendingFromRow);
    },

    async sendPush(tokens, message) {
      const result = await firebaseMessaging().sendEachForMulticast({ tokens, ...message });
      const invalidTokens: string[] = [];
      let error: string | null = null;
      result.responses.forEach((r, i) => {
        if (r.success) return;
        const code = r.error?.code ?? '';
        if (GONE.has(code)) invalidTokens.push(tokens[i]!);
        error ??= `${code} ${r.error?.message ?? ''}`.trim();
      });
      return { sent: result.successCount, failed: result.failureCount, invalidTokens, error };
    },

    async sendEmail(to, content) {
      const user = env.SMTP_USER!;
      await mailer().sendMail({
        from: env.EMAIL_FROM || { name: 'LuzHire', address: user },
        to: { name: to.name, address: to.email },
        subject: content.subject,
        html: content.html,
        text: content.text,
      });
    },

    emailVerified(userId) {
      let p = verified.get(userId);
      if (!p) {
        p = firebaseAuth()
          .getUser(userId)
          .then((u) => u.emailVerified && !u.disabled)
          .catch(() => false);
        verified.set(userId, p);
      }
      return p;
    },

    async dropTokens(tokens) {
      const { error } = await supabaseAdmin().from('push_tokens').delete().in('token', tokens);
      check(error, 'drop push tokens');
    },

    async record(rows) {
      const { error } = await supabaseAdmin()
        .from('notification_deliveries')
        .insert(
          rows.map((r) => ({
            notification_id: r.notificationId,
            channel: r.channel,
            status: r.status,
            detail: r.detail,
          })),
        );
      check(error, 'record deliveries');
    },

    close() {
      transport?.close();
    },
  };
}
