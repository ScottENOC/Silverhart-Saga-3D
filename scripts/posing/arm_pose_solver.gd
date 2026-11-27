extends RefCounted
## Solves one arm so the fingertip bone reaches a target, respecting joint limits
## and body collision proxies.
##
## Two stages, because a touch has a free choice that animation must keep stable:
##  1. plan_approach(): once per touch, choose the direction the finger travels in (within a cone
##     around the surface normal) and a swivel. Cost favours low wrist bend and near-perpendicular
##     contact. The planned hand_dir is then held constant for the whole motion.
##  2. solve(): per frame, reach the current tip target with that hand_dir. The elbow swivel is
##     searched outward from a hint (the previous frame's swivel) so the elbow moves continuously.
##
## Swivel search: analytic two-bone IK leaves one free angle (elbow rotation about the
## shoulder->wrist axis). Candidates are tried in order of distance from the hint and the first
## reachable, within-limit, collision-free pose is returned, so results are deterministic.

const BodyProxy := preload("res://scripts/posing/body_proxy.gd")
const TwoBoneIK := preload("res://scripts/posing/ik_two_bone.gd")

const SWIVEL_STEP_DEG := 5.0
const PLAN_SWIVEL_STEP_DEG := 10.0
const TILT_STEP_DEG := 10.0
const AZIMUTH_STEP_DEG := 30.0
const TILT_COST_PER_DEG := 0.5


## Chooses the approach direction for a touch.
## `tip_for_dir`: Callable(hand_dir: Vector3) -> Vector3, the fingertip BONE target when the finger
## arrives travelling along hand_dir at full load (it depends on direction through the pad offset).
## Returns {valid, hand_dir, tilt_deg, swivel_deg, pose}; when invalid, `pose` is the least-bad candidate.
func plan_approach(rig: RefCounted, tip_for_dir: Callable, surface_normal: Vector3, touch_ids: Array = [], cone_deg: float = 60.0) -> Dictionary:
	var n := surface_normal.normalized()
	var u := n.cross(rig.frame_up)
	if u.length_squared() < 1e-8:
		u = n.cross(rig.frame_right)
	u = u.normalized()
	var v := n.cross(u).normalized()

	var best_cost := INF
	var best := {"valid": false, "hand_dir": -n, "tilt_deg": 0.0, "swivel_deg": 0.0, "pose": {}}
	var fallback_reasons := 9999
	var tilt := 0.0
	while tilt <= cone_deg + 1e-6:
		var azimuths := [0.0] if tilt < 1e-6 else _range_step(0.0, 360.0 - AZIMUTH_STEP_DEG + 1e-6, AZIMUTH_STEP_DEG)
		for az_deg in azimuths:
			var az := deg_to_rad(az_deg)
			var tilt_rad := deg_to_rad(tilt)
			var hand_dir: Vector3 = (-n * cos(tilt_rad) + (u * cos(az) + v * sin(az)) * sin(tilt_rad)).normalized()
			var target: Vector3 = tip_for_dir.call(hand_dir)
			var pose := solve(rig, target, hand_dir, touch_ids, 0.0, PLAN_SWIVEL_STEP_DEG)
			if bool(pose["valid"]):
				var cost: float = float(pose["wrist_deviation_deg"]) + TILT_COST_PER_DEG * tilt
				if cost < best_cost:
					best_cost = cost
					best = {"valid": true, "hand_dir": hand_dir, "tilt_deg": tilt, "swivel_deg": pose["swivel_deg"], "pose": pose}
			elif not bool(best["valid"]) and (pose["reasons"] as Array).size() < fallback_reasons:
				fallback_reasons = (pose["reasons"] as Array).size()
				best = {"valid": false, "hand_dir": hand_dir, "tilt_deg": tilt, "swivel_deg": pose["swivel_deg"], "pose": pose}
		tilt += TILT_STEP_DEG
	return best


