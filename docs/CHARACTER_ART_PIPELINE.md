# Character Art Pipeline

## Goal

Build a reusable 3D character system for Silverhart Saga 3D. The first character is Wren Talbot from Campaign 2's Hollow Tankard opening, but the result must be reusable for the player, companions and NPCs.

The intended presentation is realistic fantasy RPG, with artistic restraint rather than photorealism, and the visual equipment flexibility of a modern party RPG. The body is not a baked outfit; changing equipped items changes the visible 3D model.

The first production-quality benchmark is Wren Talbot: a slim, lightly athletic adult woman, natural approachable face, distinctive dark-blue braid, dark-green shirt with pink-red trim, charcoal trousers and a sword. The benchmark must be assessed at normal game camera distance and close inspection distance.

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


## Modular appearance: required behaviour

Hair is a first-class appearance slot, not part of the body mesh. The same applies to brows, facial hair, clothing, armour and accessories. A character may change hairstyle, hair colour, clothing or equipment during play without replacing their body or identity.

The runtime assembly should be composed from independently addressable visual components:
- A character root and shared skeleton.
- One body resource, with body proportions/shape data where needed.
- One selected hairstyle resource, attached/skinned to the head.
- Optional additional hair pieces (fringe, ponytail, braid, beard) where a style is authored from multiple meshes.
- Independently selected garment and equipment resources.
- Optional appearance overlays such as scars, tattoos and dirt.

Each component needs a stable resource ID and compatibility metadata: rig version, supported body variant, attachment/skinning method, visual slot, and any regions it covers. Appearance state should store IDs and colour parameters, not hard-coded mesh node names. Changing a hair style should replace only the hair component; it must not recreate the character, reset animation, or affect inventory/equipment.

Hair can be a single mesh or a small group of meshes. It does not need to be split into one resource per strand. The important separation is between hair and the underlying head/body, and between independently selectable styles.

### Current prototype status

The current Blender generator creates hair as separate mesh objects weighted to the Head bone, so it is already geometrically separate from the body. However, the current exported wren_blockout.glb packages the whole character together and the Godot scene loads it as one model. There is not yet a runtime appearance-slot system or independently swappable hairstyle resources.

Therefore, the architecture is planned for modular hair, but the current implementation is not yet capable of changing Wren's hairstyle in-game. Before producing a wardrobe, split the Blender source into independently exportable body, hair and weapon components, then implement a Godot character assembler that attaches compatible resources to the shared skeleton. Garments and armour can use the same mechanism.


## Modular asset export and runtime assembly

The Blender source remains the authoring source, but exported GLBs are split by visual slot. Run `tools/blender/export_character_components.py` after generating/opening the Wren blend file. The exporter uses mesh-name prefixes and includes the canonical armature with each skinned component:

| Prefix | Export | Runtime slot |
|---|---|---|
| `Body_`, `Face_` | `body.glb` | Base body |
| `Hair_` | `hair_braid.glb` | Hair |
| `Weapon_` | `weapon_sword.glb` | Main-hand weapon |
| `Garment_Torso_` | `garment_torso_base.glb` | Torso garment |
| `Garment_Legs_` | `garment_legs_base.glb` | Leg garment |
| `Armour_Torso_` | `armour_torso_base.glb` | Torso armour |
| `Armour_Legs_` | `armour_legs_base.glb` | Leg armour |

Empty future slots are skipped by the exporter; they are not placeholder geometry. New hairstyles can use additional IDs and paths in the assembler catalog. A hairstyle may comprise several meshes but is replaced as one logical slot.

Godot's `ModularCharacterAssembler` instantiates the body first and uses its Skeleton3D as the canonical rig. It then imports optional component scenes, moves their MeshInstance3D nodes into slot mounts and rebinds their skeleton paths to the shared skeleton. This depends on every component being exported from the same canonical armature with exactly matching bone names/order and compatible bind poses. Do not apply different armature transforms or rename/reorder bones between exports.

The assembler exposes `configure(appearance)`, `set_component(slot, id)`, `clear_slot(slot)` and `get_appearance()`. Appearance IDs are presentation data; the simulation/inventory remains authoritative. Slots are generic enough for multiple hairstyles, garments and armour pieces. Body-region hiding/masking and garment layering still need to be implemented as the wardrobe grows.

### Current implementation boundary

Wren's Hollow Tankard actor now uses the assembler with the braid and sword slots. The Blender component exporter and Godot assembler are committed, but the new component GLBs must be generated locally and imported by Godot before the modular model can appear. The current blockout has no authored garment or armour meshes yet; the exporter and runtime slots support those future assets, but do not pretend that clothing/armour geometry already exists.

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


## Additional appearance layers

The Wren prototype now exports independently swappable cosmetic layers:
- `body_hair`: a groomed pubic-hair style, separate from the skin/body mesh.
- `tattoo`: a five-point star on the shoulder opposite the braid.
- `piercings`: paired ear hoops and a left-nipple hoop.

These are separate GLBs and runtime appearance slots, not baked into the body. Wren's starting appearance config equips the current examples. Other characters can omit them or choose different IDs. Hair colour is a material variant and should ultimately be stored as an appearance colour parameter rather than duplicated hairstyle geometry.

The current Blender shapes are still procedural blockout art. Tattoo linework, piercings and body hair need visual inspection in Godot for surface placement, deformation and material scale before they are treated as final assets.


## Wren inspection pass — November 2026

- Camera yaw remains unrestricted for a full horizontal orbit. Pitch travels from overhead towards the horizon, with its lower limit calculated from zoom distance and camera-pivot height so the camera stays above the ground. Close inspection has a 1.4 m minimum zoom.
- The navel is a depression in the torso loft, not a separate colour mark.
- The braid crosses the shoulder and hangs down the front to chest level; swept locks and strand geometry break up the smooth scalp cap.
- Hands are rebuilt with fingers curling around the sword axis. Fingers are still fixed-pose meshes, not individually animated finger bones.
- Body hair, piercings and the shoulder star tattoo remain independent appearance components.


