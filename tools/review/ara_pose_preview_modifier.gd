extends SkeletonModifier3D
## Review-only late modifier. Builds a real-rig nose-touch pose and applies it after
## AraSkeletonRetargeter, so the base animation remains active on unclaimed bones.

const ArmRigBuilder := preload("res://scripts/posing/arm_rig_builder.gd")
const ArmPoseSolver := preload("res://scripts/posing/arm_pose_solver.gd")
const ContactResolver := preload("res://scripts/posing/contact_resolver.gd")
const PoseApplier := preload("res://scripts/posing/pose_applier.gd")

@export var side: StringName = &"right"
var last_status := "waiting"
var last_tip_error_m := -1.0
var _solver := ArmPoseSolver.new()
var _materials: Dictionary
var _hand_dir := Vector3.ZERO
var _planned := false
var _last_swivel := 0.0
var _last_valid := false


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var rig := ArmRigBuilder.from_skeleton(skeleton, side)
	if rig == null:
		last_status = "rig build failed"
		return
	var head := ArmRigBuilder.find_bone(skeleton, ["Head"])
	if head < 0:
		last_status = "head bone missing"
		return
	var normal: Vector3 = rig.frame_forward.normalized()
	var nose: Vector3 = skeleton.get_bone_global_pose(head).origin + normal * 0.085 + rig.frame_up * 0.025
	if not _planned:
		_materials = ContactResolver.load_materials("res://data/posing/contact_materials.json")
		if _materials.is_empty():
			last_status = "contact materials unavailable"
			return
		var stack: Array = [ContactResolver.layer_from_material(&"nose_tissue", _materials["layers"]["nose_tissue"])]
		var pad: Dictionary = _materials["pads"]["fingertip_pad"]
		var tip_for_dir := func(direction: Vector3) -> Vector3:
			return ContactResolver.resolve(nose, normal, stack, pad, 0.0, 4.0, -direction)["bone_tip"]
		var plan := _solver.plan_approach(rig, tip_for_dir, normal, [&"head"], 60.0)
		if not bool(plan["valid"]):
			last_status = "no valid approach: %s" % str(plan["pose"].get("reasons", []))
			return
		_hand_dir = plan["hand_dir"]
		_last_swivel = float(plan["swivel_deg"])
		_planned = true
	var stack_now: Array = [ContactResolver.layer_from_material(&"nose_tissue", _materials["layers"]["nose_tissue"])]
	var pad_now: Dictionary = _materials["pads"]["fingertip_pad"]
	var contact := ContactResolver.resolve(nose, normal, stack_now, pad_now, 0.0, 4.0, -_hand_dir)
	var pose := _solver.solve(rig, contact["bone_tip"], _hand_dir, [&"head"], _last_swivel)
	if not bool(pose["valid"]):
		last_status = "pose invalid: %s" % str(pose["reasons"])
		_last_valid = false
		return
	if not PoseApplier.apply_arm(skeleton, side, pose):
		last_status = "PoseApplier failed"
		_last_valid = false
		return
	_last_swivel = float(pose["swivel_deg"])
	var bones := ArmRigBuilder.arm_bones(skeleton, side)
	var tip := int(bones["finger_tip"])
	if tip >= 0:
		last_tip_error_m = skeleton.get_bone_global_pose(tip).origin.distance_to(pose["tip"])
	last_status = "nose touch active"
	_last_valid = true
