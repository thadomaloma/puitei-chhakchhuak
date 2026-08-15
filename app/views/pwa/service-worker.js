const CACHE_VERSION = "puitei-chhakchhuak-shell-v6"
const SHELL_ASSETS = ["/offline", "/offline.css", "/offline.js", "/puitei-mark.svg", "/favicon-32.png", "/icon-192.png", "/icon.png", "/icon-maskable.png", "/apple-touch-icon.png"]

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_VERSION).then(cache => cache.addAll(SHELL_ASSETS)))
  self.skipWaiting()
})

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE_VERSION).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return

  if (event.request.mode === "navigate") {
    event.respondWith(fetch(event.request).catch(() => caches.match("/offline")))
    return
  }

  const url = new URL(event.request.url)
  if (url.origin === self.location.origin && ["style", "script", "image", "font"].includes(event.request.destination)) {
    event.respondWith(
      caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
        const copy = response.clone()
        caches.open(CACHE_VERSION).then(cache => cache.put(event.request, copy))
        return response
      }))
    )
  }
})
