# Ara character and equipment asset pipeline

## Separate medieval hand props

The pinned Ara 3D Gen source has a grip-origin prop pipeline and a WeaponR rig socket. Silverhart patches that pinned checkout during the build (the upstream source is not vendored) to add:

- sword and knife (Ara originals)
- axe, spear, bow, mace and wooden club (Silverhart procedural additions)

Each is exported as its own GLB prop, with the origin at the hand grip. The props are colour/material independent: equipment variants such as the Starforged Blade can reuse the sword mesh and apply a different material treatment at runtime.

The manual GitHub Actions workflow, **Build Ara Medieval Props**, produces these exports on demand. It is deliberately separate from the main Wren Workshop workflow so ordinary builds do not incur seven extra Ara generator runs. It uploads a versioned prop bundle and runs a Godot import smoke test.

## Standalone armour blockouts

A second manual workflow, **Build Ara Medieval Armour Props**, creates three shield silhouettes (round, kite and heater) and four helmet silhouettes (nasal helm, kettle hat, great helm and bascinet) as independent GLBs using Blender. These are intentionally first-pass blockout meshes, not fitted or approved equipment. Their attachment origins and dimensions need review against the actual male and female Ara character exports before runtime use.

Shields are intended for a left-hand/off-hand attachment; helmets for a head attachment. They must remain independent from the character body so equipment can be changed without regenerating a person. The current actor does not yet attach these props.

## Existing game item mapping

| Game item IDs | Visual asset |
|---|---|
| sword, starforged_blade, sword_arrow_deflection | sword |
| dagger, featherweight_dagger | knife |
| axe | axe |
| spear, stormcaller_spear | spear |
| bow, hunting_bow, nightowl_bow | bow |
| club, ashenwood_club | club |
| (future) mace | mace |
| wooden_shield | round_shield |
| nasal_helm | nasal_helm |

The other shield and helmet assets are additional visual variants for future catalogue entries.

## Hairstyles

See [ARA_HAIR_PIPELINE.md](ARA_HAIR_PIPELINE.md). Hair is extracted from Ara's material groups with its skin weights preserved, exported as standalone skinned GLBs, and selected in the player creator. Hair colour is applied as a runtime material tint. The manual/branch-triggered build workflow validates the generated meshes before committing them to the feature branch.


## Selected standalone Ara garments (existing generated exports only)

The runtime does not need the full MakeHuman/Ara clothing catalogue. Extract only the
small set already present in `build/local-cache/ara/generated`:

- Lace and fishnet briefs
- Lace and fishnet pants
- Lace and fishnet shirts
- Lace and fishnet halter bras
- Leather armour (including its separate pauldron primitives)

Run the extraction helper from the repository root:

```bash
python tools/ara/extract_selected_garments.py --dry-run
python tools/ara/extract_selected_garments.py
```

It reads the existing full-character GLBs, retains only non-body garment materials,
and writes independent skinned meshes to
`art/characters/ara_runtime/garments/female_<garment-id>.glb`. It does not invoke
Blender, download anything, regenerate anatomy, or alter the source exports. The
base body remains a separate runtime asset.

The legacy equipment visuals `bra` and `briefs` resolve to the lace halter bra and
lace briefs by default. Explicit visuals `halter_bra_fishnet`, `fishnet_briefs`,
`lace_pants`, `fishnet_pants`, `lace_shirt`, and `fishnet_shirt` select their
matching independent assets. The leather armour item resolves to
`female_leather_armor.glb`.
