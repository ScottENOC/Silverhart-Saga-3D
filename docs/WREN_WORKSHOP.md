# Wren Workshop

The Wren Workshop is a standalone browser-based model inspection tool, separate from the Godot game.

## Cloud workflow

The GitHub Actions workflow `.github/workflows/wren-workshop.yml` runs Blender 5.2.3 on an Ubuntu runner, generates Wren, exports GLB files, assembles the viewer site and deploys it to GitHub Pages.

It runs manually through Actions → Build Wren Workshop → Run workflow, and automatically when Blender generator or viewer files change on `dev`.

## First-time GitHub Pages setup

In repository Settings → Pages, set Build and deployment → Source to GitHub Actions. The workflow then deploys the viewer. Repository Pages access settings determine who can view it; a private repository does not automatically mean a private Pages site.

## Viewer controls

- Drag: orbit; pinch or wheel: zoom; two-finger drag: pan.
- Front, back, left, right, three-quarter and reset camera presets.
- Key/fill light intensity and key-light direction.
- Toggle hair, garments/armour, weapon, body hair, tattoo and piercings by mesh-name prefix.

The viewer loads the full character GLB and toggles mesh visibility. It is an inspection tool, not a full material editor or Godot substitute.

## Build outputs

The full viewer site is uploaded as a GitHub Actions Pages artifact. The Blender source file and component GLBs are generated on the runner and are not committed back into the source repository.