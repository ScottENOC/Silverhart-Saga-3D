# Brief for ChatGPT (posing slice)

Repo: ScottENOC/Silverhart-Saga-3D. Engine: Godot 4.7.2, GDScript, tabs for indentation.
Read `docs/posing/POSING_CONTRACT.md` first. Do not redesign anything described there.

## Rules

1. **You may not change** `scripts/posing/*.gd` logic, `data/posing/*.json` values, or any `tests/*posing*`
   file, except to fix a typo or a bug a test proves. If you think a test or design is wrong, stop and write
   the question into the PR description. Do not edit the test to make it pass.
2. Use tabs. No `class_name` in `scripts/posing/`. Use `preload` constants.
3. Run tests through `bash tools/ci/run_godot_checked.sh godot --headless --path . --script res://tests/<name>.gd`
   and paste the full output into the PR. `SCRIPT ERROR` anywhere means failure even if exit code is 0.
4. One branch and one PR per task. Branch from `dev` unless told otherwise. Never force-push.
   Do not touch other features' files.
5. Say plainly what you did not verify.

## Task 0: land the slice

Apply `posing-slice.patch` (`git am posing-slice.patch`) on a new branch `feat/posing-core` from `dev`.
Confirm all five posing tests pass in CI via `.github/workflows/posing-validation.yml`. Open a PR to `dev`.
Do not merge until the owner approves.

## Task 1: real Ara validation

Goal: find out whether the builder and applier work on the real character skeletons.

- Write `tools/review/posing_ara_check.gd` (a `SceneTree` script). For each canonical Ara body (female and male
  GLBs in `art/characters/ara_runtime/`, if present in the checkout or the CI artifact), instantiate it, find
  the `Skeleton3D`, call `ArmRigBuilder.from_skeleton` for both sides, and print: bone names matched, shoulder
  position, segment lengths, hand length, frame vectors, and whether each frame vector is plausible (right near
  the model's lateral axis, up near +Y).
- Then solve a nose poke with `ArmPoseSolver` using a target you derive from the head bone (document how) and
  apply it with `PoseApplier`. Print whether the solved elbow, wrist and fingertip bones landed within 2 mm.
- If bone names do not match, fix **only** the alias lists in `scripts/posing/arm_rig_builder.gd` and add a
  test case to `tests/test_posing_arm_rig_builder.gd` with a skeleton using the real names.
- Report: which Ara variants worked, which did not, and exact errors. Do not guess at fixes outside aliases.

## Task 2: preview scene

Build `scenes/dev/posing_preview.tscn` plus `scripts/dev/posing_preview.gd`. No new physics logic.

- Shows one character (synthetic fixture skeleton if no Ara is available).
- Controls: body (adult/small), helmet on/off, peak force slider (0-20 N), play/pause, scrub time.
- Draws the capsule proxies (wireframe) and the target point. Shows text: phase, pose valid/invalid with
  reasons, elbow flexion, wrist deviation, min clearance, pad compression, target compression.
- All numbers come straight from the module outputs.
- Capture a screenshot per case (bare, helmeted) using the existing review-capture pattern in `tools/review/`.

## Not your job

Procedural deformation, garments, landmarks, IK for legs or fingers, tuning materials or limits. Those are
designed separately.
