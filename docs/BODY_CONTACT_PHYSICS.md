# Body contact and pressure physics

## Scope of the first implementation

The first layer is a reusable spring-damper solver for named body regions. A contact producer (hand, garment, self-contact, or another character) supplies compressive force in Newtons. The solver accumulates simultaneous contacts, advances a damped spring, and exposes compression in metres for a later mesh-deformation adapter.

Each region has its own mechanical profile: stiffness (N/m), damping (N*s/m), effective mass (kg), and maximum compression (m). `BodyPressureProfileLibrary` supplies provisional game-tuning presets for paired chest, shoulder, arm, hand, hip, thigh and calf regions plus abdomen, waist, pelvis, back, neck and head. Ara actors register missing presets during model setup while preserving any profiles registered earlier by gameplay code. These are not medical measurements and need calibration against the model.

## Runtime contract

1. Register a stable region ID and a BodyRegionProfile.
2. For every contact in a physics tick, call apply_pressure(region_id, force_n).
3. Call step(delta) once per physics tick.
4. Read get_compression_m(region_id) and feed it to a model-specific deformation adapter.
5. Stop submitting force when contact ends; the spring returns to rest.

Multiple contact sources can contribute in the same tick. `BodyPressureContact.calculate_force_n()` converts a detected contact's penetration depth and closing speed into a capped compressive force using contact stiffness and damping. `BodyPressureContact.submit_contact()` sends that force to a registered region. `AraCharacterActor.apply_body_contact()` exposes the same bridge to gameplay code. Call it once per physics tick while a hand, garment, or other actor remains in contact; stop calling it when contact ends. Positive closing speed means motion into the body; negative speed is treated as separation and never creates tensile force. The caller still owns collision detection and region selection.

## Runtime deformation adapter

`BodyPressureController` connects named regions to explicitly authored blend shapes on the character mesh. Register a `BodyRegionProfile`, bind the character model, then submit contact forces as usual. The adapter looks for a shape named `Pressure_<RegionName>` (for example `Pressure_LeftChest`) and drives it from 0 to 1 according to the region's compression fraction. The blend shape must be authored in the compressed direction. AraCharacterActor owns the controller and exposes `register_body_pressure_region`, `apply_body_pressure` and `get_body_pressure_m`.

The current Ara body exports have not yet been given these pressure-specific blend shapes. Until those shapes are authored and verified on the actual meshes, the adapter's regression test uses a small synthetic mesh; it proves the physics-to-blend-shape connection, not visible deformation on Wren.

## Remaining integration stages

- Add actual collision probes and region-selection data for hands, garments and character-to-character contact.
- Author and visually inspect localised pressure blend shapes for the target Ara body regions.
- Map hand, clothing and character collision proxies to region IDs and calculate contact forces.
- Add a debug test scene with adjustable contact force, region profile and recovery.
- Add character-specific profile presets and profile performance.

## Validation

Run with the project's Godot 4.7.2 executable:

    godot --headless --path . --script res://tests/test_body_pressure_solver.gd
    godot --headless --path . --script res://tests/test_body_pressure_controller.gd

The solver test checks force response, relative stiffness, multiple contacts, recovery, and the maximum-compression guard. The controller test verifies independent left/right shape targets, pressure response, and recovery on a synthetic mesh.
