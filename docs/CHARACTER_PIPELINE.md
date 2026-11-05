# Reusable character pipeline

## Goal

One adult base-body and rig contract should support Wren and a large NPC cast. NPC identity is data (proportions, face preset, skin palette, hair, outfit, material choices, accessories and tattoos), not a bespoke model per person.

## Current implementation on this branch

- `scripts/characters/character_appearance.gd`: serialisable appearance state, material tint/fabric application, per-garment visibility and opacity, JSON save/load.
- `tests/test_character_appearance.gd`: verifies shirt dye/fabric settings and accessory/tattoo IDs survive save/reload.
- `data/characters/npc_presets.json`: initial Wren, Mara and Garrick profiles. Several asset IDs are explicitly placeholders pending validation against Ara's installed asset catalogue.
- `tools/blender/inspect_character.py`: non-destructive four-angle inspection renders and mesh/rig/material report.
- `tools/blender/add_adult_anatomy.py`: adult-only external anatomy blockout helper. It creates separate guide meshes; it is not yet a topology-integrated or deformation-tested anatomical sculpt.
- `tools/blender/add_attachment_points.py`: reusable named accessory sockets exported as GLB nodes.
- The phone viewer places preview earrings, a nose ring and a necklace using Ara's Y-up / +Z-front coordinate convention. Ara-generated tattoo previews use its native UV-space skin-detail texture rather than a floating decal.
- The viewer workflow now exports a separate adult body-only GLB and a tattooed body-only GLB. Ara's body is anatomically neutral and has no genital geometry.

## Pipeline contract

1. Pin a generator version and validate its parameter schema and asset catalogue.
2. Generate a neutral adult shared base body and rig, then review anatomy and silhouette in Blender from front, side, rear and three-quarter views.
3. Add anatomy to the shared base once, not independently to every NPC. Retopologise/merge and weight it to the pelvis before production.
4. Export a neutral body plus clothing/accessory modules or stable material slots. Verify actual GLB node/material structure; do not assume the generator exports modular meshes.
5. Generate NPCs from validated presets and stable seeds. Keep IDs and appearance data separate from mesh files.
6. In Godot, apply appearance state to named material slots and attach reusable accessory scenes to named socket nodes.
7. Save appearance data as JSON and test a reload before treating runtime customisation as complete.
8. Produce a lightweight mobile preview with one model loaded at a time and reduced texture/geometry cost.

## Important limitations

The current Ara benchmark is an assembled character export, not proof of independent runtime clothing modules. Dynamic dyeing can be tested on a material slot, but changing the underlying fabric weave requires a shader/texture implementation and a known material contract. Ara can generate native tattoos (for example `armband_l` and `forearm_l`) into its UV-space skin-detail texture; the current viewer demonstrates them through a separately generated tattooed body GLB. The Godot appearance resource stores tattoo IDs but does not yet dynamically repaint the skin-detail texture at runtime. Phone-preview jewellery is bounds-positioned and still needs visual review against the generated model. Garment opacity in the viewer is a material preview only: Ara removes skin under clothing in its normal clothed export, so transparent garments can reveal gaps; use the body-only export to inspect the underlying base body. The body-only preview is adult and anatomically neutral, with no genital geometry. The anatomy helper is a blockout and must not be labelled anatomically correct until reviewed and sculpted against anatomical references.
