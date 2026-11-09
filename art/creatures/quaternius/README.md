# Quaternius creature assets

Drop the downloaded and extracted Quaternius animal pack files into this folder.

## Suggested layout

Keep each pack separate and preserve its original internal folder structure. In particular, do not separate a `.gltf` file from its referenced `.bin` file, textures, or animation files.

```text
art/creatures/quaternius/
  README.md
  ultimate_animated_animals/
    ... extracted pack contents ...
  farm_animal_pack/
    ... extracted pack contents ...
```

## Import notes

- Prefer the glTF version of Ultimate Animated Animals where the pack provides it.
- Keep all model, material, texture, skeleton, and animation files together.
- Do not rename files or reorganise the pack internals until the models have been tested in Godot.
- Import the extracted assets into Godot from this location; Godot will generate its own local `.godot/imported` cache.
- Do not commit the downloaded ZIP archives or Godot's generated import cache.
- Keep the pack's included licence/readme files with the assets. Quaternius distributes these packs under CC0; retain the licence information as provenance.

## Planned use

These are source assets for reusable creature scenes (farm animals, wildlife, and potential mounts). Preserve the original skeletons and animation clips; do not retarget them to Ara's humanoid rig.