## `hand_dir`: unit vector wrist -> fingertip. `touch_ids`: proxy ids the HAND may overlap
## (the surface being touched); the upper arm and forearm may never overlap any proxy.
## Returns {valid, status, reasons, swivel_deg, shoulder, elbow, wrist, tip, hand_dir,
##          elbow_flexion_deg, shoulder_extension_deg, wrist_deviation_deg, min_clearance_m}.
## status is "ok", "out_of_reach" or "no_valid_pose".
func solve(rig: RefCounted, tip_target: Vector3, hand_dir: Vector3, touch_ids: Array = [], swivel_hint_deg: float = 0.0, swivel_step_deg: float = SWIVEL_STEP_DEG) -> Dictionary:
	var dir := hand_dir.normalized()
	var wrist_target: Vector3 = tip_target - dir * float(rig.hand_len)

	var first := _evaluate(rig, wrist_target, dir, touch_ids, deg_to_rad(swivel_hint_deg))
	if first["status"] == "out_of_reach":
		return first
	if bool(first["valid"]):
		return first

	var best := first
	var steps := int(180.0 / swivel_step_deg)
	for i in range(1, steps + 1):
		for sign_value in [1.0, -1.0]:
			var angle: float = swivel_hint_deg + swivel_step_deg * float(i) * sign_value
			var candidate := _evaluate(rig, wrist_target, dir, touch_ids, deg_to_rad(angle))
			if bool(candidate["valid"]):
				return candidate
			if (candidate["reasons"] as Array).size() < (best["reasons"] as Array).size():
				best = candidate
	best["status"] = "no_valid_pose"
	return best


func _evaluate(rig: RefCounted, wrist_target: Vector3, hand_dir: Vector3, touch_ids: Array, swivel_rad: float) -> Dictionary:
	var ik := TwoBoneIK.solve(rig.shoulder, wrist_target, rig.upper_len, rig.fore_len, rig.rest_pole, swivel_rad)
	var elbow: Vector3 = ik["mid"]
	var wrist: Vector3 = ik["end"]
	var tip: Vector3 = wrist + hand_dir * float(rig.hand_len)
	var reasons: Array = []

	var upper_dir: Vector3 = (elbow - rig.shoulder).normalized()
	var fore_dir: Vector3 = (wrist - elbow).normalized()
	var extension: float = rig.limits.shoulder_extension_deg(upper_dir, rig.frame_forward)
	var deviation := rad_to_deg(acos(clampf(fore_dir.dot(hand_dir), -1.0, 1.0)))
	var flexion: float = ik["flexion_deg"]

	if not bool(ik["reached"]):
		reasons.append("out_of_reach")
	for violation in rig.limits.violations(flexion, extension, deviation):
		reasons.append(violation)

	var upper_start: Vector3 = rig.shoulder + upper_dir * minf(rig.root_skip_m, rig.upper_len * 0.9)
	var upper_clear := BodyProxy.min_clearance(upper_start, elbow, rig.upper_radius, rig.proxies)
	var fore_clear := BodyProxy.min_clearance(elbow, wrist, rig.fore_radius, rig.proxies)
	var hand_clear := BodyProxy.min_clearance(wrist, tip, rig.hand_radius, rig.proxies, touch_ids)
	if upper_clear < 0.0:
		reasons.append("upper_arm_collision")
	if fore_clear < 0.0:
		reasons.append("forearm_collision")
	if hand_clear < 0.0:
		reasons.append("hand_collision")

	var status := "ok"
	if not reasons.is_empty():
		status = "out_of_reach" if reasons.has("out_of_reach") else "no_valid_pose"
	return {
		"valid": reasons.is_empty(),
		"status": status,
		"reasons": reasons,
		"swivel_deg": rad_to_deg(swivel_rad),
		"shoulder": rig.shoulder,
		"elbow": elbow,
		"wrist": wrist,
		"tip": tip,
		"hand_dir": hand_dir,
		"elbow_flexion_deg": flexion,
		"shoulder_extension_deg": extension,
		"wrist_deviation_deg": deviation,
		"min_clearance_m": minf(upper_clear, minf(fore_clear, hand_clear)),
	}


static func _range_step(from_value: float, to_value: float, step: float) -> Array:
	var result: Array = []
	var x := from_value
	while x <= to_value:
		result.append(x)
		x += step
	return result
