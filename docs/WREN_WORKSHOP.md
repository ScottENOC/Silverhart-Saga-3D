# Wren Workshop

The Wren Workshop is a standalone browser-based model inspection/customisation prototype, separate from the Godot game. It is published as a static site through **GitHub Pages**:

- Live viewer: https://scottenoc.github.io/Silverhart-Saga-3D/
- Source: `.github/workflows/wren-workshop.yml`
- Deployment target: GitHub Pages only; it does not depend on the Godot web export or Hollowmere preview workflows.

## Cloud workflow

The Wren workflow builds a generic female Ara base, one female body-only export, a male Ara body, anatomy-integrated body assets, and modular female garment variants. Tattoos are applied in the browser at runtime; no tattoo-specific body model is generated or integrated. It assembles the static viewer site and deploys that site to GitHub Pages.

The workflow runs manually through Actions → Build Wren Workshop → Run workflow, and automatically on relevant changes to Ara/Blender tools, viewer files, the character pipeline documentation or the workflow itself on its configured branches.

The current character source is Ara. The old procedural Wren blockout scripts are retained as historical experiments only; they are not part of the current build or review path. Wren Talbot remains a later character preset/model to be built on the reusable Ara foundation.

## Viewer scope and limitations

- Female Ara: modular clothing and accessory inspection.
- Female Ara body-only inspection and live browser-based tattoo customisation. Tattoos are surface decals applied to the loaded skin, saved with the appearance, and do not require a second body GLB.
- Male Ara: anatomy preview. Male clothing fitting and accessory sockets are not yet implemented.
- The viewer is a browser-based asset inspection/customisation prototype, not a substitute for in-game Godot validation.

## Build outputs and retention

- Raw Ara model/parameter artifacts are retained for 2 days for dependent integration jobs.
- Intermediate integrated body artifacts are retained for 2 days.
- Male body/review and final character-pipeline evaluation artifacts are retained for 14 days.
- The standalone `wren-workshop-site` artifact is retained for 90 days.
- Build artifacts and logs are visible to readers of this public repository. Generated models are not committed to the source repository; the published site contains the models needed by the viewer.
