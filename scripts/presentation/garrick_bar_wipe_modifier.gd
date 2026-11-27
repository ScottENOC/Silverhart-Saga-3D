class_name GarrickBarWipeModifier
extends SkeletonModifier3D
## Procedural one-arm wipe over a fixed world-space surface path.
## Added after AraAnimationRetargeter: the base animation continues on every
## unclaimed bone while this modifier owns only the selected arm.

const ArmRigBuilder := preload("res://scripts/posing/arm_rig_builder.gd")
const ArmPoseSolver := preload("res://scripts/posing/arm_pose_solver.gd")
const PoseApplier := preload("res://scripts/posing/pose_applier.gd")

@export var wipe_period_s: float = 3.2

var wipe_start_world := Vector3(1.55, 1.34, -4.08)
var wipe_end_world := Vector3(2.15, 1.34, -4.08)
var hand_direction_world := Vector3.DOWN

var last_status: String = "waiting"
var last_tip_error_m: float = -1.0
var last_target_world: Vector3 = Vector3.ZERO
var selected_side: StringName = &""

var _solver := ArmPoseSolver.new()
var _elapsed_s: float = 0.0
var _last_swivel_deg: float = 0.0
var _warned_unreachable: bool = false


func configure(start_world: Vector3, end_world: Vector3, hand_world: Vector3 = Vector3.DOWN, period_s: float = 3.2) -> void:
	wipe_start_world = start_world
	wipe_end_world = end_world
	hand_direction_world = hand_world.normalized()
	wipe_period_s = maxf(0.5, period_s)
	_elapsed_s = 0.0
	selected_side = &""
	last_status = "waiting"
	last_tip_error_m = -1.0


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		last_status = "skeleton unavailable"
		return

	_elapsed_s += maxf(0.0, delta)
	var cycle := TAU * _elapsed_s / wipe_period_s
	var blend := 0.5 - 0.5 * cos(cycle)
	last_target_world = wipe_start_world.lerp(wipe_end_world, blend)

	var skeleton_from_world := skeleton.global_transform.affine_inverse()
	var target_local: Vector3 = skeleton_from_world * last_target_world
	var hand_direction_local := (skeleton.global_transform.basis.inverse() * hand_direction_world).normalized()

	if selected_side == &"":
		_select_arm(skeleton, target_local, hand_direction_local)
	if selected_side == &"":
		return

	var rig := ArmRigBuilder.from_skeleton(skeleton, selected_side)
	if rig == null:
		last_status = "selected arm rig unavailable"
		return
	var pose: Dictionary = _solver.solve(rig, target_local, hand_direction_local, [], _last_swivel_deg)
	if not bool(pose.get("valid", false)):
		last_status = "wipe target unreachable: %s" % str(pose.get("reasons", []))
		return
	if not PoseApplier.apply_arm(skeleton, selected_side, pose):
		last_status = "arm pose application failed"
		return

	_last_swivel_deg = float(pose.get("swivel_deg", _last_swivel_deg))
	var bones := ArmRigBuilder.arm_bones(skeleton, selected_side)
	var tip_bone := int(bones.get("finger_tip", -1))
	if tip_bone >= 0:
		last_tip_error_m = skeleton.get_bone_global_pose(tip_bone).origin.distance_to(pose["tip"])
	last_status = "bar wipe active"


func _select_arm(skeleton: Skeleton3D, current_target: Vector3, hand_direction: Vector3) -> void:
	var skeleton_from_world := skeleton.global_transform.affine_inverse()
	var start_local: Vector3 = skeleton_from_world * wipe_start_world
	var end_local: Vector3 = skeleton_from_world * wipe_end_world
	var best_score := -INF
	for candidate_value in [&"right", &"left"]:
		var candidate_side: StringName = candidate_value
		var rig := ArmRigBuilder.from_skeleton(skeleton, candidate_side)
		if rig == null:
			continue
		var first: Dictionary = _solver.solve(rig, start_local, hand_direction, [])
		if not bool(first.get("valid", false)):
			continue
		var second: Dictionary = _solver.solve(rig, end_local, hand_direction, [], float(first.get("swivel_deg", 0.0)))
		if not bool(second.get("valid", false)):
			continue
		var score := minf(float(first.get("min_clearance_m", -INF)), float(second.get("min_clearance_m", -INF)))
		if score > best_score:
			best_score = score
			selected_side = candidate_side
			_last_swivel_deg = float(first.get("swivel_deg", 0.0))
	if selected_side == &"":
		last_status = "neither arm can reach both bar-wipe endpoints"
		if not _warned_unreachable:
			_warned_unreachable = true
			push_warning("Garrick bar wipe: no arm can reach the authored bar surface path.")
