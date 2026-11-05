# Character completion milestone

## Current state

The pinned Ara pipeline successfully exports a skinned body, hair, shirt and trousers. A completed GitHub Actions run generated three distinct adult NPC previews and separate body, hair, shirt, alternate shirt, trousers, alternate trousers, boots and sword components for each. All generated components passed an exact 69-bone ordered-hierarchy comparison against their respective body. The private viewer is being updated to expose the three previews. The Godot assembler and appearance persistence/shader foundations are committed, but their in-engine tests have not yet run.

## Required work before calling the body finished

The Ara body GLB has not yet had a verified Blender sculpt pass. Do not mark the anatomy as complete based on generator output alone. The next authoring pass must inspect the actual imported body from front, back, both sides, three-quarter and close-up views, then refine the external vulva anatomy as integrated body topology:

- Natural labia majora contours continuous with the surrounding skin.
- Clearly modelled but restrained labia minora and vestibular detail.
- Clitoral hood integrated into the anterior vulvar anatomy.
- No floating primitives, visible seams, non-manifold intersections or abrupt shading transitions.
- Preserve UVs/material assignment and transfer skin weights from the adjacent pelvis.
- Check the result in neutral standing and animated poses, including clothing visibility/body-region hiding.

This is an adult, non-erotic anatomical asset. Anatomical correctness and clean deformation take priority over exaggerated detail.

## Attachment socket calibration

The rig exposes named sockets for both ears, nose, necklace, both nipples, clitoral hood and both hands. The current calibration manifest marks them as uncalibrated. That is intentional: no jewellery is allowed to use guessed transforms. Calibrate each socket against the final mesh in Blender, export bone-local transforms per supported body variant, and verify the attached ring/chain in front, side and three-quarter views.

The nipple anchors must be calibrated to the breast surface for each supported body shape. A torso bone alone does not account for breast-size morphs, so offsets must be body-variant aware. The clitoral-hood anchor follows the pelvis and must be calibrated after the anatomical sculpt.

## NPC variation and equipment

The three deterministic adult presets deliberately vary stature, weight, muscle, face modifiers, skin tone, hair, tattoo and clothing. Each shares the same Ara game-rig definition. The pipeline exports each NPC's body, hair, shirt, trousers, boots and sword as separate assets, plus alternate shirt and trouser assets for swap testing.

Armour is not yet included in the generated test catalogue. Add armour only after its geometry and material group are confirmed in the pinned Ara asset catalogue; do not substitute a recoloured shirt and call it armour.

## Runtime verification checklist

- [x] Three NPC asset sets generated from the same Ara game-rig definition; all component bone hierarchies match exactly (69 bones).
- [ ] Three NPCs load and animate together in Godot using the same assembler.
- [ ] Hair, shirts, trousers, boots and weapons swap without recreating the body (asset sets generated; runtime test pending).
- [ ] Material tint and fabric mode change on an equipped shirt.
- [ ] Material overrides are stored in CharacterAppearance and survive save/reload.
- [ ] Ear, nose and necklace accessories attach to calibrated sockets.
- [ ] Nipple and clitoral-hood ring sockets are calibrated on all supported body variants.
- [ ] Ara tattoos render correctly on the three-dimensional body; dynamic tattoo changes use a UV overlay or a regenerated body texture, not a whole-character rebuild.
- [ ] Garments fit each body variant and body-region hiding prevents skin/clothing intersections.
- [ ] All components deform correctly during animation.
- [ ] Godot 4.7.2 headless and in-editor tests pass.

## Blender review helper

tools/ara/blender_body_review.py imports a generated body GLB into Blender and produces front, back, left, right and three-quarter review renders plus a .blend checkpoint. This is a review setup, not an automatic sculpt. The anatomical edit must be performed against the actual mesh and then re-exported.
