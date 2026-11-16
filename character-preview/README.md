# Character preview workflow

This is a Blender-only preview loop for the actual Ara GLB assets. It does not launch Godot and does not generate an AI approximation.

## Change a character
Edit `character-preview/profile.json` on `dev_2`, then commit/push. A GitHub Action renders three PNG views and uploads them as a downloadable workflow artifact (14-day retention).

Supported profile fields:
- `name`: label shown in the report
- `model`: repository-relative GLB body/model path
- `hair_asset`: optional repository-relative hair GLB path (empty string disables separate hair)
- `shape_keys`: exact Blender shape-key names and values (for example `body_breasts: 0.35`)
- `material_tints`: material-name substring to hex colour mapping (for example `Skin: "#a1845b"`)
- `hide_materials`: optional material-name substrings to hide

The first profile is Wren-oriented and deliberately uses existing repository assets only. Garment/equipment selection will be added against the repo's modular outfit material inventory after the first render confirms which surfaces are in the selected model.
