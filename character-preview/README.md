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

The first profile is Wren-oriented and deliberately uses existing repository assets only. Per-character clothing selections are stored separately in `outfits.json`; this keeps starting equipment independent of the Ara body profiles and anatomy settings. Wren's current requested outfit is a black Ara triangle bikini top and black string bikini bottom, both at 50% opacity. The loadout is authored but is not yet consumed by this Blender preview renderer; garment fitting and outfit rendering remain a separate validation step.


## Modular clothing fit review

`companion-models.json` pins the actual companion GLB artifacts used for modular garment fitting. Wren #103 is the approved, locked body source. Dagna #56, Reyna #103, Aldric #90 and Mirabel #96 are the latest successful source builds available for this review and remain subject to their separate body approval.

The clothing workflow attaches independent Ara garment primitives to copies of those GLBs. Female clothing fitting runs in Blender's `--fit-existing` mode, which adjusts garment vertices only; it does not regenerate or sculpt the companion body. Aldric is used for a male-rig attachment compatibility check, not fitted with the female underwear catalogue.

Wren's black triangle bikini top and string bikini bottom at 50% opacity are stored in `outfits.json` as a separate loadout. Her body profile and approved GLB are not edited.
