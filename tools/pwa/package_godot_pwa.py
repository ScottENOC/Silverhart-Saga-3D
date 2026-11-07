#!/usr/bin/env python3
"""Add install/update/offline support to the exported Godot web build."""
from __future__ import annotations

import argparse
import json
import math
import struct
import zlib
from pathlib import Path


def png_icon(path: Path, size: int) -> None:
    """Write a small, dependency-free app icon PNG."""
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            nx = (x - size / 2) / (size / 2)
            ny = (y - size / 2) / (size / 2)
            # Deep navy background with a restrained gold compass/rising-sun mark.
            r, g, b = 15, 20, 31
            radius = math.hypot(nx, ny)
            if 0.55 < radius < 0.63:
                r, g, b = 205, 170, 103
            if abs(nx) < 0.075 and -0.38 < ny < 0.34:
                r, g, b = 231, 203, 145
            if abs(ny - (0.28 - abs(nx) * 0.42)) < 0.055 and abs(nx) < 0.34:
                r, g, b = 231, 203, 145
            if abs(ny + 0.28) < 0.045 and abs(nx) < 0.25:
                r, g, b = 205, 170, 103
            row.extend((r, g, b, 255))
        rows.append(bytes(row))
    raw = b"".join(rows)
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    header = struct.pack(">2I5B", size, size, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    root = args.directory
    index = root / "index.html"
    if not index.is_file():
        raise SystemExit(f"Godot export is missing: {index}")
    html = index.read_text(encoding="utf-8")
    version = args.version.strip()
    if not version:
        raise SystemExit("A non-empty build version is required.")

    manifest = {
        "id": "./",
        "name": "Silverhart Saga",
        "short_name": "Silverhart",
        "description": "Silverhart Saga — game prototype",
        "start_url": "./",
        "scope": "./",
        "display": "standalone",
        "background_color": "#0f141f",
        "theme_color": "#0f141f",
        "icons": [
            {"src": "./icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any"},
            {"src": "./icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any"}
        ]
    }
    (root / "manifest.webmanifest").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (root / "icon.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" rx="96" fill="#0f141f"/><circle cx="256" cy="256" r="174" fill="none" stroke="#cdaa67" stroke-width="18"/><path d="M256 110v205m-92-24 92 75 92-75M174 365h164" fill="none" stroke="#e7cb91" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/></svg>\n',
        encoding="utf-8",
    )
    png_icon(root / "icon-192.png", 192)
    png_icon(root / "icon-512.png", 512)
    png_icon(root / "apple-touch-icon.png", 180)

    sw = r"""const CACHE_NAME = "silverhart-game-__VERSION__";
const CACHE_PREFIX = "silverhart-game-";
const APP_ROOT = new URL("./", self.location.href);
self.addEventListener("install", event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll([
      new URL("./", APP_ROOT).href,
      new URL("./manifest.webmanifest", APP_ROOT).href,
      new URL("./apple-touch-icon.png", APP_ROOT).href,
      new URL("./build-version.txt", APP_ROOT).href
    ]);
  })());
});
self.addEventListener("message", event => {
  if (event.data && event.data.type === "SKIP_WAITING") self.skipWaiting();
});
self.addEventListener("activate", event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});
self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET" || request.headers.has("range")) return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin || !url.pathname.startsWith(APP_ROOT.pathname)) return;
  if (request.mode === "navigate") {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response && response.ok) {
          const cache = await caches.open(CACHE_NAME);
          cache.put(new URL("./", APP_ROOT).href, response.clone()).catch(() => {});
        }
        return response;
      } catch (_) {
        return (await caches.match(new URL("./", APP_ROOT).href)) || Response.error();
      }
    })());
    return;
  }
  event.respondWith((async () => {
    const cached = await caches.match(request);
    if (cached) return cached;
    try {
      const response = await fetch(request);
      if (response && response.status === 200 && response.type === "basic") {
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, response.clone()).catch(() => {});
      }
      return response;
    } catch (_) {
      return Response.error();
    }
  })());
});
""".replace("__VERSION__", version)
    (root / "service-worker.js").write_text(sw, encoding="utf-8")

    head = """
<link rel="manifest" href="./manifest.webmanifest">
<link rel="icon" href="./icon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="./apple-touch-icon.png">
<meta name="theme-color" content="#0f141f">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="Silverhart">
<style>
#silverhart-update{position:fixed;z-index:2147483000;left:12px;right:12px;top:12px;display:none;padding:12px 14px;border:1px solid #cdaa67;border-radius:12px;background:#151c2a;color:#fff;font:14px/1.4 system-ui,sans-serif;box-shadow:0 5px 24px #0008}
#silverhart-update button,#silverhart-diagnostics-toggle{border:1px solid #cdaa67;border-radius:8px;background:#cdaa67;color:#101522;padding:8px 12px;font:600 14px system-ui,sans-serif}
#silverhart-diagnostics-toggle{position:fixed;z-index:2147482000;right:10px;bottom:10px;width:38px;height:38px;padding:0;border-radius:50%;opacity:.72}
#silverhart-diagnostics{position:fixed;z-index:2147482001;right:10px;bottom:56px;display:none;max-width:min(340px,calc(100vw - 20px));max-height:45vh;overflow:auto;padding:12px;border:1px solid #64748b;border-radius:10px;background:#101827;color:#e5e7eb;font:12px/1.5 ui-monospace,monospace;white-space:pre-wrap}
</style>
"""
    runtime = r"""
<div id="silverhart-update" role="status"><span>A new Silverhart build is ready.</span> <button id="silverhart-update-now" type="button">Update now</button></div>
<button id="silverhart-diagnostics-toggle" type="button" aria-label="Show diagnostics">i</button>
<pre id="silverhart-diagnostics" aria-live="polite"></pre>
<script>
(function(){
  var build = "__VERSION__";
  var banner = document.getElementById("silverhart-update");
  var updateButton = document.getElementById("silverhart-update-now");
  var diagnostics = document.getElementById("silverhart-diagnostics");
  var waitingWorker = null;
  var reloading = false;
  if ("serviceWorker" in navigator && location.protocol === "https:") {
    navigator.serviceWorker.register("./service-worker.js", {scope:"./", updateViaCache:"none"}).then(function(reg){
      function inspect(worker){
        if(!worker)return;
        worker.addEventListener("statechange",function(){
          if(worker.state==="installed" && navigator.serviceWorker.controller){
            waitingWorker=reg.waiting||worker;
            banner.style.display="block";
          }
        });
      }
      if(reg.waiting && navigator.serviceWorker.controller){waitingWorker=reg.waiting;banner.style.display="block";}
      if(reg.installing)inspect(reg.installing);
      reg.addEventListener("updatefound",function(){inspect(reg.installing);});
      reg.update().catch(function(){});
    }).catch(function(error){console.warn("Silverhart service worker:",error);});
  }
  updateButton.addEventListener("click",function(){
    if(waitingWorker)waitingWorker.postMessage({type:"SKIP_WAITING"});
  });
  navigator.serviceWorker && navigator.serviceWorker.addEventListener("controllerchange",function(){
    if(!reloading){reloading=true;location.reload();}
  });
  function diagnosticsText(){
    var lines=["Silverhart Saga diagnostics","Build: "+build,"URL: "+location.href,
      "Network: "+(navigator.onLine?"online":"offline"),
      "Service worker: "+(navigator.serviceWorker&&navigator.serviceWorker.controller?"controlling":"not controlling"),
      "Viewport: "+window.innerWidth+" × "+window.innerHeight,
      "Screen: "+screen.width+" × "+screen.height,
      "Device pixel ratio: "+window.devicePixelRatio,
      "WebGL: "+(function(){try{return !!document.createElement("canvas").getContext("webgl2")?"WebGL 2":!!document.createElement("canvas").getContext("webgl")?"WebGL":"unavailable";}catch(e){return "error";}})()];
    if(navigator.storage&&navigator.storage.estimate){navigator.storage.estimate().then(function(s){diagnostics.textContent=lines.concat(["Storage used: "+Math.round((s.usage||0)/1048576)+" MB","Storage quota: "+Math.round((s.quota||0)/1048576)+" MB"]).join("\n");});}
    else diagnostics.textContent=lines.join("\n");
  }
  document.getElementById("silverhart-diagnostics-toggle").addEventListener("click",function(){
    diagnostics.style.display=diagnostics.style.display==="block"?"none":"block";
    if(diagnostics.style.display==="block")diagnosticsText();
  });
  window.addEventListener("online",function(){if(diagnostics.style.display==="block")diagnosticsText();});
  window.addEventListener("offline",function(){if(diagnostics.style.display==="block")diagnosticsText();});
})();
</script>
""".replace("__VERSION__", version)
    if 'rel="manifest"' not in html:
        if "</head>" not in html:
            raise SystemExit("Godot HTML export has no </head> insertion point.")
        html = html.replace("</head>", head + "\n</head>", 1)
    if "silverhart-update-now" not in html:
        if "</body>" not in html:
            raise SystemExit("Godot HTML export has no </body> insertion point.")
        html = html.replace("</body>", runtime + "\n</body>", 1)
    index.write_text(html, encoding="utf-8")


if __name__ == "__main__":
    main()
