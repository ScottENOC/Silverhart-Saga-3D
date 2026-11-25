extends "res://tests/posing_test_base.gd"
## Acceptance test for the posing slice: a right-hand nose poke on two different bodies,
## bare and helmeted, driven through the full reach/press/hold/release timeline.

const ContactResolver := preload("res://scripts/posing/contact_resolver.gd")
const GoalSequence := preload("res://scripts/posing/goal_sequence.gd")
const ArmPoseSolver := preload("res://scripts/posing/arm_pose_solver.gd")
const BodyProxy := preload("res://scripts/posing/body_proxy.gd")
const Fixtures := preload("res://tests/posing_fixtures.gd")

const NORMAL := Vector3(0, 0, -1)
const PEAK_FORCE := 4.0
const CONE_DEG := 60.0

var _materials: Dictionary


func _run() -> void:
	_materials = ContactResolver.load_materials(Fixtures.MATERIALS_PATH)
	if _materials.is_empty():
		_check(false, "materials must load")
		return
	for body_name in ["adult", "small"]:
		var p: Dictionary = Fixtures.adult() if body_name == "adult" else Fixtures.small()
		_test_full_timeline(body_name, p, false)
		_test_full_timeline(body_name, p, true)
	_test_helmet_stops_short_and_finger_yields()
	_test_bodies_differ()
	_test_left_hand_mirrors()
	_test_swivel_avoids_the_torso()
	_test_unreachable_target()
	_test_target_behind_the_back()
	_test_approach_is_oblique_but_bounded()
	_test_collisions_are_enforced()
	_test_joint_limits_are_enforced()


func _stack(helm: bool) -> Array:
	var layers: Array = [ContactResolver.layer_from_material(&"nose_tissue", _materials["layers"]["nose_tissue"])]
	if helm:
		layers.append(ContactResolver.layer_from_material(&"helm_closed_steel", _materials["layers"]["helm_closed_steel"]))
	return layers


func _touch_ids(helm: bool) -> Array:
	return [&"head", &"helm"] if helm else [&"head"]


func _plan(p: Dictionary, helm: bool, side: StringName = &"right") -> Dictionary:
	var rig := Fixtures.make_rig(p, side, helm)
	var stack := _stack(helm)
	var pad: Dictionary = _materials["pads"]["fingertip_pad"]
	var nose: Vector3 = p["nose"]
	var tip_for_dir := func(dir: Vector3) -> Vector3:
		return ContactResolver.resolve(nose, NORMAL, stack, pad, 0.0, PEAK_FORCE, -dir)["bone_tip"]
	var plan := ArmPoseSolver.new().plan_approach(rig, tip_for_dir, NORMAL, _touch_ids(helm), CONE_DEG)
	plan["rig"] = rig
	return plan


func _solve_at(plan: Dictionary, p: Dictionary, helm: bool, approach_m: float, force_n: float, hint_deg: float = 0.0) -> Dictionary:
	var hand_dir: Vector3 = plan["hand_dir"]
	var contact := ContactResolver.resolve(p["nose"], NORMAL, _stack(helm), _materials["pads"]["fingertip_pad"], approach_m, force_n, -hand_dir)
	var pose: Dictionary = ArmPoseSolver.new().solve(plan["rig"], contact["bone_tip"], hand_dir, _touch_ids(helm), hint_deg)
	pose["contact"] = contact
	return pose


