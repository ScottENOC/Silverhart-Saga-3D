# MakeHuman body morph integration

## Findings on 17 November 2026

- The native Ara export inspected contains 34 blend shapes: facial expressions and speech visemes. It does not expose the MakeHuman body sliders as GLB blend shapes.
- The current tools/blender/add_body_morphs.py creates six project-specific geometric blockouts (body_height, body_muscle, body_weight, body_breasts, body_legs, body_proportions). These are not imported MakeHuman targets and must not be described as the official morph library.
- The MPFB2 source repository contains 1,258 .target.gz files and ships its own src/mpfb/data/3dobjs/base.obj mesh (19,158 vertices).
- The native Ara GLB inspected in the successful Actions artifact has 69,878 position vertices. Its 34 morphs are face/viseme shapes.
- MakeHuman target files store sparse vertex-indexed offsets in X/Z/Y order, with the stored Y component sign-inverted. A target is meaningful only against its corresponding base-mesh vertex layout.

## Consequence

Do not apply MPFB target indices directly to an Ara GLB. The vertex counts differ substantially, and the Ara GLB is not demonstrated to have the MPFB base topology. A direct index-based application could deform unrelated parts of the character.

The anatomical Python pass sculpts the existing Ara mesh without changing its intended vertex layout, but that does not solve the mismatch between Ara's base and MPFB's target base.

## First implementation

tools/makehuman/target_format.py parses .target and .target.gz rows, converts the coordinate convention to XYZ, and can validate index ranges against a supplied vertex count. It deliberately does not apply targets to meshes.

Run its tests with:

    python -m unittest tests.test_makehuman_target_format

Inspect a target with:

    python tools/makehuman/target_format.py path/to/example.target.gz --vertex-count 19158

## Next engineering decision

Build a topology correspondence test between the exact Ara source mesh and MPFB's base mesh. If Ara's high-detail export is a subdivision/retopology of the same source, recover the source-to-export mapping and transfer each target's displacement through barycentric surface correspondence. If it is a different base mesh, either retarget the MPFB morphs onto Ara's topology or evaluate using the compatible MPFB base as the body foundation.

Only after a measured correspondence test should we add the real body targets to the runtime GLB and wire Godot sliders to them. Keep the six existing blockout keys separate as temporary prototypes.
