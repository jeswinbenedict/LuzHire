// LuzHire web push. The Firebase SDK in the page registers this worker
// (scope /firebase-cloud-messaging-push-scope) and subscribes it to FCM.
// /api/notify/dispatch sends data-only messages: {id, type, title, body, link}.
// No Firebase code or config is needed here.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

function readPayload(event) {
  try {
    const msg = event.data ? event.data.json() : {};
    const data = msg.data || msg;
    const fallback = msg.notification || {};
    return {
      id: data.id || '',
      title: data.title || fallback.title || 'LuzHire',
      body: data.body || fallback.body || '',
      link: data.link || (msg.fcmOptions && msg.fcmOptions.link) || '/',
    };
  } catch (_) {
    return { id: '', title: 'LuzHire', body: '', link: '/' };
  }
}

// Only links back into this site are opened.
function safeLink(link) {
  try {
    const url = new URL(link, self.location.origin);
    return url.origin === self.location.origin ? url.href : self.location.origin + '/';
  } catch (_) {
    return self.location.origin + '/';
  }
}

self.addEventListener('push', (event) => {
  const p = readPayload(event);
  event.waitUntil(
    self.registration.showNotification(p.title, {
      body: p.body,
      tag: p.id || undefined,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-maskable-192.png',
      data: { link: safeLink(p.link) },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const link = (event.notification.data && event.notification.data.link) || self.location.origin + '/';
  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of windows) {
        if (new URL(client.url).origin === self.location.origin && 'focus' in client) {
          await client.focus();
          if ('navigate' in client) {
            try {
              await client.navigate(link);
              return;
            } catch (_) {
              // Not controlled by this worker: open a new tab instead.
            }
          }
        }
      }
      await self.clients.openWindow(link);
    })(),
  );
});
