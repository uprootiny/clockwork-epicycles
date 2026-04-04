/*! coi-serviceworker — enables SharedArrayBuffer on GitHub Pages */
// Adds COOP/COEP headers via service worker for cross-origin isolation.

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
      }).catch((err) => {
        console.error("coi-sw fetch error:", err);
        return new Response("Service Worker fetch failed", { status: 500 });
      })
    );
  });
} else {
  // Window context — register the service worker
  (async function() {
    if (window.crossOriginIsolated) return;
    // Derive scope from current page location (works for GitHub Pages subpaths)
    const scriptUrl = document.currentScript && document.currentScript.src;
    if (!scriptUrl) return;
    const scopeUrl = new URL(".", scriptUrl).href;
    try {
      const reg = await navigator.serviceWorker.register(scriptUrl, { scope: scopeUrl });
      if (reg.active && !navigator.serviceWorker.controller) {
        window.location.reload();
      } else if (reg.installing || reg.waiting) {
        const sw = reg.installing || reg.waiting;
        sw.addEventListener("statechange", () => {
          if (sw.state === "activated") window.location.reload();
        });
      }
    } catch (e) {
      console.error("coi-sw registration failed:", e);
    }
  })();
}
