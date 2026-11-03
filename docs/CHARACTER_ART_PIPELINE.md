# Character Art Pipeline

## Goal

Build a reusable 3D character system for Silverhart Saga 3D. The first character is Wren Talbot from Campaign 2's Hollow Tankard opening, but the result must be reusable for the player, companions and NPCs.

The intended presentation is a stylised, low-poly fantasy character with the visual equipment flexibility of a modern party RPG: the body is not a baked outfit, and changing equipped items changes the visible 3D model.

## Toolchain

- Blender is the authoring tool for meshes, UVs, materials, armatures and animation.
- Godot 4.7.2 is the runtime and scene assembly tool.
- Export reusable assets as glTF 2.0 / GLB.
- Keep Blender source files in Git LFS; keep small scripts, item definitions and Godot resources in normal Git.
- A Blender Python build script can create repeatable blockouts and validation assets. It is not a substitute for artist-authored final meshes.

## Character architecture

1. **Shared humanoid skeleton** — one canonical human rig, with stable bone names and attachment points. Characters use compatible proportions or controlled proportion variants; do not create a bespoke skeleton per NPC.
2. **Body mesh** — skin, head, hands and feet. It is independent of clothing.
3. **Hair** — separate meshes attached to head bones. Hair style and colour are character appearance data.
4. **Garments** — independently skinned meshes for underlayers, shirts, trousers, boots, gloves, cloaks and other clothing.
5. **Armour** — independently skinned meshes in their equipment slots. Armour can replace or cover garment regions without changing the character's identity or inventory data.
6. **Weapons and held equipment** — separate meshes attached to hand/weapon sockets; shields and back-carried items use their own attachment points.
7. **Appearance/equipment definition** — simulation data stores item IDs and colour/material variants. The presentation layer resolves those IDs to Godot scenes/resources and displays them. It must never become the authority for what is equipped.

Clothing and armour should be fitted to the same underlying rig. Where garments overlap, use deliberate layering and body-region hiding/masks to prevent skin or lower garments poking through. Do not rely on simply stacking several identical surfaces.

## Initial visual equipment slots

The original game has separate gameplay equipment and clothing. Preserve that distinction while allowing both to contribute to the rendered appearance.

Initial visual categories:
- Head / helmet
- Hair
- Face accessory
- Torso underlayer
- Torso / shirt
- Torso armour
- Outerwear / cloak
- Waist / belt
- Legs / trousers
- Hands / gloves
- Feet / boots
- Main-hand weapon
- Off-hand / shield
- Neck and other accessories

An item definition should specify its logical equipment slot, visual asset, compatible rig/body variants, layering behaviour, and any body regions it hides. A cosmetic garment must not accidentally grant armour stats; an armour piece must not be merely a recoloured shirt.

## Wren Talbot — source appearance

The original Campaign 2 code creates Wren as a human, female fighter, with the average body type. The authored appearance preset is `scenario2_wren_v2`.

| Part | Original item / setting | Notes |
|---|---|---|
| Hair | Braid | Hue 218, saturation 71, value 56 (muted dark blue) |
| Skin | Natural tone slider 50 | Midpoint of the original game's natural skin-tone ramp |
| Shirt | `top_shirt_f` | Dark green main layer; bright pink-red trim |
| Trousers | `pants_lattice` | Very dark charcoal |
| Underlayer | `underwear_bra_strapless` | Dark ochre base with pale trim; normally covered |
| Underlayer | `underwear_briefs` | Dark ochre base with pale trim; normally covered |
| Weapon | `sword` | Starting fighter weapon |
| Armour | None equipped by the authored start | Do not invent armour for the first model |
| Off-hand / helmet | None | Keep empty |

The original 2D clothing source images are separate front/side/back layers, not a complete character illustration:
- `images/equipment/clothing/top_shirt_f_front.png`, `top_shirt_f_side.png`, `top_shirt_f_back.png`
- `images/equipment/clothing/pants_lattice_front.png`, `pants_lattice_side.png`, `pants_lattice_back.png`
- `images/equipment/clothing/bra_strapless_front.png`, `bra_strapless_side.png`, `bra_strapless_back.png`
- `images/equipment/clothing/briefs_female_front.png`, `briefs_female_side.png`, `briefs_female_back.png`
- `images/equipment/weapons/sword.png`

These are references for the 3D interpretation, not textures to stretch directly over a 3D body. Preserve the recognisable colour blocking and garment identity, while designing proper 3D cloth shapes.

Source implementation in the original repository:
- `campaign2World.js`: Wren creation and starting skills.
- `characterCreation.js`: base character defaults and fighter's starting sword.
- `appearancePresets.js`: the complete `scenario2_wren_v2` appearance preset.

## First modelling milestone

Create a first reusable human female body/rig and Wren's starting appearance:
- Neutral standing pose, plus a seated pose suitable for the tavern opening.
- Head, hands and feet included; no facial animation requirement yet.
- Braid, shirt, trousers and sword as separate assets.
- Underlayers represented as real separate garment slots, but hidden beneath outer garments in the normal outfit.
- No armour, helmet or shield on Wren at the start.
- Neutral lighting and a turntable/test scene so proportions, silhouette and garment fit can be inspected from all sides.

The first pass is a proportion-and-fit prototype, not final character art. Validate the skeleton, scale, clothing changes and Godot import pipeline before investing in detailed materials, facial work or a large wardrobe.

## Non-goals for the first pass

- Do not model every race/body type or the whole wardrobe.
- Do not bake equipment into Wren's body.
- Do not create separate bespoke skeletons for every character.
- Do not implement full cloth simulation. Use authored meshes and simple secondary motion later if needed.
- Do not port the original Canvas sprite renderer or its pixel-layer geometry into Godot.
