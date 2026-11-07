#!/usr/bin/env python3
"""Add version, safe update prompt and on-device diagnostics to Godot's native PWA."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    root = args.directory
    index = root / "index.html"
    manifest_path = root / "index.manifest.json"
    worker_path = root / "index.service.worker.js"
    version = args.version.strip()

    if not index.is_file() or not manifest_path.is_file() or not worker_path.is_file():
        raise SystemExit("Godot's native PWA export is incomplete (expected index.html, index.manifest.json and index.service.worker.js).")
    if not version:
        raise SystemExit("A non-empty build version is required.")

    # Keep Godot's own manifest, icons and service worker. The native worker
    # handles offline wasm/pck caching and COOP/COEP response headers.
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["name"] = "Silverhart Saga"
    manifest["short_name"] = "Silverhart"
    manifest["scope"] = "./"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    html = index.read_text(encoding="utf-8")
    if 'rel="manifest"' not in html or "index.service.worker.js" not in html:
        raise SystemExit("Godot's native PWA manifest or service-worker configuration is missing.")

    head = """
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
  var lastError = "none";
  function showUpdate(worker){
    if(!worker || !navigator.serviceWorker.controller)return;
    waitingWorker=worker;
    banner.style.display="block";
  }
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.ready.then(function(reg){
      function inspect(worker){
        if(!worker)return;
        worker.addEventListener("statechange",function(){
          if(worker.state==="installed" && navigator.serviceWorker.controller){
            showUpdate(reg.waiting||worker);
          }
        });
      }
      if(reg.waiting)showUpdate(reg.waiting);
      if(reg.installing)inspect(reg.installing);
      reg.addEventListener("updatefound",function(){inspect(reg.installing);});
      reg.update().catch(function(error){console.warn("Silverhart update check:",error);});
    }).catch(function(error){console.warn("Silverhart service worker:",error);});
  }
  updateButton.addEventListener("click",function(){
    if(!waitingWorker)return;
    updateButton.disabled=true;
    updateButton.textContent="Updating…";
    // Godot's native worker understands "update": it activates the waiting
    // worker and navigates open clients after its cache is ready.
    waitingWorker.postMessage("update");
  });
  window.addEventListener("error",function(event){lastError=event.message||"JavaScript error";});
  window.addEventListener("unhandledrejection",function(event){lastError=String(event.reason||"Unhandled promise rejection");});
  function diagnosticsText(){
    var lines=["Silverhart Saga diagnostics","Build: "+build,"URL: "+location.href,
      "Network: "+(navigator.onLine?"online":"offline"),
      "Viewport: "+window.innerWidth+" × "+window.innerHeight,
      "Screen: "+screen.width+" × "+screen.height,
      "Device pixel ratio: "+window.devicePixelRatio,
      "WebGL: "+(function(){try{return !!document.createElement("canvas").getContext("webgl2")?"WebGL 2":!!document.createElement("canvas").getContext("webgl")?"WebGL":"unavailable";}catch(e){return "error";}})(),
      "Last JavaScript error: "+lastError];
    if(navigator.serviceWorker){
      navigator.serviceWorker.getRegistration().then(function(reg){
        lines.push("Service worker: "+(reg&&reg.active?reg.active.scriptURL+" ("+reg.active.state+")":"not active"));
        if(reg&&reg.waiting)lines.push("Update: waiting");
        if(navigator.storage&&navigator.storage.estimate){
          navigator.storage.estimate().then(function(s){diagnostics.textContent=lines.concat(["Storage used: "+Math.round((s.usage||0)/1048576)+" MB","Storage quota: "+Math.round((s.quota||0)/1048576)+" MB"]).join("\n");});
        }else diagnostics.textContent=lines.join("\n");
      }).catch(function(){diagnostics.textContent=lines.join("\n");});
    }else diagnostics.textContent=lines.join("\n");
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
    if "silverhart-update-now" not in html:
        if "</head>" not in html or "</body>" not in html:
            raise SystemExit("Godot HTML export is missing a head or body insertion point.")
        html = html.replace("</head>", head + "\n</head>", 1)
        html = html.replace("</body>", runtime + "\n</body>", 1)
    index.write_text(html, encoding="utf-8")


if __name__ == "__main__":
    main()
