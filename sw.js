/* QUICKLOG service worker — MyNatTrack-style cache-first shell (offline-friendly). */
const CACHE = "navlog-note-v3.3.0";

const ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./favicon.png",
  "./favicon-32.png",
  "./apple-touch-icon.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) =>
        cache.addAll(ASSETS.map((url) => new Request(url, { cache: "reload" })))
      )
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

function sameOriginClient(event) {
  if (!event.source || !event.source.url) return true;
  try {
    return new URL(event.source.url).origin === self.location.origin;
  } catch (e) {
    return false;
  }
}

self.addEventListener("message", (event) => {
  if (!sameOriginClient(event)) return;
  if (event.data === "SKIP_WAITING") self.skipWaiting();
  if (event.data === "CLEAR_CACHES") {
    event.waitUntil(
      caches.keys().then((keys) =>
        Promise.all(keys.map((key) => caches.delete(key)))
      )
    );
  }
});

/** Fetch and refresh cache; never throws to the page. */
function networkUpdate(request) {
  return fetch(request)
    .then((response) => {
      if (response && response.status === 200 && response.type === "basic") {
        const copy = response.clone();
        caches.open(CACHE).then((cache) => cache.put(request, copy));
      }
      return response;
    })
    .catch(() => null);
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  let url;
  try {
    url = new URL(request.url);
  } catch (e) {
    return;
  }
  if (url.origin !== self.location.origin) return;

  // App shell / static: cache-first so iPad offline open never hits Safari’s
  // “offline” interstitial. When online, refresh the cache in the background.
  const cacheKey = request.mode === "navigate" ? "./index.html" : request;

  event.respondWith(
    caches.match(cacheKey).then((cached) => {
      const online =
        typeof self.navigator === "undefined" ||
        self.navigator.onLine !== false;

      if (cached) {
        if (online) {
          event.waitUntil(
            networkUpdate(request.mode === "navigate" ? request : request)
          );
        }
        return cached;
      }

      return networkUpdate(request).then(
        (response) =>
          response ||
          caches.match("./index.html").then(
            (shell) =>
              shell ||
              new Response("QUICKLOG offline — open once while online to cache.", {
                status: 503,
                headers: { "Content-Type": "text/plain; charset=utf-8" }
              })
          )
      );
    })
  );
});