func _test_full_timeline(label: String, p: Dictionary, helm: bool) -> void:
	var plan := _plan(p, helm)
	_check(bool(plan["valid"]), "%s helm=%s: an approach exists (%s)" % [label, helm, plan["pose"].get("reasons", [])])
	if not bool(plan["valid"]):
		return
	_check(float(plan["tilt_deg"]) <= CONE_DEG + 1e-6, "%s: approach stays inside the cone" % label)
	var rig: RefCounted = plan["rig"]
	var seq: RefCounted = GoalSequence.new()
	var step := 0.05
	var t := 0.0
	var hint := 0.0
	var previous_elbow := Vector3.INF
	var previous_swivel := INF
	while t <= seq.total_duration_s() + step:
		var state: Dictionary = seq.sample(t)
		var pose := _solve_at(plan, p, helm, float(state["approach_m"]), float(state["force_n"]), hint)
		var tag := "%s helm=%s t=%.2f %s" % [label, helm, t, state["phase"]]
		_check(bool(pose["valid"]), "%s: pose must be valid (%s)" % [tag, pose["reasons"]])
		_near_v(pose["tip"], pose["contact"]["bone_tip"], 1e-4, "%s: fingertip reaches the target" % tag)
		_check(float(pose["min_clearance_m"]) >= 0.0, "%s: no body penetration (%.4f)" % [tag, float(pose["min_clearance_m"])])
		_near((pose["elbow"] - pose["shoulder"]).length(), rig.upper_len, 1e-5, "%s: upper arm length preserved" % tag)
		_near((pose["wrist"] - pose["elbow"]).length(), rig.fore_len, 1e-5, "%s: forearm length preserved" % tag)
		_check((pose["hand_dir"] as Vector3).is_equal_approx(plan["hand_dir"]), "%s: hand direction is held for the whole touch" % tag)
		if previous_elbow != Vector3.INF:
			_check((pose["elbow"] as Vector3).distance_to(previous_elbow) < 0.06, "%s: elbow moves smoothly (%.3f m in one step)" % [tag, (pose["elbow"] as Vector3).distance_to(previous_elbow)])
			_check(absf(float(pose["swivel_deg"]) - previous_swivel) <= 20.0, "%s: swivel changes gradually" % tag)
		previous_elbow = pose["elbow"]
		previous_swivel = float(pose["swivel_deg"])
		hint = previous_swivel
		t += step


func _test_helmet_stops_short_and_finger_yields() -> void:
	var p := Fixtures.adult()
	var bare_plan := _plan(p, false)
	var helm_plan := _plan(p, true)
	var bare := _solve_at(bare_plan, p, false, 0.0, PEAK_FORCE)
	var helmed := _solve_at(helm_plan, p, true, 0.0, PEAK_FORCE)
	var nose: Vector3 = p["nose"]
	var bare_gap: float = ((bare["contact"]["pad_surface_point"] as Vector3) - nose).dot(NORMAL)
	var helm_gap: float = ((helmed["contact"]["pad_surface_point"] as Vector3) - nose).dot(NORMAL)
	_check(helm_gap > bare_gap + 0.024, "the helmeted pad stops at least 24 mm further out than on the bare nose")
	var h_pad := float(helmed["contact"]["pad_compression_m"])
	var h_target := float(helmed["contact"]["target_compression_m"])
	_check(h_target < 1e-6 and h_pad > 5e-4, "against steel the finger is squashed and the metal is not")
	var b_pad := float(bare["contact"]["pad_compression_m"])
	var b_target := float(bare["contact"]["target_compression_m"])
	_check(b_target > 5e-4 and b_pad > 5e-4, "against a bare nose both finger and nose compress")


func _test_bodies_differ() -> void:
	var a_plan := _plan(Fixtures.adult(), false)
	var b_plan := _plan(Fixtures.small(), false)
	var a := _solve_at(a_plan, Fixtures.adult(), false, 0.0, PEAK_FORCE)
	var b := _solve_at(b_plan, Fixtures.small(), false, 0.0, PEAK_FORCE)
	_check((a["elbow"] as Vector3).distance_to(b["elbow"]) > 0.02, "different bodies produce different elbow positions")
	_check(absf(float(a["elbow_flexion_deg"]) - float(b["elbow_flexion_deg"])) > 0.5, "different proportions give different flexion")


