# Character production pipeline

Status: architecture baseline; implementation is gated on validation of Ara/Blender exports.

## Goals

- One reusable adult-human character system for background NPCs, companions and named characters.
- Ara is the source-generation tool; Blender is the inspection/preparation/export stage; Godot is the runtime customisation and presentation layer.
- Runtime appearance changes must not require another Ara generation.
- Character identity and appearance are data-driven and reproducible.
- The mobile Hugging Face Space is a review surface, not the production environment.

## Pipeline

1. Generate a source character in Ara.
2. Record the exact generation inputs, source version and output identifiers.
3. Inspect geometry, materials, skeleton, morph targets, UVs and clipping in Blender.
4. Prepare reusable body, clothing, armour, hair and accessory assets.
5. Export GLB assets with stable names and documented rig/morph conventions.
6. Validate the GLB in a browser viewer and in Godot.
7. Save an appearance specification that references shared assets and parameter values.

Do not claim a feature is supported merely because it appears in Ara's UI. A feature is supported only after it survives export, Blender inspection, GLB round-trip and Godot runtime testing.

## Character specification

The specification is the stable interface between generation, asset preparation, NPC authoring and Godot. Keep it versioned and independent of any one character.

Example (illustrative; parameter names are not confirmed Ara controls):

```json
{
  "schema_version": 1,
  "character_id": "npc_example_001",
  "profile": "background",
  "source": {
    "generator": "ara",
    "generator_version": null,
    "generation_seed": 1842,
    "source_asset": null
  },
  "body": {
    "body_asset": "human_base_v1",
    "morphs": {},
    "anatomy_variant": null
  },
  "head": {
    "head_asset": "human_head_v1",
    "morphs": {}
  },
  "skin": {
    "material": "skin_default",
    "parameters": {},
    "overlays": []
  },
  "hair": {
    "asset": null,
    "material_parameters": {}
  },
  "clothing": [],
  "armour": [],
  "accessories": [],
  "tattoos": [],
  "piercings": [],
  "overrides": {
    "locked_features": []
  }
}
```

Unknown or unsupported parameters remain absent/null; do not invent mappings to Ara controls.

## Asset contracts

### Body
- Shared topology/rig contract across supported body variants, or an explicit compatibility map where topology differs.
- Document skeleton bone names, rest pose, scale, forward axis and animation retargeting assumptions.
- Record morph target names and ranges from the exported file, not from memory or UI labels.
- Anatomical variants must be part of the body asset contract and tested with clothing coverage.

### Clothing and armour
- Each item declares compatible body/rig versions, occupied equipment slots, layering group, material slots and hide-body regions.
- Clothing fit and armour fit are separate validation categories.
- Armour classes: soft/padded, flexible articulated (mail/scale), rigid plate.
- Layering must be explicit; avoid relying on scene-tree order to decide visual priority.
- Record known clipping limitations rather than silently accepting them.

### Tattoos
- Prefer UV texture/decal layers over separate geometry when the UV layout supports it.
- Each tattoo records texture, body region, UV/material target, blend mode and colour parameters.
- Validate on multiple body morphs and under clothing changes.

### Piercings and accessories
- Use named attachment sockets on the skeleton or stable body landmarks.
- Each accessory declares socket, local transform, scale, material and compatibility.
- Test at rest and during representative animation; reject visible float, penetration or detachment.
- Piercing jewellery is an accessory asset; the piercing location/anchor is part of the character configuration.

## Character profiles

### Background NPC
- Generated from a constrained template and deterministic seed.
- Uses approved body, face, hair, clothing and accessory libraries.
- Occupation, faction, region and climate constrain the randomisation pools.
- Output is a character specification plus references to shared assets; do not duplicate meshes per NPC unless required.

### Companion / important NPC
- Same schema and asset contracts as background NPCs.
- Manually curated face/body/style and explicit feature locks.
- Regeneration of one component must not overwrite locked components.
- Preserve a stable character ID and revision history.

## Godot runtime responsibilities

- Load shared GLB assets and compose compatible character components.
- Expose only validated morph targets and material parameters.
- Apply tattoo overlays and accessory sockets without regenerating the source model.
- Support equipment slots, armour layering and hide-body regions.
- Save/load the character specification, not a unique baked mesh for every appearance.
- Validate missing assets and incompatible combinations with clear diagnostics.

## Validation gates

A capability is marked **validated** only when all applicable gates pass:

1. Source generation completes and output is retained.
2. Blender opens the output without repair or missing dependencies.
3. Geometry and materials pass visual inspection from front, back, sides and three-quarter views.
4. Rig and morph targets are enumerated and behave as expected.
5. Clothing/accessories pass fit and deformation checks.
6. GLB export/re-import preserves the required data.
7. Godot loads the asset and applies runtime changes.
8. Save/reload preserves the appearance.

## Initial test matrix

| Test | Required evidence |
|---|---|
| Shared body | Blender multi-angle review; rig and mesh inventory |
| Body variants | At least three proportion profiles on same body contract |
| Tattoos | Two UV overlays; persist through save/reload and clothing changes |
| Piercings | Ear, nose, nipple and clitoral jewellery on correct sockets; animation check |
| Clothing | Representative upper, lower, full-body, footwear and accessory items |
| Materials | Dye an equipped garment; save/reload; verify material parameters |
| Armour | One soft, one flexible and one rigid item; layering and clipping review |
| NPC batch | Three seeded NPCs with distinct proportions, faces, skin, hair and outfits |
| Companion | One manually curated character with locked identity features |
| Godot UI | Edit validated body/face/material/equipment options and save/reload |

## Mobile review surface

The Hugging Face Space should provide:
- A touch-friendly GLB viewer with orbit, pan, zoom and reset.
- A model selector and visible build/revision identifier.
- Front, back, left, right and three-quarter camera presets.
- A compact asset/validation report (mesh, material, skeleton, morph counts).
- A comparison mode for body/clothing variants.
- Clear loading and failure states; avoid loading several large GLBs simultaneously on iPhone Safari.

The Space must not imply that a feature works in Godot until the Godot validation gate has passed.

## Current known Ara baseline

From the previous evaluation:
- One generated GLB contained one mesh with 16 material sections.
- It contained a 69-joint skeleton.
- It contained 34 facial morphs, understood to be expression/lip-sync morphs rather than confirmed face-shape controls.
- It contained 77 animations.
- Clothing and hair were embedded in the generated character rather than independently swappable.

These are observations from one generated output, not guarantees for all Ara outputs. Re-measure each new export.

## Immediate next implementation sequence

1. Recover and inspect the latest successful Ara GLB and the current Space viewer/build workflow.
2. Produce a machine-readable inventory of that GLB (meshes, material slots, bones, morph targets, animations, dimensions).
3. Establish the body/rig contract before creating tattoos, piercings or clothing dependencies.
4. Test a small representative accessory and tattoo workflow.
5. Only then expand the catalogue and build the Godot customisation UI.
