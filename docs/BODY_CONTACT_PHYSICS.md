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

## Runtime deformation adapter

`BodyPressureController` connects named regions to explicitly authored blend shapes on the character mesh. Register a `BodyRegionProfile`, bind the character model, then submit contact forces as usual. The adapter looks for a shape named `Pressure_<RegionName>` (for example `Pressure_LeftChest`) and drives it from 0 to 1 according to the region's compression fraction. The blend shape must be authored in the compressed direction. AraCharacterActor owns the controller and exposes `register_body_pressure_region`, `apply_body_pressure` and `get_body_pressure_m`.

The current Ara body exports have not yet been given these pressure-specific blend shapes. Until those shapes are authored and verified on the actual meshes, the adapter's regression test uses a small synthetic mesh; it proves the physics-to-blend-shape connection, not visible deformation on Wren.

## Remaining integration stages

- Author and visually inspect localised pressure blend shapes for the target Ara body regions.
- Map hand, clothing and character collision proxies to region IDs and calculate contact forces.
- Add a debug test scene with adjustable contact force, region profile and recovery.
- Add character-specific profile presets and profile performance.

## Validation

Run with the project's Godot 4.7.2 executable:

    godot --headless --path . --script res://tests/test_body_pressure_solver.gd

The test checks force response, relative stiffness, multiple contacts, recovery, and the maximum-compression guard.
