# GitHub Actions workflow map

This repository uses GitHub Actions for independent build and validation tasks. The production Wren Workshop is deployed separately from the Godot game so a game export cannot block the Workshop.

## Retained workflows

| Workflow | Trigger / responsibility |
|---|---|
| **Build Wren Workshop** (`wren-workshop.yml`) | Manual or changes on `dev` to Ara/Blender tools and Workshop assets. Generates Ara female and male bases, integrates anatomy, exports modular garment variants, renders review angles, assembles the static site and deploys the Workshop to GitHub Pages. |
| **Godot and Blender validation** (`character-validation.yml`) | Pull requests and pushes to `dev` / shared-character-system. Fast Godot headless tests and Blender/Ara Python syntax and assembly tests. |
| **Godot and terrain validation** (`godot-validation.yml`) | Game/terrain tests, browser-export smoke test and terrain screenshots. |
| **Build Hollowmere Ara characters** (`hollowmere-npcs.yml`) | Generates the reusable Hollowmere NPC/player Ara model pack as an Actions artifact. |
| **Hollowmere village validation** (`hollowmere-validation.yml`) | Hollowmere-specific profile, map and opening-scene checks plus Python profile validation. Generic hex-grid and simulation tests live in Godot validation, not here. |
| **Capture Hollowmere map screenshots** (`hollowmere-screenshots.yml`) | Produces visual map screenshots using the latest successful NPC artifact from `dev`. |
| **Build Godot Web Export** (`godot-web-export.yml`) | Imports the current Hollowmere Ara pack, validates it, and creates a PWA-ready Godot web artifact. It does not deploy to Pages. |

## Retired duplicate workflows

- `iphone-hollowmere-ara-preview.yml`: duplicated the Godot import, test and web-export work and triggered another export workflow. Its tests are covered by the retained validation workflows.
- `male-anatomy.yml`: duplicated the male Ara generation/anatomy/review job now integrated into Build Wren Workshop.
- `wren-modular-review.yml`: repeated the modular outfit rendering already performed and uploaded by Build Wren Workshop, with an outdated list of outfit variants.

The old procedural from-scratch Wren blockout job was also removed from active validation. Its source scripts remain only as historical experiments.

## Artifact and deployment boundaries

- Wren Workshop deployment: GitHub Pages root, built only by `wren-workshop.yml`.
- Godot browser build: Actions artifact from `godot-web-export.yml`; no Pages deployment job.
- Hollowmere NPCs, validation renders and terrain/map screenshots: Actions artifacts with workflow-specific retention.
- Generated Ara GLBs are not committed to source by default; the relevant downstream workflow downloads the exact artifact it needs.

## Why this separation matters

A failure in Godot export or map screenshot capture must not prevent the Wren Workshop from publishing. Likewise, a Workshop rendering failure must not silently publish an incomplete model set. Each workflow should own one clear output and validate that output before publishing or uploading it.