The latest Wren mesh pass also adds a shallow integrated pelvic contour to the torso loft and positions the separate body-hair component just outside that surface. It is intended to remain a subtle anatomical sculpt rather than a raised, pasted-on object.


## November 4 — feet, pelvis and hand rig refinement

The latest Wren generator pass:
- Extends the lower torso/pelvic loft into the upper-thigh transition and increases voxel-remesh resolution/smoothing to reduce the hard crotch seam.
- Moves the integrated pelvic surface contours and the separate groomed body-hair component lower on the body.
- Clamps foot underside vertices to a shared sole plane and adds distinct ankle bones/geometry.
- Adds wrist bones and three phalange bones for each finger and thumb. Finger mesh segments are weighted to their corresponding bones; the current grip remains a posed prototype, not a finished animation rig.
- Keeps areola and nipple meshes outside the body remesh so their material distinction survives; lowers them on the breast profile and adjusts the piercing position.
- Widens the mouth.
- Adds raised scalp flow-lines in a contrasting blue and replaces the bead-like braid with a continuous core and three interweaving lobes.

These changes require local Blender generation and Godot inspection. The procedural geometry is still a blockout; verify the mesh visually and inspect the rig in Blender before relying on finger articulation in animation.


## Wren hand, pelvis and tattoo adjustment

The latest blockout pass:
- Moves the areolae/nipples halfway back towards their previous position and moves the nipple hoop with them.
- Flattens the palm and creates each finger as one continuous mesh with blended weights across three phalange bones. The thumb has two phalange bones.
- Extends the lower torso loft into a tapered crotch bridge and shifts the separate body-hair layer lower.
- Clamps the lowest fused foot vertices to a common sole plane after remeshing.
- Replaces the dragon tattoo with a five-point star on the shoulder opposite the braid.

These remain procedural forms. The sword grip should be checked from several angles in Godot; the hand is posed around the grip but does not yet dynamically animate around it.


## November 4 — continuous joint anatomy pass

The current body generator no longer uses separate shoulder, kneecap or ankle spheres. Those forms are now produced by the continuous arm and leg lofts before the unified body remesh:

- Shoulders begin with a buried root section inside the torso, widen into a sloping deltoid cap, then taper into the upper arm.
- Knees use a shallow, localised anterior surface deformation over the patella region, with the thigh and calf profiles shaping the joint.
- Ankles use small inner and outer malleolar surface deformations at different heights. Their directions are mirrored for left and right legs.
- Wrists retain a tapered forearm-to-palm bridge, with subtle asymmetric contour changes rather than a round joint object.

These are deliberately restrained first-pass anatomical cues. They need inspection in the neutral clay preview from front, side and rear, followed by deformation tests in Blender. The current procedural surface is still a blockout and should not be treated as finished anatomy.

## Wren undergarments — first modular clothing pass

The original 2D source assets were inspected directly:
- `bra_strapless_front/back.png`: strapless two-cup bra, ornate lace-like cup pattern, central connector and a broad back band.
- `briefs_female_front/back.png`: full-coverage briefs with a shaped, high-cut leg opening and contrasting waistband/edge detail.

Wren's `scenario2_wren_v2` preset applies the same two-colour palette to both items: dark layer hue 55 / saturation 58 / value 20, with light trim hue 47 / saturation 100 / value 100. The 3D material values are an approximation of those authored colour parameters, not a literal sampling of the original pixel art.

The first 3D garment pass is authored as two independent skinned components:
- `underwear_bra.glb` — separate cups, bandeau band, pale piping, lace-inspired surface detail and centre clasp.
- `underwear_briefs.glb` — separate front and rear cloth panels with a shaped lower edge and contrasting waistband.

Godot appearance slots are `underwear_bra` and `underwear_briefs`; each can be cleared or equipped independently. The Hollow Tankard prototype exposes separate Bra and Briefs toggles. When briefs are enabled, the optional body-hair appearance layer is hidden; turning briefs off restores that layer. These controls are presentation-only at this stage and do not change inventory or gameplay equipment state.

This is deliberately a fit-and-layering prototype, not final cloth simulation. The next validation is to check the garments from front, side and rear in Godot, correct any intersections, then add body-region hiding so future shirts and trousers cleanly cover the underlayers.


## Wren first-pass underwear and appearance customisation

Wren's original 2D preset (`scenario2_wren_v2`) defines both bra and briefs with:
- Main fabric: HSV 55°, 58% saturation, 20% value, 75% layer opacity (dark ochre).
- Pale trim: HSV 47°, 100% saturation, 100% value, fully opaque.

The first 3D pass uses the same dark ochre and pale gold palette. The briefs use actual open mesh cells in a repeating lace-like pattern, so the gaps reveal the body behind them rather than relying on a second body render. The bra and briefs remain separate components and can be toggled independently.

Clothing colour and opacity are material properties, not baked into a body texture. `ModularCharacterAssembler.set_component_layer_colour(slot, layer_name, colour, opacity)` provides per-mesh-layer runtime tint/opacity. For example, the bra cups, cup trim, briefs front/back and waistband trim can be controlled independently. Cut-outs remain geometric holes and are unaffected by colour changes. No duplicate body model is needed for clothing colour variants.

The authored Wren bra preset is explicitly `underwear_bra_strapless`: it should be a bandeau/strapless bra with a continuous under-bust band, not shoulder straps. If a later item uses shoulder straps, those will be separately modelled and must attach to the cup geometry and follow the body's surface.
