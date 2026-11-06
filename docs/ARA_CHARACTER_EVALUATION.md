# Ara 3D Gen evaluation

## Purpose

Evaluate Ara 3D Gen as the primary reusable human-character authoring system before investing further in bespoke procedural anatomy. This is a time-boxed technical and visual evaluation, not an adoption decision.

Upstream: https://github.com/olatunde85/3d-gen  
Documentation: https://ara3dgen.com/docs  
Upstream revision evaluated: record the exact commit SHA used for each export.

## Licensing assessment

Ara's repository declares its generator code MIT-licensed. Its bundled character dataset is derived from MakeHuman core assets released under CC0 1.0. Ara's own scripts/ASSETS_LICENSE.txt identifies the base mesh, morph targets, skeleton, skins, eyes, brows, lashes, hair, clothes and proxy meshes as CC0. MakeHuman's licence statement also says its exported models and derivatives can be used commercially, modified, redistributed and included in closed-source games.

Ara states that exported characters may be used commercially without attribution. Its motion-capture clips are derived from the CMU Graphics Lab Motion Capture Database. CMU permits commercial use in products but prohibits reselling the motion data itself, including converted forms. Ara's asset notice requests this acknowledgement:

> The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.

Keep that acknowledgement in our third-party notices if we ship those clips. Do not sell or distribute the motion data as a standalone asset pack. Check the licence of any future third-party garment, hair, texture, sound or animation added to Ara individually; the upstream project's general licence does not automatically cover unrelated additions.

This is a practical project assessment, not legal advice. Preserve copies of the exact upstream licence files and commit SHA used for each shipped asset set.

## Why Ara is the first candidate

- Scriptable CLI and saved parameter files make repeatable NPC creation possible.
- MakeHuman's CC0 base mesh and morph system avoid rebuilding human anatomy from primitives.
- Separate clothing, hair, props, a game rig and GLB export align with our modular character architecture.
- Its docs describe Godot export conventions and a 65-bone Mixamo-named game rig.

Ara is a young project with a small public contributor base. Treat feature claims as hypotheses until our own export and Godot import checks pass.

## Evaluation sequence

1. Pin an upstream commit; record package and asset licences.
2. Build the upstream project and run its own automated checks (npm test, npm run test:gltf, and npm run test:ui where CI resources permit).
3. Generate an adult female benchmark with a saved parameter file. Match Wren's slim athletic proportions, dark blue braid, green/pink shirt palette, charcoal trousers and sword as closely as the available assets permit.
4. Export a high-detail rigged GLB with facial shapes and a small animation selection.
5. Inspect the exported GLB in the existing private phone viewer, then import it into Godot 4.7.2.
6. Test skeleton names/retargeting, scale and axes, material/texture import, facial blend shapes, weapon socket orientation, hand grip, and at least idle/walk/sit/combat clips.
7. Test body morphs against clothing fit, clipping, skin hiding, garment swapping and whether hair/clothes can be independently replaced.
8. Generate at least three visibly distinct NPCs from saved parameter files and confirm deterministic rebuilds.

## Acceptance gates

Ara becomes our character foundation only if it meets all of these:

- Visual quality is a credible starting point for our realistic fantasy RPG target, not a low-poly placeholder.
- Face and body can be customised enough to create recognisably different NPCs without hand-sculpting each one.
- Clothing fits multiple body shapes without unacceptable clipping and can be swapped independently.
- Rig imports into Godot cleanly and supports our animation and equipment attachment needs.
- Sword grip and hand pose are usable or can be corrected through a reusable rig/animation pose rather than per-character mesh edits.
- Export pipeline is repeatable, version-pinned and licence-documented.

If Ara fails visual quality but passes its rig/data tests, retain it as a base mesh/morph source and improve selected characters in Blender. If it fails the rig or garment pipeline, compare MPFB as the Blender-native alternative. Do not port Ara's generator runtime into the game; generated GLBs and appearance parameters are build-time content, while Godot owns runtime character assembly and gameplay state.
