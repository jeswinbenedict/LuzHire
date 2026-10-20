import { describe, expect, it } from 'vitest';
import { authorizeCron } from '../../api/_lib/cron.js';
import { HttpError } from '../../api/_lib/http.js';
import {
  dispatch,
  pendingFromRow,
  type Delivery,
  type DispatchDeps,
  type Pending,
  type PushResult,
} from '../../api/_lib/notify/dispatch.js';
import { dispatchConfig } from '../../api/_lib/notify/live.js';
import { linkFor, pushMessage, renderEmail, type OutgoingNotification } from '../../api/_lib/notify/messages.js';

const origin = 'https://luzhire.vercel.app';
const APP = '11111111-2222-4333-8444-555555555555';
const JOB = '66666666-7777-4888-9999-000000000000';

function note(over: Partial<OutgoingNotification> = {}): OutgoingNotification {
  return {
    id: 'n-1',
    type: 'application.stage',
    title: 'Application update',
    body: 'Your application for Flutter Developer at Nimbus moved to Interview.',
    data: { application_id: APP, job_id: JOB },
    role: 'candidate',
    displayName: 'Asha Rao',
    ...over,
  };
}

describe('linkFor', () => {
  it('opens the right screen for each role', () => {
    expect(linkFor(note())).toBe(`/me/applications/${APP}`);
    expect(linkFor(note({ type: 'interview.scheduled', data: {} }))).toBe('/me/interviews');
    expect(linkFor(note({ type: 'system.test', data: {} }))).toBe('/me/notifications');
    expect(linkFor(note({ role: 'employer', type: 'application.new' }))).toBe(`/employer/pipeline?job=${JOB}`);
    expect(linkFor(note({ role: 'employer', type: 'job.rejected', data: { job_id: JOB } }))).toBe(`/employer/jobs/${JOB}`);
    expect(linkFor(note({ role: 'employer', type: 'company.invite', data: {} }))).toBe('/employer/company');
    expect(linkFor(note({ role: 'admin', type: 'report.resolved' }))).toBe('/admin');
  });

  it('never builds a link from anything but a UUID', () => {
    expect(linkFor(note({ data: { application_id: '../../evil' } }))).toBe('/me/notifications');
  });
});

describe('pushMessage', () => {
  it('is data-only on the web and a system notification on phones', () => {
    const m = pushMessage(note(), origin);
    expect(m).not.toHaveProperty('notification');
    expect(m.data).toEqual({
      id: 'n-1',
      type: 'application.stage',
      title: 'Application update',
      body: 'Your application for Flutter Developer at Nimbus moved to Interview.',
      link: `${origin}/me/applications/${APP}`,
    });
    expect(m.android.notification).toMatchObject({ title: 'Application update', channelId: 'luzhire_updates' });
    expect(m.apns.payload.aps.alert.title).toBe('Application update');
  });
});

describe('renderEmail', () => {
  it('builds an HTML + text email with the action and a settings link', () => {
    const mail = renderEmail(note(), origin);
    expect(mail.subject).toBe('Application update');
    expect(mail.html).toContain('Hi Asha,');
    expect(mail.html).toContain(`href="${origin}/me/applications/${APP}"`);
    expect(mail.html).toContain('View your application');
    expect(mail.html).toContain(`href="${origin}/account/notifications"`);
    expect(mail.html).toContain('<!--[if mso]>'); // Outlook width fix
    expect(mail.text).toBe(
      [
        'Hi Asha,',
        '',
        'Application update',
        'Your application for Flutter Developer at Nimbus moved to Interview.',
        '',
        `View your application: ${origin}/me/applications/${APP}`,
        '',
        '--',
        `Choose which emails you get: ${origin}/account/notifications`,
      ].join('\n'),
    );
  });

  it('escapes names and text from users', () => {
    const mail = renderEmail(
      note({ displayName: '<b>Eve</b>', title: 'Offer <script>x()</script>', body: '"><img src=x onerror=1>' }),
      origin,
    );
    expect(mail.html).not.toContain('<script>x()');
    expect(mail.html).not.toContain('<img src=x');
    expect(mail.html).not.toContain('<b>Eve');
  });
});

function pending(over: Partial<Pending> = {}): Pending {
  return {
    ...note(),
    userId: 'u-1',
    email: 'asha@example.com',
    sendPush: true,
    sendEmail: true,
    tokens: ['token-a', 'token-b'],
    ...over,
  };
}

