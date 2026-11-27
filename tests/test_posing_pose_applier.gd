extends "res://tests/posing_test_base.gd"
## Contract for scripts/posing/pose_applier.gd (synthetic skeletons; real Ara validation is a separate task).
## Uses the fixture rig (not the builder) so a builder bug cannot hide an applier bug.

const ContactResolver := preload("res://scripts/posing/contact_resolver.gd")
const ArmPoseSolver := preload("res://scripts/posing/arm_pose_solver.gd")
const PoseApplier := preload("res://scripts/posing/pose_applier.gd")
const Fixtures := preload("res://tests/posing_fixtures.gd")

const NORMAL := Vector3(0, 0, -1)


func _run() -> void:
	for body_name in ["adult", "small"]:
		var p: Dictionary = Fixtures.adult() if body_name == "adult" else Fixtures.small()
		for side in [&"right", &"left"]:
			_test_apply(body_name, p, side)
	_test_missing_bone()


func _model_pos(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _solve(p: Dictionary, side: StringName) -> Dictionary:
	var mats := ContactResolver.load_materials(Fixtures.MATERIALS_PATH)
	var stack: Array = [ContactResolver.layer_from_material(&"nose_tissue", mats["layers"]["nose_tissue"])]
	var pad: Dictionary = mats["pads"]["fingertip_pad"]
	var rig := Fixtures.make_rig(p, side, false)
	var nose: Vector3 = p["nose"]
	var tip_for_dir := func(dir: Vector3) -> Vector3:
		return ContactResolver.resolve(nose, NORMAL, stack, pad, 0.0, 4.0, -dir)["bone_tip"]
	var solver := ArmPoseSolver.new()
	var plan := solver.plan_approach(rig, tip_for_dir, NORMAL, [&"head"], 60.0)
	return solver.solve(rig, tip_for_dir.call(plan["hand_dir"]), plan["hand_dir"], [&"head"])


func _test_apply(label: String, p: Dictionary, side: StringName) -> void:
	var tag := "%s %s" % [label, side]
	var pose := _solve(p, side)
	_check(bool(pose["valid"]), "%s: fixture pose is valid" % tag)
	var skeleton := Fixtures.make_skeleton(p, [], root)
	var prefix := "Right" if side == &"right" else "Left"
	var before_upper := _model_pos(skeleton, prefix + "Arm").distance_to(_model_pos(skeleton, prefix + "ForeArm"))
	var before_fore := _model_pos(skeleton, prefix + "ForeArm").distance_to(_model_pos(skeleton, prefix + "Hand"))
	var untouched := {}
	for bone in ["Hips", "Spine2", "Neck", "Head", "LeftArm" if side == &"right" else "RightArm", "LeftHand" if side == &"right" else "RightHand"]:
		untouched[bone] = _model_pos(skeleton, bone)

	_check(PoseApplier.apply_arm(skeleton, side, pose), "%s: apply_arm succeeds" % tag)
	_near_v(_model_pos(skeleton, prefix + "Arm"), pose["shoulder"], 1e-3, "%s: shoulder stays at the shoulder" % tag)
	_near_v(_model_pos(skeleton, prefix + "ForeArm"), pose["elbow"], 1e-3, "%s: elbow joint lands on the solved elbow" % tag)
	_near_v(_model_pos(skeleton, prefix + "Hand"), pose["wrist"], 1e-3, "%s: wrist joint lands on the solved wrist" % tag)
	_near_v(_model_pos(skeleton, prefix + "HandMiddle4"), pose["tip"], 2e-3, "%s: fingertip bone lands on the solved tip" % tag)
	_near(_model_pos(skeleton, prefix + "Arm").distance_to(_model_pos(skeleton, prefix + "ForeArm")), before_upper, 5e-4, "%s: upper arm length preserved" % tag)
	_near(_model_pos(skeleton, prefix + "ForeArm").distance_to(_model_pos(skeleton, prefix + "Hand")), before_fore, 5e-4, "%s: forearm length preserved" % tag)
	for bone in untouched:
		_near_v(_model_pos(skeleton, bone), untouched[bone], 1e-4, "%s: %s is not moved" % [tag, bone])
	for bone in [prefix + "Arm", prefix + "ForeArm", prefix + "Hand"]:
		_near_v(skeleton.get_bone_pose_scale(skeleton.find_bone(bone)), Vector3.ONE, 1e-5, "%s: %s scale untouched" % [tag, bone])

	var tip_after := _model_pos(skeleton, prefix + "HandMiddle4")
	_check(PoseApplier.apply_arm(skeleton, side, pose), "%s: applying twice succeeds" % tag)
	_near_v(_model_pos(skeleton, prefix + "HandMiddle4"), tip_after, 1e-5, "%s: applying is idempotent" % tag)
	skeleton.free()


func _test_missing_bone() -> void:
	var p := Fixtures.adult()
	var skeleton := Fixtures.make_skeleton(p, ["RightForeArm"], root)
	_check(not PoseApplier.apply_arm(skeleton, &"right", _solve(p, &"right")), "a missing bone returns false")
	skeleton.free()
