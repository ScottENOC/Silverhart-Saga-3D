# Character cloth and contact simulation architecture

## Design target

The fitting pipeline and eventual game runtime share one physical model. Garments
are not pushed away from the body by a one-off clearance script. The accepted
body, garment surfaces, accessories and other characters remain distinct
geometry with explicit collision and deformation roles.

## Solver order

Each substep uses this order, repeated over solver iterations:

1. Integrate animated pose, gravity and inertial motion.
2. Resolve non-penetration contacts against body, piercing, armour, equipment
   and other characters.
3. Solve garment stretch and shear constraints.
4. Solve bending constraints.
5. Solve reinforced seam constraints (waistbands and leg-opening elastic).
6. Apply compliant body response, then repeat contact resolution.
7. Run a final contact pass so elastic forces cannot pull cloth back through a
   collider.

The XPBD core in `tools/cloth/xpbd_solver.py` supplies timestep-stable distance
constraints, signed-distance contact projection, two-sided contact weighting,
and a nonlinear hardening response. The collision provider is deliberately an
adapter: it must query actual Blender/Godot collision geometry, not guessed
spheres or hand-authored vertex offsets.

## Fitting versus wearing

Cross-character fitting is a separate magical-tailoring operation, not a
simulation of the source material under impossible physical strain. A garment
may scale, reshape, redistribute volume and reposition panels to fit a new
body. Material presets guide the resulting rest shape and later motion, but do
not forbid fitting transformations: plate armour can widen at the shoulders
and narrow at the hips, then become a new articulated rest shape.

Once fitted, the garment's rest shape is frozen for that wearer. Runtime
simulation then governs movement, gravity, contact with the body and objects,
and secondary motion. Fabric flexes; cords retain their tubular cross-section;
rigid armour moves as articulated plates with constrained joints rather than
stretching like fabric.

The current Wren fitting pass is an offline static rest-shape candidate. Its
body collider is a separate collision-only shell built from the accepted Wren
skin. Open boundary loops are capped on that copy, and the build fails if the
result remains open or non-manifold. The visible Wren mesh is never edited by
this operation. The Ara adult-anatomy fitting reference is not used as Wren's
collision source.

## Layers and material behaviour

Each garment is a separate simulated layer with its own material parameters,
rest shape, thickness, mass, friction and constraints. Layer-to-layer contacts
are enabled where needed. A shirt can collide with skin and underwear; armour
can collide with the clothing beneath it. Adjacent layers may use collision
exclusions only where their intended construction requires it.

Seams and elastic openings are explicit constraint sets, not a global stiffness
hack. Leg openings receive higher pre-tension and lower target circumference
than ordinary fabric edges, allowing the opening to maintain contact around the
leg without simply shrinking the whole garment.

## Animation and gravity

The solver consumes the animated skeleton pose every substep. Gravity is a
world-space acceleration, while pose changes contribute inertial motion. A
standing, seated, supine or prone pose therefore produces different cloth
settling. Offline fitting can simulate multiple canonical poses and transitions;
runtime can use reduced substeps, cached rest-state corrections and simplified
collision proxies.

## Two-way contact

A contact has two participants and a compliance/mass split. A soft body region
can yield under cloth pressure; cloth and body both move according to inverse
mass/compliance. Body resistance hardens with displacement (for example a
linear-plus-cubic response). The original accepted Wren skin is never replaced:
deformation is applied to a simulation proxy or reversible deformation layer,
then transferred to the rendered body only through a separately validated
deformation path.

The same contact interface can represent character-to-character contact and
equipment contact. A sword touching a sleeve is not a special-case garment
operation; it is another collider with its own stiffness, thickness and friction.
Rigid objects remain rigid unless explicitly configured as compliant.

## Performance tiers

- **Authoring/offline:** high-resolution body and garment meshes, accurate
  triangle/BVH contacts, many iterations, multiple pose validation.
- **Gameplay:** lower-resolution collision proxies, adaptive substeps, selective
  garment simulation, sleeping/caching for stable layers, and rigid or kinematic
  fallback for distant characters.
- **Mobile:** strict per-character simulation budgets; simulate only nearby,
  visible, interacting characters at full fidelity.

## Current scope and non-goals

The PR now includes an offline static-pose adapter in
`tools/blender/simulate_wren_garment_contact.py`. It loads the extracted Ara
garment objects, builds triangle BVHs from the accepted Wren skin collider and
the actual baked piercing meshes, and runs XPBD contact projection interleaved
with mesh-edge stretch constraints. It exports a deformed garment GLB and a
machine-readable report. The CI preview consumes that simulated GLB, not the
pre-simulation assembly.

The current adapter deliberately leaves the accepted rendered body, rig,
materials and visible piercing meshes unchanged. It is a static-pose relaxation:
it does not yet simulate animation/gravity, apply compliant soft-tissue
deformation to the body, or identify semantic waistband/leg-opening seam loops.
Boundary edges currently receive reinforced elastic constraints as a generic
fallback. These limitations are recorded in the simulation report and are not
claimed as completed features.

No garment is accepted until the actual preview demonstrates improved contact
without new folds, holes or shading artefacts, and the report shows tolerable
residual penetration. Multiple-pose behaviour, body soft-tissue response,
semantic seam tension and runtime cloth remain subsequent work.
