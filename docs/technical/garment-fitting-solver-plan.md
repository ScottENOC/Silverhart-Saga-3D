# Garment fitting solver: implementation plan

## Status

Planning and integration contract only. This document does not claim that a production solver exists. The current `fit_garment_clearance()` routine in `tools/blender/add_adult_anatomy.py` performs a one-pass per-vertex push against a BVH built from the skin object. It does not enforce cloth strain, smooth displacement over garment topology, solve layer collisions, or produce a comprehensive fit verdict.

This work is based on the solver concepts reviewed from the Claude Code proposal: explicit garment intent, surface collision, skin clearance, topology-aware smoothing, bounded deformation, optional soft-tissue response, layer collision, and machine-readable fit reports.

## Scope and sequencing

### Stage 0 — preserve and establish a reproducible baseline

- Keep the current Wren bra attachment PR and source GLBs unchanged.
- Pin the exact Wren native build SHA, Ara generator revision, Blender version, and garment source in every report.
- Record the source garment's vertex/face counts, material names, object transforms, armature/skeleton identity, and world-space bounds.
- Classify skin faces by skin material only; never let garment faces become part of the body collision surface.
- Measure signed normal clearance and unsigned nearest-surface distance separately. A nearest-distance statistic alone cannot distinguish penetration from a garment floating away.
- Fail early when expected skin or garment material groups are absent or ambiguous.

### Stage 1 — deterministic geometric fitter

Implement a Blender-side fitter with a small, explicit configuration per garment family:

- `intent`: `drape`, `clearance`, `compression`, or `support`.
- target clearance in metres, with separate values for cups, bands, straps, briefs, and outer layers.
- maximum displacement per iteration and maximum cumulative displacement.
- garment topology adjacency, connected components, and seam/duplicate-vertex handling.
- iterative projection against the skin-only BVH, followed by topology-aware smoothing of displacement (not arbitrary smoothing of the original garment).
- re-query the skin surface after smoothing and repeat until tolerance or iteration limit.
- report vertices that cannot satisfy clearance within the displacement limit rather than silently clamping them.

Do not add tissue deformation in this stage. First prove the one-way garment solver on rigid/simple cases and on a simple garment exported from the actual Ara pipeline.

### Stage 2 — strain and construction constraints

- Preserve garment edge lengths within configured stretch/compression bounds.
- Report maximum and percentile edge strain, plus counts beyond the configured limit.
- Keep separate connected panels (cups, gore, underband, shoulder/neck straps, back band) so a solver cannot pull unrelated parts together.
- Use authored guide curves / anatomy regions to constrain garment roles. Do not infer cup and strap roles solely from centroid heuristics.
- Treat seams and lace trim as attached subcomponents of their parent panel.

### Stage 3 — layer collision

- Add explicit layer order (skin, underwear, shirt/dress, armour).
- Build collision references from the intended inner layer, not from the garment being fitted.
- Report inter-layer penetration and clearance independently from skin clearance.
- Verify transparent clothing does not hide or remove the body mesh.

### Stage 4 — optional soft-tissue response

Only after Stages 1–3 are stable:
- Add authored, bounded soft-tissue masks.
- Permit tissue displacement only in explicitly marked regions and within conservative limits.
- Report tissue displacement separately from garment displacement.
- Keep the original body unchanged when tissue response is disabled.
- Do not treat synthetic fixtures as proof of anatomical correctness.

## Fit report contract

Every run writes JSON with:

- source provenance and coordinate-system declaration;
- body and garment object/material identification;
- garment intent and configured clearances;
- vertex/face counts and connected-component counts;
- signed clearance min/median/p95/max;
- penetration count/depth and floating count/gap;
- displacement min/median/p95/max and vertices at the displacement clamp;
- edge-strain min/median/p95/max and out-of-range edge count;
- layer-collision metrics when applicable;
- solver iterations, convergence reason, and unresolved constraints;
- explicit result: `PASS`, `FAIL`, or `INCONCLUSIVE`.

A successful Blender process or successful GLB export is not a fit pass.

## Test gates

1. Pure algorithm tests for projection direction, signed-distance classification, displacement limits, convergence, and deterministic output.
2. Blender integration fixtures for skin-only surface selection, material classification, object/world transform handling, UV-seam duplicate vertices, and preserved body geometry.
3. Actual Ara simple-garment trial: inspect front/side/rear renders and compare pre/post metrics.
4. Actual Wren simple-garment trial: verify skeleton identity and transforms; compare poses as well as rest pose.
5. Only then run the solver on the Wren bra panels and guides.
6. Accept the bra only when the cups, gore, underband, neck straps, and back band are visually present and all fit-report constraints pass.

## Implemented in the initial foundation PR

- Stage 0 inventory: `inspect_fit_inputs.py` records materials, world transforms, mesh bounds, armature identity and bone names without changing the GLB.
- Stage 1 core: `solver_core.py` implements bounded iterative projection against a caller-supplied outward-oriented surface query, with garment-edge correction smoothing and deterministic reports.
- Blender adapter: `fit_glb.py` selects exactly one skin mesh by explicit material name, builds a skin-only world-space BVH, fits explicitly selected garment material groups, leaves the body untouched, and writes a candidate GLB plus JSON report.
- Unit tests cover projection, unchanged vertices, pinned vertices, displacement limits, invalid edges, invalid normals, floating vertices, adjacency smoothing and deterministic results.
- CI compiles the Blender scripts and runs the dependency-free unit tests.

The adapter is intentionally not wired into the production Ara/Wren garment pipeline yet. Real-asset inventory must pass first, then the fitter must be trialled on a simple garment with visual and geometric review. Stage 2 strain constraints, Stage 3 layer collision and Stage 4 soft-tissue response remain future work.

## Immediate next implementation

Run the inventory against the exact current Ara body GLB and latest native Wren GLB. Confirm the material names, skin mesh uniqueness, coordinate transforms and skeleton compatibility. Then apply the new fitter to a simple garment on Wren, compare before/after reports and renders, and only after that proceed to bra-specific panels. Do not alter the current bra mesh or tune its global transform to compensate for missing garment geometry.
