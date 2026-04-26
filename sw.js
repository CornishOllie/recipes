// Recipes PWA service worker.
// - Pre-caches the app shell on install so the kitchen still works with no signal.
// - Network-first for navigations / index.html so deploys flow through quickly.
// - Cache-first for static assets (manifest, icons, sw itself).
// Bump CACHE_VERSION whenever the asset list changes to force a clean cache.
const CACHE_VERSION = "v3-2026-04-26";
const CACHE = `recipes-${CACHE_VERSION}`;
const SHELL = [
  "./",
  "./index.html",
  "./manifest.json",
  "./icon.svg",
  "./icon-maskable.svg",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  const isNavigation =
    req.mode === "navigate" ||
    url.pathname.endsWith("/") ||
    url.pathname.endsWith("/index.html");

  if (isNavigation) {
    // Network-first so updates ship through; fall back to cached shell offline.
    event.respondWith(
      fetch(req)
        .then((resp) => {
          const clone = resp.clone();
          caches.open(CACHE).then((c) => c.put(req, clone));
          return resp;
        })
        .catch(() =>
          caches.match(req).then((c) => c || caches.match("./index.html"))
        )
    );
    return;
  }

  // Static assets: cache-first, network-fill.
  event.respondWith(
    caches.match(req).then(
      (cached) =>
        cached ||
        fetch(req).then((resp) => {
          if (resp && resp.ok) {
            const clone = resp.clone();
            caches.open(CACHE).then((c) => c.put(req, clone));
          }
          return resp;
        })
    )
  );
});
