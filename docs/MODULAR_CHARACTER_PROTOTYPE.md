# Modular character and fabric prototype

## Goal

Test whether Ara can supply a reusable character asset library for Silverhart Saga, rather than requiring one complete GLB per NPC. The prototype deliberately uses one adult Wren-shaped body definition and exports the body, hair, shirt and trousers as separate skinned GLBs.

This is a technical proof of concept, not yet the production character creator.

## What the build does

The workflow pins Ara 3D Gen to commit \`b60b5bece6d383d2cbb7067fd50e7c8e68b5a395\`, applies the small documented patch in \`tools/ara/patch_ara_clothing.py\`, and generates:

- A fully unclothed adult base body (including face, eyes, teeth and facial morph targets).
- A separate braid.
- A separate fatigue shirt.
- Separate fatigue trousers.
- Two complete comparison models: a translucent shirt and an open-weave lace shirt.

The component exporter selects Ara's material groups from separately generated body/garment builds, compacts the vertices, and writes independent skinned GLBs. It does **not** try to cut a shirt out of a fully clothed character: Ara hides the skin beneath opaque garments during generation, so doing that would leave holes in the base body.

The workflow checks that body, hair, shirt and trousers use the same ordered bone names and parent hierarchy. The private viewer then attempts to rebind the garment and hair meshes to the body skeleton and assemble them at runtime.

## The two fabric treatments

### 1. Translucent fabric

The shirt material uses glTF alpha blending at 42% opacity. The body remains present underneath it. This is appropriate for genuinely sheer fabric, but should be used selectively.

Godot's alpha-blended materials have real costs: overlapping transparent surfaces can sort incorrectly, and alpha-blended materials do not cast shadows. See the [Godot StandardMaterial3D transparency documentation](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html).

### 2. Open-weave lace

The existing Ara lace pattern is extended to produce an alpha mask: the raised cord and fine net remain opaque, while the gaps are discarded. The body remains present underneath.

This is a texture-based cutout, not literal holes cut into the garment's polygon topology. It is a useful first real-time approximation: alpha-masked materials avoid the usual alpha-blend sorting problem and can cast shadows. If the result needs close-up silhouette accuracy, the next test should be actual perforated garment geometry.

The opacity and lace pattern are independent from the shirt's colour values, so recolouring can be tested without generating another mesh.

## Important distinction: body customisation

Ara's complete export currently combines all material groups into one mesh node with multiple glTF primitives. The modular exporter proves that those material groups can be extracted into separate skinned assets, but it does not make every facial feature an independent object.

Nose, jaw, cheek and other facial appearance should be investigated as body morphs/modifiers. The facial morph targets in the current export are primarily expressions and speech shapes; they are not the same thing as appearance sliders.

## Acceptance checks

- [ ] The unclothed body is anatomically complete and imports into Godot.
- [ ] Hair, shirt and trousers assemble on the body without visible offsets.
- [ ] The separate components deform correctly during animation.
- [ ] The shirt does not clip badly at shoulders, waist, elbows or hips.
- [ ] The transparent shirt reveals the body and has acceptable sorting/shadow behaviour.
- [ ] The lace shirt reveals the body through its cutouts and has acceptable edge quality.
- [ ] Recolouring does not remove opacity or the lace pattern.
- [ ] The same components can be reused by another character with the same body/rig definition.

## Known limitations

- A shared skeleton does not guarantee that a garment fits every body shape. Fit across multiple body proportions remains a separate acceptance test.
- Body-region hiding is not yet implemented in the Godot runtime assembler. This matters for close-fitting clothing, armour, boots and overlapping layers.
- The lace test uses an alpha-cutout texture, not physical mesh openings.
- A single common rig and body topology are assumed. Different body proportions may require morph-compatible garments or a small number of supported body bases.
- The first prototype only proves one shirt, one pair of trousers and one hairstyle. It does not establish the size or completeness of a production wardrobe.

## Decision after the prototype

If the components assemble and animate correctly, build a small appearance catalogue and test it on at least three different body shapes. Only then decide whether Ara/MakeHuman can underpin the player creator, mercenary recruitment and the wider NPC population.

Do not generate 100 complete characters as the production asset strategy.
