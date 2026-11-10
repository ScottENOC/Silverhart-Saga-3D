# Unified character assembly

Silverhart characters are generated from the Ara female or male base, with each person's Ara body settings applied during the local asset build. The resulting bare body is then combined at runtime with that person's appearance profile, hairstyle, inventory and equipment.

## Body generation and morphs

Ara's body controls (gender, age, muscle, weight, height, proportions, ethnicity, breast settings and detail sliders) are applied by the generator when it creates the mesh. They are baked into the exported body geometry; Ara's current GLB exporter does not expose those 935 body targets as runtime blend shapes.

Facial expression blend shapes are exported separately (20 expression shapes when speech shapes are disabled; speech adds 14 more). Godot can use those facial targets at runtime.

Consequences:

- A person's body proportions must be present in their generated bare-body GLB. Storing muscle, weight, height and proportions in a profile does not make them runtime morphs.
- The female anatomy modification is a Blender skin-mesh sculpt pass. It changes the pelvic skin geometry and does not edit the fingers or other bones.
- Ara places its skeleton from the generated body's joints. The game rig uses the same bone definitions, but rest transforms can vary with the generated body profile. Do not assume a Wren garment can safely be rebound to an unrelated default female skeleton just because the bone names match.

## Runtime assembly

1. **Bare body** — a profile-generated, anatomy-integrated Ara GLB. Wren's pilot asset is art/characters/ara_runtime/bodies/wren_talbot.glb.
2. **Appearance profile** — data/characters/hollowmere_npcs.json supplies the Ara generation parameters, skin/eye/hair colours, hairstyle and garment styles.
3. **Hair** — a separate Ara skinned export attached to the character's skeleton.
4. **Inventory** — CharacterState is authoritative. Clothing and armour are separate skinned meshes; weapons, shields and helmets use the existing bone-attachment prop path.

The body is never hidden to simulate removing clothes. Garment meshes are independent nodes and inventory equipment toggles their visibility.

## Wren pilot asset pipeline

Wren is the first profile being validated end to end:

- Generate a bare female Ara body using Wren's exact profile settings.
- Apply the adult female anatomy sculpt to that bare body.
- Generate two additional Ara exports with identical Wren body settings and garments: one with footwear disabled, and one with Wren's configured combat boots.
- Apply the same adult anatomy pass to all three body/dressed exports.
- Compare the bare body, dressed/no-shoes export and dressed/booted export with tools/blender/compare_ara_footwear_rigs.py.
- The comparison established that the no-shoes export matches the bare body's complete 69-bone rest rig exactly, while the booted export shifts Hips by 30.421 mm. Therefore, footwear must not be present during generation of a skinned garment source.
- Use the no-shoes export as the canonical Wren garment source. The booted export is retained only for diagnostics; it is never normalised or used to extract skinned garments.
- The garment-library builder deliberately excludes the `shoes` slot from required skinned garments. It records configured footwear (such as `female:combat_boots`) in the build report's `deferred_equipment` list instead of failing the build when that footwear is absent from the no-shoes source.
- Package the bare body and matching garment library for Godot. Boots and sandals will be treated as separate equipment assets, not baked into the body or garment-source skeleton. Until those assets exist, their absence is explicit in the report; the builder does not fabricate footwear or silently substitute another mesh.

