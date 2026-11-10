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
- Generate a second Ara export with the same Wren body settings, game rig, A-pose and facial-shape settings, but with Wren's current inventory garments.
- Apply the same anatomy and garment-clearance pass to the dressed export.
- Extract Wren's garments from that matching dressed export and validate its bone names, order and rest transforms against the bare Wren body.
- Package the bare body and matching garment library for Godot.

The old art/characters/hollowmere/*.glb models are not used as the source of Wren's new body or garments; an older export may have been made with different Ara parameters or generator versions. They remain a temporary runtime visual fallback for NPCs whose profile-generated bodies are not built yet, so the migration does not leave those characters undressed. This fallback is transitional and is not the target architecture.

This is deliberately a Wren-only pilot. Wren uses her new bare Ara body and matching garment library. Other NPCs temporarily retain their existing visual assets until their own profile-generated bare bodies and matching garment sources have been built. The player creator still uses the generic female/male preview bodies; its body macro sliders are not yet connected to profile-specific Ara body generation, and Wren's garment library is deliberately not attached to the player. Do not attach Wren's garment library to another character.

## Build locally

This pipeline is local Blender work, not a GitHub Actions job.

From the repository root:

```bash
export BLENDER_BIN="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
python tools/build_ara_runtime_local.py
```

The pipeline caches completed Ara exports, anatomy passes, validation, garment extraction and review renders under build/local-cache/ara. A failed later stage should not require repeating successful earlier stages unless an input fingerprint changes.

Important outputs:

- art/characters/ara_runtime/bodies/wren_talbot.glb — bare Wren body, with Wren's Ara macro settings baked in and the modified adult female anatomy.
- art/characters/ara_runtime/ara_person_garments.glb — Wren-profile garments only, extracted from the matching Wren Ara export.
- art/characters/ara/ara_person_wren_body.validation.json — rig and facial-morph validation report.
- art/characters/ara/review/wren_body/ and wren_dressed/ — front, side, rear and three-quarter review renders.

## Validation contract

The bare Wren body and Wren dressed source must have:

- Identical bone names and ordering.
- Identical bone rest transforms (within the validator's strict tolerance).
- Facial morph targets present in both exports.
- The expected clothing materials present in the dressed source.

The garment builder independently validates the source rig and each extracted mesh's skinning before exporting separate garment nodes.

After the local build and Godot import, run:

```bash
"C:/Program Files/Godot/Godot.exe" --headless --path . --script tests/test_character_assembly.gd
```

The automated test does not replace visual inspection in the running game. Review Wren from the front, side and rear, then equip/unequip one garment and confirm the underlying body remains visible and correctly shaped.
