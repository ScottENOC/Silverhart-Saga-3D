# Body-derived garment shell prototype

This module ports the central Ara garment-construction idea into a small,
testable Python geometry core: garments are cut from the character's own body
surface using a signed coverage field, offset along surface normals, and given
a turned-in boundary rim. It does not try to push an imported garment mesh
through the body after the fact.

## Geometry contract

- Supply body-space vertices, vertex normals, polygon faces and one signed
  coverage value per body vertex. Positive means covered; the zero contour is
  the garment cutline.
- The core clips each face at the contour and caches edge intersections, so
  adjacent faces share cut vertices instead of creating cracks.
- The selected surface is offset by a constant or per-vertex distance.
- Boundary edges receive a rim that returns toward the skin.
- Every generated vertex carries a source reference: either an original body
  vertex or an interpolated source edge. A Blender/Godot adapter can use that
  reference to transfer skin weights, morph deltas, UVs and other attributes.

The core deliberately does not yet choose anatomical coverage regions or
export a rigged GLB. Those belong in a host adapter and a garment-specific
coverage definition. In particular, the standard Ara briefs must be driven by
a pelvis/upper-leg coverage field and checked against Wren's anatomy; a generic
height threshold is not an acceptable substitute.

## Validation

Run:

```sh
python -m unittest discover -s tools/blender/garment_shell -p 'test_*.py' -v
python -m py_compile tools/blender/garment_shell/shell_core.py
```

This is a geometry prototype, not yet a replacement for the failed Wren briefs
fit workflow. It intentionally leaves the original body and garment assets
untouched.
