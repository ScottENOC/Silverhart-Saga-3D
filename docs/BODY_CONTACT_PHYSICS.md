# Body contact and pressure physics

## Scope of the first implementation

The first layer is a reusable spring-damper solver for named body regions. A contact producer (hand, garment, self-contact, or another character) supplies compressive force in Newtons. The solver accumulates simultaneous contacts, advances a damped spring, and exposes compression in metres for a later mesh-deformation adapter.

Each region has its own mechanical profile: stiffness (N/m), damping (N*s/m), effective mass (kg), and maximum compression (m). These are mechanical tuning parameters, not medical measurements. Initial values are provisional and need calibration against the model.

## Runtime contract

1. Register a stable region ID and a BodyRegionProfile.
2. For every contact in a physics tick, call apply_pressure(region_id, force_n).
3. Call step(delta) once per physics tick.
4. Read get_compression_m(region_id) and feed it to a model-specific deformation adapter.
5. Stop submitting force when contact ends; the spring returns to rest.

Multiple contact sources can contribute in the same tick. The solver does not perform collision detection, infer contact forces, move bones, or deform a mesh. Those responsibilities stay separate so the same physics works for clothing, self-contact and character-to-character contact.

## Planned integration stages

- Contact sampling from hand/body/clothing collision proxies.
- Region mapping from existing anatomy-region metadata or vertex groups.
- Mesh deformation using localised vertex weights or authored shape keys.
- A debug test scene with adjustable contact force, region profile and recovery.
- Character-specific profile presets and performance profiling.

## Validation

Run with the project's Godot 4.7.2 executable:

    godot --headless --path . --script res://tests/test_body_pressure_solver.gd

The test checks force response, relative stiffness, multiple contacts, recovery, and the maximum-compression guard.