The old art/characters/hollowmere/*.glb models are not used as the source of Wren's new body or garments; an older export may have been made with different Ara parameters or generator versions. They remain a temporary runtime visual fallback for NPCs whose profile-generated bodies are not built yet, so the migration does not leave those characters undressed. This fallback is transitional and is not the target architecture.

This is deliberately a Wren-only pilot. Wren uses her new bare Ara body and matching garment library. Other NPCs temporarily retain their existing visual assets until their own profile-generated bare bodies and matching garment sources have been built. The player creator still uses the generic female/male preview bodies; its body macro sliders are not yet connected to profile-specific Ara body generation, and Wren's garment library is deliberately not attached to the player. Do not attach Wren's garment library to another character.

## Build locally

This pipeline is local Blender work, not a GitHub Actions job.

From the repository root:

```bash
export BLENDER_BIN="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
python tools/build_ara_runtime_local.py
```

The pipeline caches completed Ara exports, anatomy passes, validation, garment extraction and review renders under build/local-cache/ara. Cache entries are JSON manifests with a UTC build timestamp, a content fingerprint for declared inputs, and checksums/sizes for every output. A cache hit requires all three to match; missing inputs are errors, and modified or missing outputs force a rebuild. Each stage includes the scripts that directly control it in its fingerprint. The garment-fit stage consumes the actual modular assembly outputs and writes to separate fitted files, so downstream fitting cannot silently mutate the assembly cache.

By default, unchanged and checksum-verified cache entries can be reused regardless of age. To require fresh results, run the complete pipeline with `--force`, or set a maximum successful-cache age in hours with `--max-cache-age-hours`. Old pre-manifest cache stamps are treated as misses.

Important outputs:

- art/characters/ara_runtime/bodies/wren_talbot.glb — bare Wren body, with Wren's Ara macro settings baked in and the modified adult female anatomy.
- art/characters/ara/ara_person_wren_dressed_no_shoes.glb — Wren's garment source, generated with footwear disabled and proven to share the bare body's rest rig.
- art/characters/ara/ara_person_wren_footwear_rig_comparison.json — diagnostic proving the no-shoes rig matches and the booted rig has a 30.421 mm Hips offset.
- art/characters/ara_runtime/ara_person_garments.glb — Wren-profile garments only, extracted from the no-shoes Ara export.
- art/characters/ara/ara_person_wren_body.validation.json — final rig and facial-morph validation report.
- art/characters/ara/review/wren_body/ and wren_dressed/ — front, side, rear and three-quarter review renders.

## Validation contract

The bare Wren body and Wren dressed source must have:

- Identical bone names and ordering.
- The selected garment source must match the bare body's bone names, order, hierarchy and every rest-bone transform within 1e-5.
- The garment source must be generated with footwear disabled. A footwear-enabled export is rejected as a garment source because its Hips rest position differs.
- Facial morph targets present in both exports.
- The expected clothing materials present in the dressed source.

The garment builder independently validates the source rig and each extracted mesh's skinning before exporting separate garment nodes.

After the local build and Godot import, run:

```bash
"C:/Program Files/Godot/Godot.exe" --headless --path . --script tests/test_character_assembly.gd
```

The automated test does not replace visual inspection in the running game. Review Wren from the front, side and rear, then equip/unequip one garment and confirm the underlying body remains visible and correctly shaped.

## Gender and anatomy source diagnostics

The local pipeline now keeps raw Ara body review renders separate from the anatomy-processed outputs:

- `art/characters/ara/review/body_raw/` — raw female Ara export before the female anatomy pass.
- `art/characters/ara/review/male_raw/` — raw male Ara export before the male anatomy pass.
- `art/characters/ara/ara_person_gender_anatomy_validation.json` — geometry and bounds comparison for raw female, raw male, and both final anatomy-processed bodies.

The diagnostic compares the skin meshes' vertex counts, polygon counts, world-space bounds and (when topology counts match) per-vertex displacement. This isolates three possibilities:

1. Raw female and male exports are already effectively the same: investigate Ara's gender morph targets, source data and export/cache inputs.
2. Raw exports differ, but the final male body looks female: investigate the male anatomy/export/package path.
3. Female raw and final meshes barely differ: investigate the female sculpt's pelvic landmark, front-surface selection and deformation strength/topology.

The diagnostic does not automatically declare a body anatomically correct. It provides evidence about which stage changed the geometry; front/side/rear visual review remains mandatory.

## Visual validation status — blocked, not complete

The first in-game review exposed failures that the initial Wren pilot validation did not cover. The presence of a generated GLB and a successful garment extraction are not proof that the correct body, anatomy, hair, or inventory state is visible in Godot.

### Confirmed implementation gaps from code review

- The player creator still previews the generic assets `ara_person_body.glb` and `ara_person_male_body.glb`. It does not request a profile-generated body from the selected Ara macro settings. The body-build and height controls currently feed scale/tint metadata and cannot reproduce Ara's baked body morphs.
- The campaign player spawn also selects those same generic female/male assets. It does not build or select a body generated from the saved player appearance profile. The male build parameters request Ara gender 1 (male) with breast size and firmness set to zero, but the local review render must establish whether the exported torso is actually male-shaped.
- Wren's body pipeline explicitly sets `hair: none` on the bare-body export. Her braid must therefore come from the separate, tracked GLB at `art/characters/ara_runtime/hair/female_braid01.glb`. The campaign code attempts to attach it; the current in-game failure is therefore an attachment/import/transform problem to diagnose, not an absent source asset.
- The female anatomy pass is invoked for Wren and the generic female body, while the male anatomy pass is invoked for the generic male body. The current validation checks skeletons and facial morphs, not that the expected anatomy geometry is present, correctly positioned, or visible in Godot.
- The modular garment pilot is Wren-specific. It is not evidence that the player or other NPCs have correctly fitted clothing for their body profile.
- The current equipment attachment code toggles independent garment meshes but has no validated body-occlusion/clipping solution for anatomy intersecting clothing. Male anatomy under trousers/underwear is explicitly unvalidated.

### Required visual acceptance tests

Do not mark the character-assembly milestone complete until all of these have been checked in the running Godot project:

1. **Female base:** front, side and rear inspection confirms the intended adult female anatomy is part of the skin mesh, not a missing/hidden accessory.
2. **Male base:** front, side and rear inspection confirms a genuinely male torso/pelvis silhouette, no unintended breasts, and the male anatomy is correctly attached and weighted.
3. **Wren:** her profile-generated body has the female anatomy pass; her blue `braid01` is loaded; fatigue shirt, bra and fatigue pants are visible and correctly fitted.
4. **Player:** female and male choices load distinct correct base assets. The male choice must not be a female torso with only male anatomy added.
5. **Appearance controls:** changing hair style and colour changes the visible hairstyle; changing eye and skin colour changes the intended materials. Unsupported controls must be disabled or clearly identified, not silently accepted.
6. **Clothing/anatomy matrix:** for both body variants, inspect bare, underwear, trousers and fully clothed states from front, side and rear. No genital geometry may protrude through clothing; no body mesh may disappear when garments are equipped or removed.
7. **NPC fallback:** every NPC must either use a validated profile-generated Ara body with its appearance/equipment assembled, or an explicitly documented legacy complete outfit. Never substitute a naked generic base when profile assets are missing.

### November 2026 follow-up: first in-game assembly test

The first local in-game pass now equips Wren's shirt, trousers and bra, and those garments correctly unequip. The next inventory update adds Ara's native `bikini_bottom` as a separate `underBottom` item and maps its exported material to its own garment visual.

The same test still reports unresolved body and appearance failures:
- Wren's blue braid is not visible despite the female braid GLB being present in the runtime asset tree. Hair attachment must be verified against the actual Godot output; the runtime attachment now preserves the mesh transform relative to its exported root and logs the number of tinted materials/attached meshes.
- Wren's female anatomy is not visually confirmed in-game.
- The player male selection appears to use a female-shaped base with male anatomy added; the female anatomy is also not visibly confirmed.
- The creator's body-build and height choices previously only populated metadata. They now apply a conservative whole-body scale, not a true Ara body morph. True body proportions still require profile-specific baked exports.
- Skin, eye and embedded-hair tint operations now log how many surfaces they actually changed, so material-name mismatches can be diagnosed rather than silently ignored.

These are not accepted as resolved by code inspection. Inspect the local `art/characters/ara/review/female-body`, `male-body` and `wren-body` renders, then compare them with the runtime models. Do not merge PR #87 until the female and male body silhouettes/anatomy and Wren's hair are visually verified in Godot.

### Current disposition

PR #87 remains a draft. The Wren garment extraction and footwear deferral are pipeline progress only. The body/anatomy/appearance/runtime milestone is **blocked pending asset inspection and Godot visual validation**. Do not merge this PR on the strength of the garment-builder passing alone.

The next local build should be inspected using the generated review renders under `art/characters/ara/review/` before runtime testing. If the anatomy is absent in those renders, investigate the Blender anatomy stage. If it is present there but absent in-game, investigate the packaged GLB path, selected actor asset and Godot import. This separates asset-generation failures from runtime assembly failures instead of applying another speculative visibility patch.
