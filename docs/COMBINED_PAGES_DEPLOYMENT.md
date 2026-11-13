# Combined GitHub Pages deployment

The Godot browser export and Wren Workshop build each deploy the combined site after their own build artifact is ready. Both jobs share the `combined-pages-deployment` concurrency group so they cannot overwrite each other concurrently.

- The Wren Workshop site remains at the repository Pages root.
- The Godot browser game is published under `/game/`.
- The Godot export downloads the latest successful `wren-workshop-site` artifact when available; otherwise it uses the checked-in `site/` shell.
- The Wren Workshop publish job downloads the latest successful `godot-web-export` artifact when available; if no game build exists yet, it publishes the Workshop only.
- Each workflow publishes only after its own build succeeds. A failed Workshop generation does not prevent the Godot game export from deploying.

The browser game is therefore available at:

`https://scottenoc.github.io/Silverhart-Saga-3D/game/`
