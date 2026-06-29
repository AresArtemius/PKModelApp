importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');
importScripts('firebase-web-config.js');

const config = self.firebaseWebConfig || {};

if (config.apiKey && config.projectId && config.messagingSenderId && config.appId) {
  firebase.initializeApp(config);

  const messaging = firebase.messaging();
  messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification || {};
    const data = payload.data || {};
    const title = notification.title || data.title || 'PK Management';
    const body = notification.body || data.body || '';
    const route = data.route || '/chats';

    self.registration.showNotification(title, {
      body,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { route },
    });
  });
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const route = event.notification?.data?.route || '/chats';
  const targetUrl = new URL(route.replace(/^\//, '#/'), self.location.origin);
  targetUrl.pathname = self.location.pathname.replace(
    /firebase-messaging-sw\.js$/,
    '',
  );

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if ('focus' in client) {
            client.navigate(targetUrl.href);
            return client.focus();
          }
        }

        if (clients.openWindow) {
          return clients.openWindow(targetUrl.href);
        }

        return undefined;
      }),
  );
});
