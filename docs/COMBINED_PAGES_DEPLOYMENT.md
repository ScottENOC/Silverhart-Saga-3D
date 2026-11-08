# Combined GitHub Pages deployment

The Pages site is published by `.github/workflows/combined-pages-deploy.yml`.

- The Wren Workshop site remains at the repository Pages root.
- The Godot browser build is published under `/game/`.
- The deploy workflow runs after a successful Godot web export or Wren Workshop build.
- It downloads the latest successful `godot-web-export` artifact and, when available, the latest `wren-workshop-site` artifact.
- If no successful Workshop artifact exists yet, it uses the checked-in `site/` shell as a fallback.
- Both build workflows only create artifacts; the combined deploy workflow is the single owner of Pages publishing, preventing one workflow from overwriting the other's site.

The Godot web export must pass its PWA packaging checks before it is eligible for deployment.
