# Blender character finishing tools

These scripts run in Blender's background Python environment against exported GLB assets.

## Inspect a generated character

```bash
blender --background --python tools/blender/inspect_character.py -- --input character.glb --output-dir /tmp/character-review
```

The script imports the GLB, reports mesh/material/armature statistics, and renders front, side, rear and three-quarter review images. It is deliberately non-destructive.

## Adult anatomical finishing

`add_adult_anatomy.py` is a geometry-blockout utility for adult character assets. It adds a separate, clearly named anatomy mesh group to a copy of the imported model. It is not a substitute for a topology-aware sculpt pass: proportions, attachment, skin transitions and deformation must be reviewed in Blender before treating the result as final.

The anatomy profile is explicit (`female`, `male`, or `none`); the script rejects non-adult metadata. It does not infer anatomy from a character name or body slider. Use it only on adult base bodies, before clothing is fitted. Keep the anatomy meshes in the same armature/deformation workflow as the body before production use.

```bash
blender --background --python tools/blender/add_adult_anatomy.py -- --input adult_base.glb --output adult_base_anatomy.glb --profile female --adult
```

The generated blockout is intended for review and refinement, not sexualised presentation.
