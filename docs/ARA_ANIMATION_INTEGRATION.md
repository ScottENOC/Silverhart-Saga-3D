# Ara skeleton and animation integration validation

## Purpose

Validate the actual Ara Wren benchmark export in Godot 4.7.2 before wiring animation states into gameplay. This is deliberately a separate validation branch from the terrain grounding work.

## Source assets

The test downloads the `character-pipeline-evaluation` artifact from workflow run `41979224139` on `feature/modular-character-poc`:

- `ara_wren_benchmark.glb`: full Wren benchmark export with a 69-bone rig and 77 animation clips.
- `modular/body.glb`, `hair.glb`, `shirt.glb`, `trousers.glb`: independently exported skinned components, each carrying its own copy of the rig.

The mobile terrain-test export `ara_wren_mobile.glb` is a separate lightweight export. It has 66 joints and no animation clips, so it is not suitable for this test.

## Automated checks

`tests/test_ara_animation_import.gd` runs in Godot headless and checks:

1. Godot imports the benchmark GLB as a scene with a `Skeleton3D` and `AnimationPlayer`.
2. The benchmark skeleton has the expected 69 bones and exposes key clips such as Idle, Walk, Run, Strafe left and Jump.
3. Each modular component imports with a skeleton whose bone count, ordered names and rest transforms match the benchmark rig.
4. The body, hair, shirt and trousers meshes can be rebound to the benchmark skeleton.
5. Playing the Walk clip changes the shared skeleton's bone poses.

This validates the import, rig compatibility and animation-driving path. It does not yet prove visual quality of deformation, foot locking, root-motion handling, animation blending, or integration with the game's movement/combat state machines. Those require an in-engine visual test and a gameplay animation controller.

## Asset retention

The workflow artifact is temporary (14-day retention). This validation intentionally downloads it at CI time rather than committing a 20 MB benchmark GLB to the source tree. Before production integration, promote the selected runtime body/components and an agreed animation source into managed project assets with explicit versioning.