func _test_left_hand_mirrors() -> void:
	var p := Fixtures.adult()
	var right_plan := _plan(p, false, &"right")
	var left_plan := _plan(p, false, &"left")
	_check(bool(left_plan["valid"]), "left hand also finds an approach")
	var right := _solve_at(right_plan, p, false, 0.0, PEAK_FORCE)
	var left := _solve_at(left_plan, p, false, 0.0, PEAK_FORCE)
	_near(float(left_plan["tilt_deg"]), float(right_plan["tilt_deg"]), 1e-3, "mirrored approach tilt")
	_near(float(left["elbow_flexion_deg"]), float(right["elbow_flexion_deg"]), 0.5, "mirrored flexion")
	_near((left["elbow"] as Vector3).y, (right["elbow"] as Vector3).y, 0.01, "mirrored elbow height")
	_near((left["hand_dir"] as Vector3).x, -(right["hand_dir"] as Vector3).x, 1e-4, "mirrored hand direction")


func _test_swivel_avoids_the_torso() -> void:
	var p := Fixtures.adult()
	var plan := _plan(p, false)
	var rig: RefCounted = plan["rig"]
	var hand_dir: Vector3 = plan["hand_dir"]
	var contact := ContactResolver.resolve(p["nose"], NORMAL, _stack(false), _materials["pads"]["fingertip_pad"], 0.0, PEAK_FORCE, -hand_dir)
	rig.rest_pole = Vector3.LEFT   # the elbow wants to swing inward, across the chest
	var pose: Dictionary = ArmPoseSolver.new().solve(rig, contact["bone_tip"], hand_dir, [&"head"])
	_check(bool(pose["valid"]), "a bad rest pole still finds a valid pose (%s)" % [pose["reasons"]])
	_check(absf(float(pose["swivel_deg"])) > 0.0, "search moved off the colliding elbow (swivel %.0f)" % float(pose["swivel_deg"]))
	_check(float(pose["min_clearance_m"]) >= 0.0, "result does not penetrate the body")


func _test_unreachable_target() -> void:
	var rig := Fixtures.make_rig(Fixtures.adult(), &"right", false)
	var pose: Dictionary = ArmPoseSolver.new().solve(rig, Vector3(0.2, 1.45, -1.2), Vector3(0, 0, 1), [])
	_check(not bool(pose["valid"]) and pose["status"] == "out_of_reach", "a target a metre away is out of reach")


func _test_target_behind_the_back() -> void:
	var rig := Fixtures.make_rig(Fixtures.adult(), &"right", false)
	var pose: Dictionary = ArmPoseSolver.new().solve(rig, Vector3(0.0, 1.20, 0.30), Vector3(0, 0, -1), [])
	_check(not bool(pose["valid"]), "a pose through the back is rejected")
	_check((pose["reasons"] as Array).size() > 0, "the rejection says why")


func _test_approach_is_oblique_but_bounded() -> void:
	var p := Fixtures.adult()
	var plan := _plan(p, false)
	_check(float(plan["tilt_deg"]) > 5.0, "a self-poke approaches obliquely (tilt %.0f), not straight into the face" % float(plan["tilt_deg"]))
	var tiny_cone := ArmPoseSolver.new().plan_approach(plan["rig"], func(dir: Vector3) -> Vector3:
		return ContactResolver.resolve(p["nose"], NORMAL, _stack(false), _materials["pads"]["fingertip_pad"], 0.0, PEAK_FORCE, -dir)["bone_tip"], NORMAL, [&"head"], 0.0)
	_check(not bool(tiny_cone["valid"]), "with the cone closed to zero, the straight-in approach is rejected as unreachable by the wrist")