function fakeDeps(items: Pending[], opts: { push?: PushResult; emailFails?: boolean; verified?: boolean } = {}) {
  const recorded: Delivery[] = [];
  const dropped: string[] = [];
  const emails: string[] = [];
  const pushes: string[][] = [];
  let closed = false;
  const deps: DispatchDeps = {
    claim: async () => items,
    sendPush: async (tokens) => {
      pushes.push(tokens);
      return opts.push ?? { sent: tokens.length, failed: 0, invalidTokens: [], error: null };
    },
    sendEmail: async (to) => {
      if (opts.emailFails) throw new Error('535 Username and Password not accepted');
      emails.push(to.email);
    },
    emailVerified: async () => opts.verified ?? true,
    dropTokens: async (t) => {
      dropped.push(...t);
    },
    record: async (rows) => {
      recorded.push(...rows);
    },
    close: () => {
      closed = true;
    },
  };
  return { deps, recorded, dropped, emails, pushes, closed: () => closed };
}

const on = { origin, pushEnabled: true, emailEnabled: true };

describe('dispatch', () => {
  it('sends push and email and records both', async () => {
    const f = fakeDeps([pending()]);
    const summary = await dispatch(f.deps, on);
    expect(summary).toEqual({
      claimed: 1,
      push: { sent: 1, failed: 0, skipped: 0 },
      email: { sent: 1, failed: 0, skipped: 0 },
    });
    expect(f.pushes).toEqual([['token-a', 'token-b']]);
    expect(f.emails).toEqual(['asha@example.com']);
    expect(f.recorded).toContainEqual({ notificationId: 'n-1', channel: 'push', status: 'sent', detail: '2 of 2 devices' });
    expect(f.closed()).toBe(true);
  });

  it('respects preferences, missing devices and missing configuration', async () => {
    const f = fakeDeps([
      pending({ id: 'off', sendPush: false, sendEmail: false }),
      pending({ id: 'nodev', tokens: [] }),
    ]);
    await dispatch(f.deps, { origin, pushEnabled: true, emailEnabled: false });
    const detail = (id: string, channel: string) =>
      f.recorded.find((r) => r.notificationId === id && r.channel === channel)?.detail;
    expect(detail('off', 'push')).toBe('turned off');
    expect(detail('off', 'email')).toBe('turned off');
    expect(detail('nodev', 'push')).toBe('no devices');
    expect(detail('nodev', 'email')).toBe('email not configured');
    expect(f.pushes).toHaveLength(0);
    expect(f.emails).toHaveLength(0);
  });

  it('drops tokens FCM no longer knows', async () => {
    const f = fakeDeps([pending()], {
      push: { sent: 1, failed: 1, invalidTokens: ['token-b'], error: 'messaging/registration-token-not-registered' },
    });
    await dispatch(f.deps, on);
    expect(f.dropped).toEqual(['token-b']);
  });

  it('never emails an unverified address', async () => {
    const f = fakeDeps([pending()], { verified: false });
    const summary = await dispatch(f.deps, on);
    expect(f.emails).toHaveLength(0);
    expect(summary.email.skipped).toBe(1);
  });

  it('a failing mailbox is recorded and does not stop push', async () => {
    const f = fakeDeps([pending()], { emailFails: true });
    const summary = await dispatch(f.deps, on);
    expect(summary.push.sent).toBe(1);
    expect(f.recorded.find((r) => r.channel === 'email')).toMatchObject({
      status: 'failed',
      detail: '535 Username and Password not accepted',
    });
  });

  it('does nothing when nothing is pending', async () => {
    const f = fakeDeps([]);
    expect((await dispatch(f.deps, on)).claimed).toBe(0);
    expect(f.recorded).toHaveLength(0);
  });
});

describe('wiring', () => {
  it('maps database rows', () => {
    expect(
      pendingFromRow({
        id: 'n', user_id: 'u', type: 'offer.issued', title: 'Offer', body: null, data: { offer_id: 'x' },
        role: 'employer', display_name: 'Nimbus', email: 'a@b.c', send_push: true, send_email: false,
        tokens: ['t', 5],
      }),
    ).toMatchObject({ role: 'employer', body: null, sendPush: true, sendEmail: false, tokens: ['t'] });
  });

  it('turns channels on only when configured', () => {
    expect(dispatchConfig(origin, {})).toEqual({ origin, pushEnabled: false, emailEnabled: false });
    expect(
      dispatchConfig(origin, { FIREBASE_SERVICE_ACCOUNT: '{}', SMTP_USER: 'a@gmail.com', SMTP_PASSWORD: 'x' }),
    ).toEqual({ origin, pushEnabled: true, emailEnabled: true });
  });

  it('the webhook needs NOTIFY_SECRET', () => {
    const req = new Request('https://x/api/notify/dispatch', { method: 'POST' });
    try {
      authorizeCron(req, undefined, 'NOTIFY_SECRET');
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(HttpError);
      expect((e as HttpError).message).toBe('Server is missing NOTIFY_SECRET.');
    }
  });
});
