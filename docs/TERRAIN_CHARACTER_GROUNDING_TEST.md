# Terrain character grounding test

This prototype uses Wren Talbot's actual Ara Workshop character export as the visible character, attached to a separate physics-driven `CharacterBody3D`. The capsule collision shape remains authoritative for movement and grounding; Wren's mesh is visual only.

## Workshop model source

- Model: `ara_wren_mobile.glb` (Wren Talbot mobile preview export).
- Source: successful Wren Workshop character-pipeline GitHub Actions artifact, run `41979224139`, artifact `character-pipeline-evaluation`.
- The export parameters identify Wren by her dark-blue `braid01` hairstyle, fatigue shirt, dark fatigue pants and combat boots. The mobile export uses a 66-joint game rig and does not embed animation.
- The CI workflow downloads that exact artifact and stages the GLB before Godot's import scan. The source Workshop output is not modified.
- The build artifact currently has a 14-day retention period. The GLB should be promoted into managed project art assets before this becomes a permanent CI dependency.

## What is exercised

- Three stationary Wren characters spawn over the valley floor, a moderate slope and the ridge crest.
- A fourth Wren starts on the ridge shoulder and walks along it for 60 physics frames.
- Each character has a capsule collision shape, while Wren's model is a visual child of the physics body.
- The terrain renderer creates a static concave collision shape from the exact mesh used for rendering.
- The screenshot capture checks terrain ray hits, grounded state for all four characters, and meaningful movement along the ridge shoulder.

## Verified CI result

- GitHub Actions run: `42188392245` (successful, 6 November 2026).
- Terrain collision ray probes hit the generated mesh for all four Wren instances.
- All four instances reported `is_on_floor()` after the physics settling period.
- RidgeWalker moved `1.424 m` along the ridge shoulder during 60 physics frames and remained grounded.
- Four 1600×900 screenshots were captured and uploaded as the `terrain-prototype-screenshots` artifact.

## What this does not prove yet

- The mobile export has no walk animation, so the moving Wren translates in a static pose. This does not validate gait, foot locking, retargeted animation or root motion.
- The steep escarpment is not treated as a walkable ramp; this test does not validate climbing or ledge traversal.
- It does not yet test the game's hex-step movement controller.
- It does not yet test slope-specific climbing permissions, edge-profile ledges, animation adaptation, navmesh behaviour or terrain ray picking.
- The current terrain is still a coarse prototype mesh; successful grounding is not evidence that its visual quality is production-ready.
