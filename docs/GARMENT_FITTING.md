# Garment fitting architecture

## Purpose

A garment is authored with its own pattern and material behaviour; a character
provides an individual body surface, landmarks and shape. The fitting system
must adapt the garment to the character without changing the approved source
body or destroying intentional garment openings.

The fitting pipeline has two outputs: a fitted garment and a fit report. The
source character body remains the authority.

## Material profiles

The shared policy lives in `tools/ara/garment_fit.py`. It is deliberately
independent of Blender so material classification and hard limits can be
tested in ordinary Python.

| Profile | Examples | Fit behaviour |
| --- | --- | --- |
| `stretch_fabric` | briefs, bikini fabric, shirts | Moderate stretch; modest body compression |
| `open_mesh` | lace, fishnet | Preserve authored holes; lower compression |
| `structured_bra` | standard bra, bustier, corset | Lower stretch; controlled support/compression |
| `rigid` | plate armour, rigid accessories | Essentially no stretch or body compression |
| `loose_drape` | dresses, skirts, cloaks | Low material strain; preserve drape and openings |

Each fabric profile defines comfortable and hard strain limits, a compression
limit, body clearance, maximum unintended gap and texture response. Construction
is resolved independently. This matters for a lace or fishnet bra: it is still
open mesh (so its holes and texture must survive), but its cup perimeter,
underbust band and straps are constrained support features. The system must not
force that garment into either a generic lace profile or a generic solid-bra
profile and lose the other half of its behaviour.

Exceeding a hard strain limit must eventually fail fit validation or request
another size/pattern; it must not silently stretch without limit.

## Fitting stages

1. **Correspondence** — map garment vertices and pattern edges to stable body
   landmarks and body-surface regions. Record which body region each panel
   belongs to.
2. **Material-aware fitting** — distribute the required change across the
   garment according to its material profile and seam/edge constraints.
   Stretch is bounded by the profile's hard strain limit.
3. **Coverage and collision** — resolve unintended body intersections and
   accidental gaps while preserving intentional cut-outs, lace holes, fishnet
   openings and exposed edges. Collision clearance alone is not a coverage
   solution.
4. **Compression** — generate a reversible, local body-fit deformation under
   garments. Prefer Ara morph targets or a generated character-specific body
   morph over arbitrary vertex pushes. Do not modify the approved source GLB.
5. **Validation and bake** — measure penetration, unintended gaps, strain,
   seam continuity and strap continuity; bake the character-specific result
   for runtime. Retain a small runtime correction path for animation and morphs.

## Current implementation

The first vertical slice is in place:

- Material names resolve to shared, explicit fabric profiles.
- Fabric behaviour and garment construction are separate axes. For example,
  fishnet halter bras retain open-mesh texture behaviour while exposing
  structured cup/underbust/strap constraints.
- A Blender-independent landmark correspondence module maps garment points to nearby body anchors with normalised weights, transfers body-shape landmark deltas to garment points, and rejects implausibly distant matches.
- Profiles define bounded strain, compression, clearance, coverage and texture
  response policies.
- The existing Blender anatomy fitting pass now uses profile-specific body
  clearance rather than one hard-coded upper/lower clearance value.
- The pass logs the number of affected vertices, initial penetrations and
  correction distances for each material profile.
- Pure-Python unit tests cover material resolution, profile isolation, strain estimation, threshold classification and landmark correspondence.
- The existing body-unchanged validator remains a mandatory gate after
  modular garment assembly.

This is intentionally not yet full cloth simulation. The current geometry
adapter still performs a conservative surface-clearance correction and reports
an approximate local strain induced by that correction. The correspondence
module is currently a tested primitive; the Ara Blender adapter does not yet
supply live landmark positions or apply those weights to garment meshes. The
pipeline does not yet solve panel stretch, pattern deformation, gap filling or
body compression. Those are subsequent stages, and must be introduced with
measurable acceptance tests rather than hidden inside a generic offset.

## Required test matrix

Fit each garment class against deliberately different body shapes, not just
the Ara default:

- bust projection and separation;
- shoulder width and torso length;
- waist-to-hip ratio;
- body mass/softness;
- upper-leg and pelvis proportions.

A successful fit must keep body penetration and unintended gaps below the
profile limits, keep strain below the hard maximum, preserve authored openings,
and maintain seam/strap continuity. Test static poses first, then arms raised,
twisting, bending and walking. Review front, side and rear renders before
approving an asset.
