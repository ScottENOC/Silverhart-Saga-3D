# Reusable character pipeline

## Goal

One adult base-body and rig contract should support Wren and a large NPC cast. NPC identity is data (proportions, face preset, skin palette, hair, outfit, material choices, accessories and tattoos), not a bespoke model per person.

## Current implementation on this branch

**Milestone correction:** no production Wren model exists yet. Ara is the base authoring system, and the immediate target is one complete generic person. Older cancelled builds used `ara_wren_*` names and Wren-specific parameters; these were benchmark exports, not a production Wren model. The current workflow now exports `ara_person_*` assets from a generic Ara base-person preset. Wren remains a later, separate character preset.

- `scripts/characters/character_appearance.gd`: serialisable appearance state, material tint/fabric application, independent shirt/bra/briefs/trouser visibility and opacity, JSON save/load.
- `tests/test_character_appearance.gd`: verifies shirt dye/fabric settings and accessory/tattoo IDs survive save/reload.
- `data/characters/npc_presets.json`: initial Wren, Mara and Garrick profiles. Several asset IDs are explicitly placeholders pending validation against Ara's installed asset catalogue.
- `tools/blender/inspect_character.py`: non-destructive four-angle inspection renders and mesh/rig/material report.
- `tools/blender/add_adult_anatomy.py`: adult-only external vulva and pubic-mound sculpt pass, weighted to the Ara Hips bone. It also expands briefs/trousers locally around the pelvis. This is a reviewable sculpt pass, not yet a final topology-integrated or deformation-tested anatomical sculpt.
- `tools/blender/add_attachment_points.py`: reusable named accessory sockets exported as GLB nodes.
- The phone viewer raycasts earrings, nose ring, necklace and optional left/right nipple and clitoral-hood jewellery onto the actual skin surface. Genital-region piercings are only visible in the body-only preview.
- The Ara build patch adds a separate under-top layer (a fitted sports bra) and adds briefs beneath outer trousers. The outer shirt and pants remain separate material slots.
- Ara-generated tattoo previews use its native UV-space skin-detail texture rather than a floating decal.
- The viewer workflow now exports a separate adult body-only GLB and a tattooed body-only GLB. Ara's body is anatomically neutral and has no genital geometry.

## Pipeline contract

1. Pin a generator version and validate its parameter schema and asset catalogue.
2. Generate one generic adult Ara person with a complete face, body, hair, game rig and simple everyday clothing. Keep Wren-specific hair, colours, proportions, weapons and identity out of this baseline.
3. Review the person in Blender from front, side, rear and three-quarter views; check anatomy, silhouette, mesh integrity, materials, skeleton and facial morphs.
4. Add any required project-specific anatomy to the shared base only after the unmodified Ara body has been inspected and accepted. Retopologise/merge and weight it to the rig before production.
5. Export a neutral body plus clothing/accessory modules or stable material slots. Verify actual GLB node/material structure; do not assume the generator exports modular meshes.
6. Import the person into Godot and verify scale, skeleton binding, materials, pose and animation. Exercise equipment slots and body/garment visibility.
7. Generate at least three visibly distinct people from saved parameter presets and stable seeds. Keep identity data separate from the shared rig and reusable garment assets.
8. Save appearance data as JSON, test reload, and produce a lightweight mobile preview with one model loaded at a time.

## Important limitations

The generic Ara person is still an assembled character export, not proof that arbitrary clothing combinations can be added at runtime. The current build adds a separate bra under-layer and briefs under the selected trousers during export; the material slots are independently dyeable, hideable and opacity-adjustable. More garment combinations require extending the generator's layer contract. Dynamic dyeing can be tested on a material slot, but changing the underlying fabric weave requires a shader/texture implementation and a known material contract. Ara can generate native tattoos (for example `armband_l` and `forearm_l`) into its UV-space skin-detail texture; the current viewer demonstrates them through a separately generated tattooed body GLB. The Godot appearance resource stores tattoo IDs but does not yet dynamically repaint the skin-detail texture at runtime. Phone-preview jewellery is raycast to mesh surfaces, but its anchor coordinates still need review against the generic base person's proportions. The user has confirmed that the current transparency preview reveals the underlying body without obvious missing-skin gaps; continue checking this across different garments and poses. The external vulva sculpt is weighted to the pelvis and trousers/briefs receive a local outward adjustment, but this must be checked from front, side and three-quarter views before treating clipping as solved. The sculpt is a first anatomical pass, not a medically validated or final topology-integrated model.


## CI reuse and invalidation

The Wren Workshop pipeline caches three stages independently:

1. **Ara source exports** — keyed by the pinned Ara generator revision and `tools/ara/patch_layering.py`. Anatomy, Blender fitting, review-render, and Workshop UI edits reuse the exported source GLBs without cloning Ara, installing pnpm dependencies/assets, or exporting every character and garment again.
2. **Anatomy integration** — female and male integrated bodies plus their review renders are cached against the relevant anatomy and inspection scripts. A change to an anatomy script invalidates only the affected integration cache.
3. **Modular equipment assembly and fitting** — the assembled/fitted modular GLBs are cached against the assembler, dress-slit, and anatomy-fit scripts. Outfit review renders use a separate cache and are saved only when both the dress and lace/fishnet render steps succeed; a failed dress render remains non-blocking and is retried on a later run. A Workshop site/UI-only change can therefore skip Blender assembly, garment fitting, and outfit rendering as well as the upstream work.

**Cache maintenance:** exported Ara parameters and garment variant definitions currently live inside `.github/workflows/wren-workshop.yml`. If those embedded parameters or variants change, increment the corresponding `ara-generated-...-v1`, `ara-integrated-...-v1`, and/or `ara-modular-...-v1` cache-key suffixes as applicable. A change to the pinned Ara generator revision must update the revision in both the clone step and all cache keys. The caches are optimisations only: a cache miss rebuilds that stage, and normal Actions artifacts are still uploaded for downstream jobs and review.

Male anatomy is built and reviewed by the main Wren pipeline from the same cached Ara source exports as the female anatomy. There is no separate male workflow that independently clones Ara and repeats the male export/integration.
