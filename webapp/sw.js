/* Kimi Proxy — legacy PWA service worker KILL SWITCH.
 * The Flutter app now owns this origin. This worker exists only to
 * unregister itself and wipe its caches so existing visitors are released
 * from the old cached shell and load the Flutter app on their next visit.
 * It does NOT intercept any requests.
 */
'use strict';

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    (async function () {
      if (self.caches && self.caches.keys) {
        var keys = await self.caches.keys();
        await Promise.all(
          keys.map(function (k) {
            return self.caches.delete(k);
          })
        );
      }
      if (self.registration && self.registration.unregister) {
        await self.registration.unregister();
      }
    })()
  );
  self.clients.claim();
});

// Intentionally NO fetch handler — the browser falls back to the network,
// which serves the new Flutter index.html.
