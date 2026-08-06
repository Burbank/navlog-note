/* QUICKLOG service worker — cache-first shell (offline-first, no speculative fetch). */
const CACHE = "navlog-note-v4.1.0";

const ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
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

/** Fetch once; never throws to the page. Used only on cache miss. */
function networkFetch(request) {
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

  /*
   * Pure cache-first: never background-revalidate.
   * iOS treats any fetch while Airplane Mode / flaky link as
   * “Turn Off Airplane Mode or Use Wi-Fi to Access Data”.
   * navigator.onLine is unreliable on resume / radio changes.
   * Updates are explicit (long-press Clear) from the page.
   */
  const cacheKey = request.mode === "navigate" ? "./index.html" : request;

  event.respondWith(
    caches.match(cacheKey).then((cached) => {
      if (cached) return cached;

      return networkFetch(request).then(
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
