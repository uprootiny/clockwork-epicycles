/*! coi-serviceworker v0.1.7 - Guido Zuidhof, licensed under MIT */
// Minimal service worker that enables SharedArrayBuffer on GitHub Pages
// by adding Cross-Origin-Opener-Policy and Cross-Origin-Embedder-Policy headers.

if (typeof window === 'undefined') {
  // Service worker context
  self.addEventListener("install", () => self.skipWaiting());
  self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
  self.addEventListener("fetch", (e) => {
    if (e.request.cache === "only-if-cached" && e.request.mode !== "same-origin") return;
    e.respondWith(
      fetch(e.request).then((r) => {
        if (r.status === 0) return r;
        const headers = new Headers(r.headers);
        headers.set("Cross-Origin-Embedder-Policy", "credentialless");
        headers.set("Cross-Origin-Opener-Policy", "same-origin");
        return new Response(r.body, { status: r.status, statusText: r.statusText, headers });
      }).catch((err) => console.error(err))
    );
  });
} else {
  // Window context — register the service worker
  if (window.crossOriginIsolated === false) {
    const r = window.navigator.serviceWorker.register(window.document.currentScript.src, { scope: "/" });
    r.then((reg) => {
      if (reg.active && !navigator.serviceWorker.controller) {
        window.location.reload();
      }
    });
  }
}
