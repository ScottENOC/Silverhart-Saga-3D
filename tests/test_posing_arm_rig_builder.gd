extends "res://tests/posing_test_base.gd"
## Contract for scripts/posing/arm_rig_builder.gd (synthetic skeletons; real Ara validation is a separate task).

const ArmRigBuilder := preload("res://scripts/posing/arm_rig_builder.gd")
const BodyProxy := preload("res://scripts/posing/body_proxy.gd")
const Fixtures := preload("res://tests/posing_fixtures.gd")


func _run() -> void:
	for body_name in ["adult", "small"]:
		var p: Dictionary = Fixtures.adult() if body_name == "adult" else Fixtures.small()
		var skeleton := Fixtures.make_skeleton(p, [], root)
		for side in [&"right", &"left"]:
			_test_rig(body_name, p, skeleton, side)
		skeleton.free()
	_test_missing_bone_returns_null()
	_test_options_override()


func _model_pos(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _test_rig(label: String, p: Dictionary, skeleton: Skeleton3D, side: StringName) -> void:
	var tag := "%s %s" % [label, side]
	var rig: RefCounted = ArmRigBuilder.from_skeleton(skeleton, side)
	_check(rig != null, "%s: builder returns a rig" % tag)
	if rig == null:
		return
	var prefix := "Right" if side == &"right" else "Left"
	var shoulder := _model_pos(skeleton, prefix + "Arm")
	var elbow := _model_pos(skeleton, prefix + "ForeArm")
	var wrist := _model_pos(skeleton, prefix + "Hand")
	var tip := _model_pos(skeleton, prefix + "HandMiddle4")
	_check(rig.side == side, "%s: side recorded" % tag)
	_near_v(rig.shoulder, shoulder, 1e-4, "%s: shoulder position" % tag)
	_near(rig.upper_len, shoulder.distance_to(elbow), 1e-4, "%s: upper arm length" % tag)
	_near(rig.fore_len, elbow.distance_to(wrist), 1e-4, "%s: forearm length" % tag)
	_near(rig.hand_len, wrist.distance_to(tip), 1e-4, "%s: hand length comes from the finger chain" % tag)

	# Frame: right = left shoulder -> right shoulder, up = hips -> head (orthogonalised), forward = up x right.
	_near_v(rig.frame_right, Vector3.RIGHT, 1e-4, "%s: frame right" % tag)
	_near_v(rig.frame_up, Vector3.UP, 1e-4, "%s: frame up" % tag)
	_near_v(rig.frame_forward, Vector3(0, 0, -1), 1e-4, "%s: frame forward = up x right" % tag)
	_near(rig.frame_right.dot(rig.frame_up), 0.0, 1e-4, "%s: frame is orthogonal" % tag)

	# Natural elbow: hangs down and a little outward.
	var outward := 1.0 if side == &"right" else -1.0
	_near(rig.rest_pole.length(), 1.0, 1e-4, "%s: rest pole is a unit vector" % tag)
	_check(rig.rest_pole.dot(rig.frame_up) < -0.8, "%s: rest pole points down" % tag)
	_check(rig.rest_pole.dot(rig.frame_right) * outward > 0.0, "%s: rest pole points outward" % tag)

	# Radii scale with segment length so any body gets sensible capsules.
	_check(rig.upper_radius >= 0.10 * rig.upper_len and rig.upper_radius <= 0.16 * rig.upper_len, "%s: upper radius proportional" % tag)
	_check(rig.fore_radius >= 0.10 * rig.fore_len and rig.fore_radius <= 0.16 * rig.fore_len, "%s: forearm radius proportional" % tag)
	_check(rig.hand_radius >= 0.12 * rig.hand_len and rig.hand_radius <= 0.20 * rig.hand_len, "%s: hand radius proportional" % tag)

	# Limits come from data/posing/arm_joint_limits.json.
	_near(rig.limits.elbow_flexion_max_deg, 150.0, 1e-6, "%s: limits loaded from data" % tag)

	# Default body proxies: torso, head and pelvis exist, contain their bones, and the resting arm is clear of them.
	var ids: Array = []
	for proxy in rig.proxies:
		ids.append(proxy["id"])
	for required in [&"torso", &"head", &"pelvis"]:
		_check(ids.has(required), "%s: proxy '%s' exists" % [tag, required])
	var head_pos := _model_pos(skeleton, "Head")
	for proxy in rig.proxies:
		if proxy["id"] == &"head":
			_check(BodyProxy.clearance(head_pos, head_pos, 0.0, proxy) < 0.0, "%s: head proxy contains the head bone" % tag)
	var rest_upper := BodyProxy.min_clearance(shoulder + (elbow - shoulder).normalized() * rig.root_skip_m, elbow, rig.upper_radius, rig.proxies)
	var rest_fore := BodyProxy.min_clearance(elbow, wrist, rig.fore_radius, rig.proxies)
	_check(rest_upper >= 0.0 and rest_fore >= 0.0, "%s: the resting arm does not penetrate the default proxies" % tag)


func _test_missing_bone_returns_null() -> void:
	var skeleton := Fixtures.make_skeleton(Fixtures.adult(), ["RightForeArm"], root)
	_check(ArmRigBuilder.from_skeleton(skeleton, &"right") == null, "a missing forearm gives null, not an invented rig")
	_check(ArmRigBuilder.from_skeleton(skeleton, &"left") != null, "the other arm is unaffected")
	skeleton.free()


func _test_options_override() -> void:
	var skeleton := Fixtures.make_skeleton(Fixtures.adult(), ["RightHandMiddle4", "RightHandMiddle3", "RightHandMiddle2", "RightHandMiddle1"], root)
	var rig: RefCounted = ArmRigBuilder.from_skeleton(skeleton, &"right", {"hand_length_m": 0.2})
	_check(rig != null, "without a finger chain, hand_length_m is used")
	if rig != null:
		_near(rig.hand_len, 0.2, 1e-6, "hand length option applied")
	skeleton.free()
