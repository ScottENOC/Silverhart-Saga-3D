# Native Ara garment generation

This folder vendors and runs Ara 3D Gen's original swimwear garment source locally.

- Upstream: https://github.com/olatunde85/3d-gen
- Exact source revision: `b60b5bece6d383d2cbb7067fd50e7c8e68b5a395`
- Source licence: MIT; see [vendor/LICENSE](vendor/LICENSE).

`export_wren_ara_body_surface.py` reads the accepted `art/characters/companions/wren.glb` and exports the actual skin geometry, semantic regions, rig landmarks and polygon topology in Ara's coordinate system. It also adds every body-piercing mesh to the fitting surface. Piercings remain independent scene objects in the character GLB; their geometry is included in Ara's surface projection so fabric is generated over them.

`generate-wren-bikini.ts` runs Ara's original `bikini_top` and `bikini_bottom` builders directly against that accepted Wren surface. It does not create a MakeHuman proxy body, apply a morph-only approximation, or call Ara's CLI or hosted service. The generated top is 50% opacity gold foil; the bottom is black foil. Ara's optional skin-hide masks are deliberately not applied.

The Ara projection code accepts the accepted GLB's variable polygon topology rather than assuming MakeHuman's quad layout. Breast landmarks are taken from the actual nipple-piercing bar geometry where present; the opposite landmark is mirrored only when the corresponding piercing is absent.

The Blender attachment step is deliberately geometry-preserving: it adds Ara's generated garment as an independent mesh and verifies that the fitting surface hash matches the exact accepted Wren GLB. It performs no post-generation vertex projection, panel extension or other corrective deformation.

The generated garment is currently a static preview mesh, not yet weighted to Wren's skeleton for runtime animation. A successful geometry/render check is not final fit approval: inspect front, back, side, three-quarter and close-up views, especially around the piercing and garment coverage.
