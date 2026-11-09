# Unified character assembly

Silverhart characters are assembled at runtime from three independent sources:

1. **Base body** — `art/characters/ara_runtime/ara_person_body.glb` or `ara_person_male_body.glb`. These are the anatomy-integrated adult Ara bases.
2. **Appearance profile** — the player profile or an entry in `data/characters/hollowmere_npcs.json`. It supplies body variant, body parameters, skin/eye/hair choices and hairstyle.
3. **Inventory** — `CharacterState` inventory/equipment. Clothing and armour select independent skinned meshes from `ara_person_garments.glb`; weapons, shields and helmets use the existing bone-attachment prop path.

The character's body is never hidden to simulate removing clothes. Garment meshes are separate nodes, initially invisible, and inventory equipment toggles their `visible` state. Garment meshes carry a `body_variant` tag (`female`, `male`, or `any`) so a fitted variant is preferred and a generic garment is used only when no matching body-specific mesh exists.

## NPC source data

- `hollowmere_npcs.json` is the authoritative personal appearance profile.
- `hollowmere_loadouts.json` defines starting weapon and armour inventory.
- NPC clothing inventory is created from the `top`, `underTop`, `underBottom`, `bottom` and `shoes` profile fields.
- `art/characters/hollowmere/*.glb` files are **asset-conversion inputs only**. Runtime spawning no longer loads these pre-dressed character models as the person's body.

## Build the garment library locally

The independent garment library is assembled from the existing NPC garment geometry, Ara modular exports and the anatomy-integrated shared skeleton. This is deliberately local Blender work, not a GitHub Actions job.

From the repository root, run:

```bash
python tools/build_ara_runtime_local.py
```

If Blender is not on PATH, set `BLENDER_BIN` to the installed Blender executable before running the command. The pipeline writes `art/characters/ara_runtime/ara_person_garments.glb` and updates the runtime manifest. Its intermediate cache is under `build/local-cache/ara`.

The Blender conversion checks that source skeleton bone names and ordering match the canonical Ara body, extracts clothing by material, and writes separate skinned objects named:

```text
Garment__<garment_visual>__<body_variant>__<piece>
```

The Godot actor attaches only the matching body variant (or an `any` fallback) and toggles each garment object from equipped inventory.

## Verify in Godot

After the local asset build and Godot import have completed:

```bash
"C:/Program Files/Godot/Godot.exe" --headless --path . --script tests/test_character_assembly.gd
```

The test checks both adult body variants, required inventory garment visuals, equip/unequip visibility, and that base-body mesh visibility is unchanged. It does not replace visual inspection in the running game.
