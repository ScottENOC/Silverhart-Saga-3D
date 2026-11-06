# Hollowmere village prototype

The first exterior map is a playable-scale blockout around the existing Hollow Tankard interior.

## Layout

The map uses the same flat-top axial grid as the tavern, with a 40-hex local radius. The authored points follow the Campaign 2 Hollowmere layout:

- Hollow Tankard at the local origin.
- General store at (0, 18), with a path back to the tavern ring.
- Chapel at (-14, 0).
- Elder's house at (0, -12).
- Mira's and Oskar's houses at (12, 9) and (-6, 9).
- The stream runs along r = -25; the north road crosses it at q = 8.
- The signposted crossroads is at (8, 24), with the first sections of the four outgoing roads visible.
- Forest dressing is deterministic and kept clear of the roads, stream and building footprints.

The exterior currently uses procedural low-poly blockout buildings, dirt-road surfaces, a water strip, a timber bridge, a signpost and simple tree meshes. It is intended to establish scale, navigation and spatial relationships before detailed environment art.

## Ara character generation

The file data/characters/hollowmere_npcs.json is the source of truth for the first 13 adult village character profiles. Each profile stores its game ID, map position and Ara parameters. The profile uses Ara's normalized 0–1 sliders for gender, age, height, weight, muscularity and proportions, plus catalogue IDs for eyes, hair, facial hair, tattoos, garments, footwear, accessories and weapons.

The build is pinned to Ara commit b60b5bece6d383d2cbb7067fd50e7c8e68b5a395. The existing Silverhart patch_layering.py is applied before export so the under-top and under-bottom equipment slots are available. The profile exporter validates the selected catalogue IDs before exporting one full GLB per character. The generated files include a skinned rig and Ara's 77 animation clips; the Godot AraCharacterActor starts the Idle clip when it is available.

These settings are build-time Ara values, not live Godot sliders. The Wren Workshop page now has a profile selector and read-only display for the saved values; the updated page will be published after the current Wren Workshop build finishes and this branch is built. Changing a profile requires another Ara export. The player avatar remains a neutral placeholder until the player-appearance choices are defined.

## Generated asset pack

The Build Hollowmere Ara characters workflow uploads an artifact named hollowmere-npc-models. It contains:

- One generated GLB per profile.
- The exact .params.json file used for each export.
- profiles.json, the manifest used by the Wren Workshop preview.

Download and extract that artifact into the Godot repository so the GLBs are at:

art/characters/hollowmere/<profile-id>.glb

The directory is generated output and is not committed to Git. If the pack is absent, the Godot scene deliberately falls back to simple capsule actors so the map and movement tests can still run.

## Validation

tests/test_hollowmere_village.gd checks map bounds, stream/bridge traversability, road connectivity to all building thresholds, and that every NPC profile has a unique ID, valid normalized sliders and a traversable spawn point. The Hollowmere village validation workflow also imports the project and runs the existing grid, simulation and character tests.