## Collision must be the ONLY thing that changes these results: the obstacle is placed where the
## unobstructed solution puts the arm, and every limit is unchanged.
func _test_collisions_are_enforced() -> void:
	var p := Fixtures.adult()
	var plan := _plan(p, false)
	var hand_dir: Vector3 = plan["hand_dir"]
	var contact := ContactResolver.resolve(p["nose"], NORMAL, _stack(false), _materials["pads"]["fingertip_pad"], 0.0, PEAK_FORCE, -hand_dir)
	var tip: Vector3 = contact["bone_tip"]
	var solver := ArmPoseSolver.new()
	var rig: RefCounted = plan["rig"]

	var free: Dictionary = solver.solve(rig, tip, hand_dir, [&"head"])
	_check(bool(free["valid"]), "unobstructed reference pose is valid")
	var free_elbow: Vector3 = free["elbow"]

	rig.proxies.append(BodyProxy.make(&"obstacle", free_elbow, free_elbow, 0.07))
	var dodged: Dictionary = solver.solve(rig, tip, hand_dir, [&"head"])
	_check(bool(dodged["valid"]), "an obstacle at the elbow can be avoided (%s)" % [dodged["reasons"]])
	_check(absf(float(dodged["swivel_deg"]) - float(free["swivel_deg"])) >= 5.0, "swivel changed to dodge the obstacle")
	_check((dodged["elbow"] as Vector3).distance_to(free_elbow) > 0.03, "elbow moved away from the obstacle")
	_check(float(dodged["min_clearance_m"]) >= 0.0, "dodged pose has clearance")
	rig.proxies.pop_back()

	var wrist: Vector3 = free["wrist"]
	rig.proxies.append(BodyProxy.make(&"wall", wrist, wrist, 0.10))
	var blocked: Dictionary = solver.solve(rig, tip, hand_dir, [&"head"])
	_check(not bool(blocked["valid"]) and blocked["status"] == "no_valid_pose", "an obstacle swallowing the wrist cannot be avoided")
	_check((blocked["reasons"] as Array).has("forearm_collision"), "and the forearm collision is reported")
	rig.proxies.pop_back()

	rig.proxies.append(BodyProxy.make(&"touched", tip, tip, 0.02))
	var touching: Dictionary = solver.solve(rig, tip, hand_dir, [&"head", &"touched"])
	var not_allowed: Dictionary = solver.solve(rig, tip, hand_dir, [&"head"])
	_check(bool(touching["valid"]), "the hand may overlap a surface it is allowed to touch")
	_check(not bool(not_allowed["valid"]) and (not_allowed["reasons"] as Array).has("hand_collision"), "the same overlap is rejected when the surface is not a touch target")
	rig.proxies.pop_back()


func _test_joint_limits_are_enforced() -> void:
	var p := Fixtures.adult()
	var plan := _plan(p, false)
	var rig: RefCounted = plan["rig"]
	var hand_dir: Vector3 = plan["hand_dir"]
	var contact := ContactResolver.resolve(p["nose"], NORMAL, _stack(false), _materials["pads"]["fingertip_pad"], 0.0, PEAK_FORCE, -hand_dir)
	var solver := ArmPoseSolver.new()
	var free: Dictionary = solver.solve(rig, contact["bone_tip"], hand_dir, [&"head"])
	_check(bool(free["valid"]), "reference pose is valid")

	rig.limits.elbow_flexion_max_deg = float(free["elbow_flexion_deg"]) - 10.0
	var tight_elbow: Dictionary = solver.solve(rig, contact["bone_tip"], hand_dir, [&"head"])
	_check(not bool(tight_elbow["valid"]) and (tight_elbow["reasons"] as Array).has("elbow_flexion"), "a tighter elbow limit rejects a pose it used to allow")
	rig.limits.elbow_flexion_max_deg = 150.0

	var behind_tip := Vector3(0.2, 1.12, 0.30)   # fingertip behind the shoulder plane, hand pointing down
	var down := Vector3(0, -1, 0)
	rig.limits.shoulder_extension_max_deg = 180.0
	var relaxed: Dictionary = solver.solve(rig, behind_tip, down, [])
	_check(bool(relaxed["valid"]) and float(relaxed["shoulder_extension_deg"]) > 30.0, "with the shoulder limit relaxed the arm can reach behind itself (extension %.0f)" % float(relaxed["shoulder_extension_deg"]))
	rig.limits.shoulder_extension_max_deg = 25.0
	var capped: Dictionary = solver.solve(rig, behind_tip, down, [])
	_check(not bool(capped["valid"]) or float(capped["shoulder_extension_deg"]) <= 25.01, "a 25 degree shoulder limit is never exceeded by a returned pose")
	_check(not bool(capped["valid"]), "and here it makes the target unreachable")
