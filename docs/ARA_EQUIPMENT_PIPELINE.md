# Ara character and equipment asset pipeline

## Separate medieval hand props

The pinned Ara 3D Gen source has a grip-origin prop pipeline and a WeaponR rig socket. Silverhart patches that pinned checkout during the build (the upstream source is not vendored) to add:

- sword and knife (Ara originals)
- axe, spear, bow, mace and wooden club (Silverhart procedural additions)

Each is exported as its own GLB prop, with the origin at the hand grip. The props are colour/material independent: equipment variants such as the Starforged Blade can reuse the sword mesh and apply a different material treatment at runtime.

The manual GitHub Actions workflow, Build Ara Medieval Props, produces these exports on demand. It is deliberately separate from the main Wren Workshop workflow so ordinary builds do not incur seven extra Ara generator runs. It uploads a versioned prop bundle and runs a Godot import smoke test.

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

## Next equipment attachments

The current Ara prop socket is for the right hand. Shields need a dedicated left-hand/off-hand attachment and helmets need a head attachment. They should be exported and attached independently rather than baked into a full character GLB. The next asset pass should add round, kite and heater shields, plus a nasal helm, kettle hat, great helm and bascinet, with a fit check against both male and female Ara bodies.

## Hairstyles

Ara has independent hair and hairTint parameters. The pinned generator exposes MakeHuman styles plus procedural buzz, mohawk, cornrows and box braids. The intended Silverhart implementation is one geometry export per hairstyle and runtime material tinting; no per-colour Ara exports are required. The hair export/extraction and runtime selector are a separate step from this hand-prop build.
