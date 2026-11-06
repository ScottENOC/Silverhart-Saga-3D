# Terrain character grounding test

This prototype uses the Wren Workshop Ara-derived Wren character export as the visible character, attached to a separate physics-driven `CharacterBody3D`. The capsule collision shape remains authoritative for movement and grounding; the character mesh is visual only.

## Workshop model source

- Model: `ara_wren_mobile.glb` (Wren Talbot mobile preview export).
- Source: successful Wren Workshop character-pipeline GitHub Actions artifact, run `41979224139` (build #84).
- The model is a static rigged GLB with a 66-joint skin and no embedded animation. It is used to assess real character proportions, visible foot contact and body placement against the ridge.
- The CI workflow downloads that exact artifact and stages the GLB before Godot's import scan. The source Workshop output is not modified.
- The build artifact currently has a 14-day retention period. The model should be promoted to the project's managed art assets before this test becomes a permanent CI dependency.

## What is exercised

- Three stationary Wren characters spawn over the valley floor, a moderate slope and the ridge.
- A fourth Wren character moves horizontally toward and across the ridge, reversing when its capsule encounters a wall.
- Each character has a capsule collision shape, while the visible Ara model is a child of the physics body.
- The terrain renderer creates a static concave collision shape from the exact mesh used for rendering.
- The screenshot capture script checks that the terrain can be ray-hit and fails if any character is not reported as grounded.

## What this does not prove yet

- The exported model has no walk animation, so the moving character translates in a static pose. This does not validate gait, foot locking, retargeted animation or root motion.
- It does not yet test the game's hex-step movement controller.
- It does not yet test slope-specific climbing permissions, edge-profile ledges, animation adaptation, navmesh behaviour or terrain ray picking.
- The current terrain is still a coarse prototype mesh; successful grounding is not evidence that its visual quality is production-ready.
