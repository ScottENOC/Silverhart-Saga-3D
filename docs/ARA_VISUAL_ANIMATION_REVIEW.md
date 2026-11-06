# Ara modular character visual animation review

## Goal

Render Wren Talbot using the separately exported Ara body, braid, fatigue shirt, fatigue trousers and sword, all bound to the 69-bone benchmark rig. The benchmark's 77 imported animation clips drive that one shared skeleton.

## Captured poses

`tests/capture_ara_modular_animations.gd` captures Idle, Walk, Run, Strafe left, Turn left 90°, Jump and Sword slash. Each capture is a real Godot render of the skinned modular meshes at a sample time in the imported clip.

## Asset source

CI stages the benchmark and modular exports from the Wren Workshop `character-pipeline-evaluation` artifact (workflow run `41979224139`). The sword is the Ara `npc_female_slim/weapon_sword.glb` export; its skin contains the same 69-bone joint list, including `WeaponR`, as the Wren benchmark rig.

## What this review establishes

- The individual modular meshes can be attached to the benchmark skeleton for rendering.
- The benchmark animation player can drive the shared skeleton while the modular outfit and sword are visible.
- Captured stills provide a visual review of clothing/hair/weapon deformation across representative movement and combat clips.

Automated image capture and matching joint names do not by themselves establish that deformations are visually correct. Inspect the screenshots for clipping, offsets, skinning artefacts, sword placement, foot contact and the known ~20.8 mm Hips rest-origin difference. This is a review prototype, not yet the gameplay animation controller.

## Current limitations

The test samples clips at fixed times; it does not yet blend between locomotion states, extract root motion, synchronize animation velocity with CharacterBody3D movement, or solve foot locking. Those are subsequent integration tasks after the visible modular rig is accepted.