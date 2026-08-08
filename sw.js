/* QUICKLOG service worker — cache-only shell (offline-first).
 * Network is used only for explicit ?updateCheck=1 (long-press Clear /
 * PWA cold-start stamp check). Never speculative fetch on resume —
 * iOS treats that as “Turn Off Airplane Mode…”. */
const CACHE = "navlog-note-v4.6.0";

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

  /* Explicit online probe only (page sets this during allowed windows). */
  if (url.searchParams.has("updateCheck")) {
    event.respondWith(
      fetch(request, { cache: "reload" }).catch(
        () =>
          new Response("", {
            status: 503,
            headers: { "Content-Type": "text/plain; charset=utf-8" }
          })
      )
    );
    return;
  }

  const cacheKey = request.mode === "navigate" ? "./index.html" : request;

  event.respondWith(
    caches.match(cacheKey).then((cached) => {
      if (cached) return cached;
      /* Cache miss: never hit the network — avoids Airplane Mode dialogs on
       * app-switch resume when WebKit re-requests a resource. */
      return caches.match("./index.html").then(
        (shell) =>
          shell ||
          new Response("QUICKLOG offline — open once while online to cache.", {
            status: 503,
            headers: { "Content-Type": "text/plain; charset=utf-8" }
          })
      );
    })
  );
});
