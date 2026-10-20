// Delivers new notifications by push and email. The database decides what
// may be sent (claim_notification_deliveries applies preferences and
// suspension and claims each row once); this only sends and records.
import {
  pushMessage,
  renderEmail,
  type EmailContent,
  type OutgoingNotification,
  type Role,
} from './messages.js';

export interface Pending extends OutgoingNotification {
  userId: string;
  email: string;
  sendPush: boolean;
  sendEmail: boolean;
  tokens: string[];
}

export interface PushResult {
  sent: number;
  failed: number;
  /** Tokens FCM says are gone (app removed, permission revoked). */
  invalidTokens: string[];
  error: string | null;
}

export interface Delivery {
  notificationId: string;
  channel: 'push' | 'email';
  status: 'sent' | 'failed' | 'skipped';
  detail: string | null;
}

export interface DispatchDeps {
  claim(max: number): Promise<Pending[]>;
  sendPush(tokens: string[], message: ReturnType<typeof pushMessage>): Promise<PushResult>;
  sendEmail(to: { email: string; name: string }, content: EmailContent): Promise<void>;
  /** Only verified addresses get email (never mail a mistyped stranger). */
  emailVerified(userId: string): Promise<boolean>;
  dropTokens(tokens: string[]): Promise<void>;
  record(rows: Delivery[]): Promise<void>;
  /** Releases connections (SMTP pool) once the batch is done. */
  close?(): void;
}

export interface DispatchConfig {
  origin: string;
  pushEnabled: boolean;
  emailEnabled: boolean;
}

export interface DispatchSummary {
  claimed: number;
  push: Record<Delivery['status'], number>;
  email: Record<Delivery['status'], number>;
}

function message(e: unknown): string {
  return (e instanceof Error ? e.message : String(e)).slice(0, 300);
}

async function deliverPush(deps: DispatchDeps, config: DispatchConfig, n: Pending): Promise<Delivery> {
  const row = (status: Delivery['status'], detail: string | null): Delivery => ({
    notificationId: n.id,
    channel: 'push',
    status,
    detail,
  });
  if (!n.sendPush) return row('skipped', 'turned off');
  if (!config.pushEnabled) return row('skipped', 'push not configured');
  if (n.tokens.length === 0) return row('skipped', 'no devices');
  try {
    const result = await deps.sendPush(n.tokens, pushMessage(n, config.origin));
    if (result.invalidTokens.length) await deps.dropTokens(result.invalidTokens);
    if (result.sent > 0) return row('sent', `${result.sent} of ${n.tokens.length} devices`);
    return row('failed', result.error ?? 'no device accepted it');
  } catch (e) {
    return row('failed', message(e));
  }
}

async function deliverEmail(deps: DispatchDeps, config: DispatchConfig, n: Pending): Promise<Delivery> {
  const row = (status: Delivery['status'], detail: string | null): Delivery => ({
    notificationId: n.id,
    channel: 'email',
    status,
    detail,
  });
  if (!n.sendEmail) return row('skipped', 'turned off');
  if (!config.emailEnabled) return row('skipped', 'email not configured');
  try {
    if (!(await deps.emailVerified(n.userId))) return row('skipped', 'email not verified');
    await deps.sendEmail({ email: n.email, name: n.displayName }, renderEmail(n, config.origin));
    return row('sent', null);
  } catch (e) {
    return row('failed', message(e));
  }
}

export async function dispatch(
  deps: DispatchDeps,
  config: DispatchConfig,
  max = 50,
): Promise<DispatchSummary> {
  const pending = await deps.claim(max);
  let rows: Delivery[];
  try {
    rows = (
      await Promise.all(
        pending.map((n) => Promise.all([deliverPush(deps, config, n), deliverEmail(deps, config, n)])),
      )
    ).flat();
  } finally {
    deps.close?.();
  }
  if (rows.length) await deps.record(rows);
  const count = (channel: Delivery['channel']) => {
    const out = { sent: 0, failed: 0, skipped: 0 };
    for (const r of rows) if (r.channel === channel) out[r.status]++;
    return out;
  };
  return { claimed: pending.length, push: count('push'), email: count('email') };
}

/** Maps a row of claim_notification_deliveries(). */
export function pendingFromRow(r: Record<string, unknown>): Pending {
  const role = r.role === 'employer' || r.role === 'admin' ? r.role : 'candidate';
  return {
    id: String(r.id),
    userId: String(r.user_id),
    type: String(r.type),
    title: String(r.title),
    body: typeof r.body === 'string' ? r.body : null,
    data: r.data && typeof r.data === 'object' ? (r.data as Record<string, unknown>) : {},
    role: role as Role,
    displayName: String(r.display_name ?? ''),
    email: String(r.email),
    sendPush: r.send_push === true,
    sendEmail: r.send_email === true,
    tokens: Array.isArray(r.tokens) ? r.tokens.filter((t): t is string => typeof t === 'string') : [],
  };
}
