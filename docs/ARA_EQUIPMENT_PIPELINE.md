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

Ara exposes independent `hair` and `hairTint` parameters. The intended Silverhart approach is one geometry export per hairstyle and runtime material tinting, so colour options do not multiply export count. The current player creator stores a hairstyle choice but does not swap the hair mesh. Geometry extraction must preserve the character skeleton/skin weights and be verified against the pinned generator before it can safely replace hair at runtime. That extraction and selector integration remain outstanding; the current dropdown is not yet functional.
