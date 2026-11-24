# Body contact and pressure physics

## Scope

The pressure solver is anatomy-agnostic. Region identity belongs to the canonical CharacterSurfaceRegionMask.REGION_IDS vocabulary (145 overlapping fine regions); the pressure layer must not define a second anatomical taxonomy. BodyPressureProfileLibrary reads that vocabulary from the anatomy resource at runtime and assigns provisional game-tuning material defaults by anatomical name. The IDs remain distinct even when regions share a mechanical profile. Callers may register character-specific overrides before defaults are installed; defaults never overwrite them.

The anatomy resource and authoring workflow currently live in the dependent anatomy workstream. When that resource is not present (for example, when this PR is tested against dev alone), automatic canonical registration safely returns no regions. The profile-library test supplies representative canonical IDs in that case; when run with the anatomy workstream, it tests the complete resource vocabulary.

These stiffness, damping, effective-mass and maximum-compression values are game-tuning starting points, not measured tissue properties. They require calibration against the actual character mesh and deformation response.

## Runtime contract

1. Register the canonical anatomy region ID and a BodyRegionProfile.
2. For every contact in a physics tick, call apply_pressure(region_id, force_n).
3. Call step(delta) once per physics tick.
4. Read get_compression_m(region_id) and feed it to a model-specific deformation adapter.
5. Stop submitting force when contact ends; the spring returns to rest.

Multiple contact sources can contribute in the same tick. BodyPressureContact.calculate_force_n() converts detected penetration and closing speed into a capped compressive force. BodyPressureContact.submit_contact() sends that force to a registered canonical region. AraCharacterActor.apply_body_contact() exposes the same bridge. Collision detection and selection of the canonical region ID remain the contact producer's responsibility.

## Runtime deformation adapter

BodyPressureController connects named regions to explicitly authored blend shapes. It looks for Pressure_<RegionId> (for example, Pressure_breast_left) and drives the shape from 0 to 1 according to the region's compression fraction. The blend shape must be authored in the compressed direction. The 145 region definitions do not imply that 145 pressure shapes already exist: the current Ara exports still need localised pressure deformation authored and visually validated.

## Remaining integration stages

- Integrate the pressure controller with evaluated CharacterSurfaceRegions samples so a contact point can resolve to one or more overlapping canonical IDs.
- Add actual collision probes and region-selection data for hands, garments and character-to-character contact.
- Author and visually inspect localised pressure deformation on the actual Wren/Aldric meshes.
- Add a debug test scene with adjustable contact force, region profile and recovery.

## Validation

Run with Godot 4.7.2:

    godot --headless --path . --script res://tests/test_body_pressure_solver.gd
    godot --headless --path . --script res://tests/test_body_pressure_controller.gd
    godot --headless --path . --script res://tests/test_body_pressure_contact.gd
    godot --headless --path . --script res://tests/test_body_pressure_profile_library.gd

The solver/contact tests cover force response, relative stiffness, simultaneous contacts, recovery and force limits. The controller test verifies local blend-shape targeting on a synthetic mesh, not visible deformation on Wren.
