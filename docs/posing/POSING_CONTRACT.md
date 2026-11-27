# Posing slice: contract and status

Goal: make a character reach and touch something realistically, on any body, with the outcome
depending on what is being touched. First case: a hand poking a nose, bare or under a steel helm.

Everything here is pure maths over plain data, so it runs headless and is fast to test.
Godot scene wiring is deliberately thin and lives in two small modules.

## Space and conventions

- **Rig space = Skeleton3D model space** (`get_bone_global_pose`). Metres.
- Frame vectors travel with the rig: `right` (left shoulder to right shoulder), `up` (hips to head,
  orthogonalised), `forward = up.cross(right)`. Nothing assumes the engine's -Z convention.
- Godot `Vector3` is 32-bit float. Test tolerances below 1e-6 will flake.
- **A `Skeleton3D` must be inside the scene tree** before you modify and re-read bone poses. In 4.7.2
  a free-standing skeleton returns stale global poses (`force_update_all_bone_transforms()` does not help).
- No `class_name` in these scripts: they `preload` each other, so headless runs need no class cache.

## Modules

| File | Role | Status |
|---|---|---|
| `scripts/posing/body_proxy.gd` | Capsule distance and clearance | done, tested |
| `scripts/posing/joint_limits.gd` | Elbow, shoulder-extension, wrist limits (data in `data/posing/arm_joint_limits.json`) | done, tested |
| `scripts/posing/ik_two_bone.gd` | Analytic shoulder-elbow-wrist IK with swivel | done, tested |
| `scripts/posing/arm_pose_solver.gd` | Approach planning + per-frame solve with limits and collision | done, tested |
| `scripts/posing/contact_resolver.gd` | Series-spring contact between fingertip pad and a layer stack | done, tested |
| `scripts/posing/goal_sequence.gd` | Reach, press, hold, release timeline (minimum jerk) | done, tested |
| `scripts/posing/arm_rig.gd` | Plain-data description of one arm | done |
| `scripts/posing/arm_rig_builder.gd` | `Skeleton3D` to `ArmRig` | done on synthetic skeletons; **not yet run on real Ara** |
| `scripts/posing/pose_applier.gd` | Solved pose to bone rotations | done on synthetic skeletons; **not yet run on real Ara** |

## How a touch works

```gdscript
# 1. Describe what is being touched: layers inner -> outer, plus the fingertip pad.
var stack = [nose_tissue_layer, helm_layer]          # helm_layer.bearing = true
var pad = materials["pads"]["fingertip_pad"]

# 2. Once per touch: pick the approach direction (inside a cone around the surface normal).
var tip_for_dir = func(dir): return ContactResolver.resolve(point, normal, stack, pad, 0.0, peak_force, -dir)["bone_tip"]
var plan = ArmPoseSolver.new().plan_approach(rig, tip_for_dir, normal, [&"head", &"helm"], 60.0)

# 3. Every frame: sample the timeline, resolve contact, solve the arm, apply it.
var s = sequence.sample(t)
var contact = ContactResolver.resolve(point, normal, stack, pad, s.approach_m, s.force_n, -plan.hand_dir)
var pose = solver.solve(rig, contact.bone_tip, plan.hand_dir, touch_ids, last_swivel_deg)
PoseApplier.apply_arm(skeleton, &"right", pose)
```

## Design decisions

- **Series springs decide who yields.** The same force passes through every element, so displacement is
  `F / k` per element and the softer one moves further. Finger vs nose splits roughly evenly; finger vs
  steel puts all of it into the finger.
- **`bearing` layers end the load path.** A rigid shell spreads load, so tissue beneath it is not compressed.
  Without this rule a helmet would still squash the nose through the spring chain.
- **Standoff comes from layer thickness**, so a helm that sits 25 mm off the face stops the finger there.
- **Approach is planned once, then held.** A self-touch cannot approach perpendicular to the face: that needs
  about 87 degrees of wrist bend. The planner searches directions within a cone (default 60 degrees) and scores
  wrist bend plus a small tilt penalty. Holding the direction stops the finger swinging during the motion.
- **Swivel search, not a heuristic pole.** The free elbow angle is searched outward from the previous frame's
  value, so the result is the valid pose nearest the last one: deterministic and continuous.
- **Hand may overlap only the surface it touches** (`touch_ids`). Upper arm and forearm may overlap nothing.

## Known limits (be honest about these)

- One arm chain, fingertip effector, straight rigid hand. No finger articulation, no hand roll control, no
  leg or spine IK, no two-handed or body-on-body contact.
- Collision proxies are coarse capsules. A poke can look right and still clip fine geometry (nose bridge, ear).
- Planned approaches for the nose poke land at the 60 degree cone limit on both test bodies. The constraints are
  binding, so tuning hand length, limits or proxies will move the result; do not widen the cone to hide a bug.
- Material numbers in `data/posing/contact_materials.json` are placeholders, not measurements.
- Planning takes tens of milliseconds per goal. Fine for authored animation; budget it before using for crowds.
- Only synthetic skeletons are tested. Real Ara bone names, rest orientations and proportions are unverified.
- **No visible soft deformation yet.** `ContactResolver` reports compression in metres; nothing drives the mesh.

## Acceptance (what the tests prove)

`tests/test_posing_nose_poke.gd` runs reach, press, hold, release at 50 ms steps on two bodies with different
proportions, bare and helmeted. At every step: valid pose, fingertip within 0.1 mm of target, limb lengths
preserved, no capsule penetration, elbow moves under 6 cm per step, swivel under 20 degrees per step, hand
direction constant. Helmet case: pad stops at least 24 mm further out, finger takes over 99% of the deformation,
tissue beneath the shell is unloaded. Collision and each joint limit are proven to be binding by tests where
they are the only thing that changes the answer.

The suite was mutation-checked: disabling collision, joint limits, bearing shells, finger compression or the
swivel search each makes tests fail.

## Running

```
godot --headless --path . --script res://tests/test_posing_math.gd
godot --headless --path . --script res://tests/test_posing_contact.gd
godot --headless --path . --script res://tests/test_posing_nose_poke.gd
godot --headless --path . --script res://tests/test_posing_arm_rig_builder.gd
godot --headless --path . --script res://tests/test_posing_pose_applier.gd
```

Always run through `tools/ci/run_godot_checked.sh` in CI: a script error inside a test function does not
change Godot's exit code, and that script turns `SCRIPT ERROR` into a failure.

## Next stages (not started)

1. Real Ara validation and a preview scene (see `CHATGPT_BRIEF.md`).
2. Procedural local deformation from contact (point, normal, radius, depth) using the existing region masks.
3. Layer chain for garments derived from the layer beneath; garment tension to tissue pressure.
