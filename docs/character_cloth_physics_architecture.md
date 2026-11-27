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

The current PR has only prepared the accepted skin and baked piercing collision
meshes. It has not simulated or deformed the bikini. This core is the reusable
solver foundation; the next adapter work must extract the actual bikini-bottom
and string primitives, preserve their skinning/morph contracts, query the real
body/piercing surfaces, and validate the result in front/side/pelvis views.

No garment is accepted until contact, seam tension, multiple-pose behaviour,
and preservation of the accepted body/rig/materials all pass review.
