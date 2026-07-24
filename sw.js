/**
 * NAVLOG NOTE — caches the app shell for offline use (same pattern as KLYear).
 * Online: network-first so updates are not stuck behind a stale shell.
 */
(function () {
  'use strict';

  var CACHE = 'navlog-note-v1.0.6';
  var PRECACHE = [
    './',
    './index.html',
    './manifest.webmanifest',
    './favicon.png',
    './favicon-32.png',
    './apple-touch-icon.png'
  ];

  function cacheFallback(request) {
    return caches.open(CACHE).then(function (cache) {
      return cache.match(request).then(function (cached) {
        if (cached) return cached;
        return cache.match(request, { ignoreSearch: true }).then(function (byPath) {
          if (byPath) return byPath;
          if (request.mode === 'navigate') {
            return cache.match('./index.html');
          }
          return Response.error();
        });
      });
    });
  }

  self.addEventListener('install', function (event) {
    event.waitUntil(
      caches.open(CACHE).then(function (cache) {
        return cache.addAll(PRECACHE);
      }).then(function () {
        return self.skipWaiting();
      })
    );
  });

  self.addEventListener('activate', function (event) {
    event.waitUntil(
      caches.keys().then(function (keys) {
        var hadStale = keys.some(function (key) { return key !== CACHE; });
        return Promise.all(keys.map(function (key) {
          if (key !== CACHE) return caches.delete(key);
        })).then(function () {
          return self.clients.claim();
        }).then(function () {
          if (!hadStale) return;
          /* Force open clients onto the new shell after a version bump (Home Screen) */
          return self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
            return Promise.all(clientList.map(function (client) {
              if (!client.navigate) return;
              try {
                var next = new URL(client.url);
                next.searchParams.set('_sw', String(Date.now()));
                return client.navigate(next.pathname + next.search + next.hash);
              } catch (e) {
                return client.navigate(client.url);
              }
            }));
          });
        });
      })
    );
  });

  self.addEventListener('message', function (event) {
    if (event.data === 'SKIP_WAITING') {
      self.skipWaiting();
    }
    if (event.data === 'CLEAR_CACHES') {
      event.waitUntil(
        caches.keys().then(function (keys) {
          return Promise.all(keys.map(function (key) { return caches.delete(key); }));
        })
      );
    }
  });

  self.addEventListener('fetch', function (event) {
    var request = event.request;
    if (request.method !== 'GET') return;

    var url;
    try {
      url = new URL(request.url);
    } catch (e) {
      return;
    }

    if (url.origin !== self.location.origin) return;

    event.respondWith(
      fetch(request).then(function (response) {
        if (response && response.ok) {
          var copy = response.clone();
          caches.open(CACHE).then(function (cache) {
            cache.put(request, copy);
          }).catch(function () {});
        }
        return response;
      }).catch(function () {
        return cacheFallback(request);
      })
    );
  });
})();
