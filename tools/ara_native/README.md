# Native Ara garment generation

This folder vendors and runs Ara 3D Gen's original swimwear garment source locally.

- Upstream: https://github.com/olatunde85/3d-gen
- Exact source revision: `b60b5bece6d383d2cbb7067fd50e7c8e68b5a395`
- Source licence: MIT; see [vendor/LICENSE](vendor/LICENSE).
- MakeHuman fitting data: CC0 1.0; downloaded at a pinned revision by the workflow.

`generate-wren-bikini.ts` runs Ara's actual `bikini_top` and `bikini_bottom` builders with Wren's `character-preview/wren-ara.json` morph profile. It does not call Ara's CLI or hosted service. The generated top is 50% opacity gold foil; the bottom is black foil. Ara's optional skin-hide masks are deliberately not applied.

`build-fitting-data.ts` builds the base topology, semantic vertex regions, joints, slider catalogue and morph target packs from the pinned CC0 MakeHuman source data.

The workflow then attaches the resulting independent garment mesh to the accepted `art/characters/companions/wren.glb`. The accepted Wren body and armature are preserved; a garment-only surface correction uses the accepted skin mesh as a collider. The correction is bounded and reported so that a coordinate mismatch cannot silently produce an extreme fit.

The generated garment is currently a static preview mesh, not yet weighted to Wren's skeleton for runtime animation. A successful geometry/render check is not a final fit approval: inspect the uploaded front, side, three-quarter and pelvis views, especially where the accepted Wren sculpt differs from Ara's morph-only base.
