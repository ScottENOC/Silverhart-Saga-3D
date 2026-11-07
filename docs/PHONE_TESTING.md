# Testing Silverhart Saga on iPhone

The Godot browser export is published at:

- https://scottenoc.github.io/Silverhart-Saga-3D/game/

## Install on iPhone

1. Open the game URL in **Safari** (not an in-app browser).
2. Tap **Share**.
3. Choose **Add to Home Screen**.
4. Keep **Open as Web App** enabled, then tap **Add**.
5. Launch Silverhart from its new Home Screen icon.

The game remains a web app; this does not install a native App Store package. It can be updated from the hosted site without reinstalling it.

## First test pass

- Launch once while online and allow the game to finish loading.
- Close the app and launch it again while still online. Godot's built-in service worker then controls the page load and can cache the large WebAssembly and game-pack files.
- Check that the game starts and that saved settings/appearance remain available.
- Turn on Airplane Mode and relaunch to test the cached game. Offline play is best-effort: iOS may evict website storage, and a first launch alone may not have cached every large game file.
- Restore connectivity. When a newer build is published, the app should show an **Update now** prompt. Use it at a safe point in the game; the app reloads into the new build.
- Tap the small **i** button at the lower-right of the game to view build, network, viewport, WebGL and browser-storage diagnostics. Include this information when reporting a phone-specific problem.

## Important limits

- This is a Home Screen web app (PWA), not a signed native iOS app or TestFlight build.
- Browser storage is not a substitute for backing up important save data. Do not assume local saves will survive every iOS storage cleanup.
- Offline caching is opportunistic and subject to available device storage. A successful first online launch is required before meaningful offline testing.
- For a fresh test after an update, use the in-app update prompt rather than deleting the app or clearing Safari website data.
