# Ara modular character visual animation review

## Goal

This is a standalone modular-asset preview: render Wren Talbot using the separately exported Ara body, braid, fatigue shirt, fatigue trousers, boots and sword on the 69-bone benchmark rig. The benchmark's 77 imported animation clips drive that preview skeleton.

This preview is not the gameplay actor architecture. Gameplay characters retain their own imported Skeleton3D and skin binding; `AraSkeletonRetargeter` transfers animation deltas from the benchmark source onto each character's native rest pose.

## Captured poses

`tests/capture_ara_modular_animations.gd` captures Idle, Walk, Run, Strafe left, Turn left 90°, Jump and Sword slash. Each capture is a real Godot render of the skinned modular meshes at a sample time in the imported clip.

## Asset source

CI stages the benchmark and modular exports from the Wren Workshop `character-pipeline-evaluation` artifact (workflow run `41979224139`). The boots and sword are staged from the Ara `npc_female_slim` component exports; both use the same 69-bone joint list, including `WeaponR`, as the Wren benchmark rig. These are review-compatible NPC accessory exports, not yet a dedicated Wren-specific boots export.

## What this review establishes

- The individual modular preview meshes can be attached to the benchmark skeleton for rendering.
- The benchmark animation player can drive that preview skeleton while the modular outfit and sword are visible.
- Gameplay runtime retargeting is validated separately by `tests/test_ara_character_animation_carrier.gd`.
- Captured stills provide a visual review of clothing/hair/weapon deformation across representative movement and combat clips.

Automated image capture and matching joint names do not by themselves establish that deformations are visually correct. Inspect the screenshots for clipping, offsets, skinning artefacts, sword placement, foot contact and the known ~20.8 mm Hips rest-origin difference. This is a review prototype, not the gameplay animation controller.

## Current limitations

The test samples clips at fixed times; it does not yet blend between locomotion states, extract root motion, synchronize animation velocity with CharacterBody3D movement, or solve foot locking. Those are subsequent integration tasks after the visible modular rig is accepted.