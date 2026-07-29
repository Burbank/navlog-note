/**
 * QUICKLOG v3.1 — offline-first shell.
 * Navigations serve cache immediately (avoids iOS “offline” interstitial).
 * Other same-origin GETs: network, then cache. Hold Clear 4s flushes caches.
 */
(function () {
  'use strict';

  var CACHE = 'navlog-note-v3.1.0';
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
          if (request.mode === 'navigate') return cache.match('./index.html');
          return Response.error();
        });
      });
    });
  }

  function putInCache(request, response) {
    if (!response || !response.ok) return;
    var copy = response.clone();
    caches.open(CACHE).then(function (cache) {
      cache.put(request, copy);
    }).catch(function () {});
  }

  function sameOriginClient(event) {
    if (!event.source || !event.source.url) return true;
    try {
      return new URL(event.source.url).origin === self.location.origin;
    } catch (e) {
      return false;
    }
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
        return Promise.all(keys.map(function (key) {
          if (key !== CACHE) return caches.delete(key);
        })).then(function () {
          return self.clients.claim();
        });
      })
    );
  });

  self.addEventListener('message', function (event) {
    if (!sameOriginClient(event)) return;
    if (event.data === 'SKIP_WAITING') self.skipWaiting();
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
    try { url = new URL(request.url); } catch (e) { return; }
    if (url.origin !== self.location.origin) return;

    /* Document loads: cache first so iPad PWA never waits on a failed network. */
    if (request.mode === 'navigate') {
      event.respondWith(
        caches.open(CACHE).then(function (cache) {
          return cache.match('./index.html').then(function (cached) {
            var network = fetch(request).then(function (response) {
              if (response && response.ok) {
                cache.put('./index.html', response.clone());
                cache.put(request, response.clone());
              }
              return response;
            }).catch(function () { return null; });
            if (cached) {
              network.catch(function () {});
              return cached;
            }
            return network.then(function (response) {
              return response || cacheFallback(request);
            });
          });
        })
      );
      return;
    }

    event.respondWith(
      fetch(request).then(function (response) {
        putInCache(request, response);
        return response;
      }).catch(function () {
        return cacheFallback(request);
      })
    );
  });
})();
