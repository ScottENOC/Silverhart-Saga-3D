extends RefCounted
## Builds an ArmRig from a Skeleton3D. All positions are skeleton model space
## (Skeleton3D.get_bone_global_pose), so no node transforms are involved.
##
## Frame: right = left shoulder -> right shoulder; up = hips -> head, made orthogonal to right;
## forward = up.cross(right). Bone names are matched by alias, ignoring case, '_', '-', ':' and
## any namespace prefix (e.g. "mixamorig:RightArm").

const ArmRigScript := preload("res://scripts/posing/arm_rig.gd")
const BodyProxy := preload("res://scripts/posing/body_proxy.gd")

const LIMITS_PATH := "res://data/posing/arm_joint_limits.json"
const RADIUS_FRACTIONS := {"upper": 0.13, "fore": 0.135, "hand": 0.165}
const REST_POLE_OUTWARD := 0.35
const FALLBACK_HAND_FRACTION := 0.7   # hand length as a fraction of forearm length, when no finger chain exists
const FINGER_CHAIN_MAX := 5

const ALIASES := {
	"hips": ["Hips", "Hip", "Pelvis"],
	"spine": ["Spine", "Spine1"],
	"spine_top": ["Spine2", "Spine3", "Chest"],
	"head": ["Head"],
}


static func normalise(value: String) -> String:
	return value.to_lower().replace("_", "").replace("-", "").replace(" ", "").replace(":", "")


## Index of the first bone matching any alias: exact (normalised) match first, then namespace suffix.
static func find_bone(skeleton: Skeleton3D, aliases: Array) -> int:
	var wanted: Array[String] = []
	for alias in aliases:
		wanted.append(normalise(String(alias)))
	for want in wanted:
		for i in range(skeleton.get_bone_count()):
			if normalise(skeleton.get_bone_name(i)) == want:
				return i
	for want in wanted:
		for i in range(skeleton.get_bone_count()):
			var actual := normalise(skeleton.get_bone_name(i))
			if actual.ends_with(want) and actual.length() > want.length() and not actual.ends_with("fore" + want):
				return i
	return -1


## Resolves the bones one arm needs. Returns {} if the upper arm, forearm or hand is missing.
## `finger_tip` is -1 when the model has no middle-finger chain.
static func arm_bones(skeleton: Skeleton3D, side: StringName) -> Dictionary:
	var prefix := "Right" if side == &"right" else "Left"
	var upper := find_bone(skeleton, [prefix + "Arm", prefix + "UpperArm"])
	var fore := find_bone(skeleton, [prefix + "ForeArm", prefix + "LowerArm"])
	var hand := find_bone(skeleton, [prefix + "Hand", prefix + "Wrist"])
	if upper < 0 or fore < 0 or hand < 0:
		return {}
	var tip := -1
	for n in range(1, FINGER_CHAIN_MAX + 1):
		var finger := find_bone(skeleton, ["%sHandMiddle%d" % [prefix, n]])
		if finger >= 0:
			tip = finger
	return {"upper": upper, "fore": fore, "hand": hand, "finger_tip": tip}


static func _origin(skeleton: Skeleton3D, bone: int) -> Vector3:
	return skeleton.get_bone_global_pose(bone).origin


static func from_skeleton(skeleton: Skeleton3D, side: StringName, options: Dictionary = {}) -> RefCounted:
	var bones := arm_bones(skeleton, side)
	var other_prefix := "Left" if side == &"right" else "Right"
	var other_upper := find_bone(skeleton, [other_prefix + "Arm", other_prefix + "UpperArm"])
	var hips := find_bone(skeleton, ALIASES["hips"])
	var head := find_bone(skeleton, ALIASES["head"])
	if bones.is_empty() or other_upper < 0 or hips < 0 or head < 0:
		push_warning("ArmRigBuilder: skeleton lacks the bones needed for the %s arm." % side)
		return null

	var rig: RefCounted = ArmRigScript.new()
	rig.side = side
	rig.shoulder = _origin(skeleton, bones["upper"])
	var elbow := _origin(skeleton, bones["fore"])
	var wrist := _origin(skeleton, bones["hand"])
	rig.upper_len = rig.shoulder.distance_to(elbow)
	rig.fore_len = elbow.distance_to(wrist)

	if options.has("hand_length_m"):
		rig.hand_len = float(options["hand_length_m"])
	elif int(bones["finger_tip"]) >= 0:
		rig.hand_len = wrist.distance_to(_origin(skeleton, bones["finger_tip"]))
	else:
		rig.hand_len = rig.fore_len * FALLBACK_HAND_FRACTION
		push_warning("ArmRigBuilder: no finger chain; estimating hand length.")

	var side_sign := 1.0 if side == &"right" else -1.0
	var right_shoulder: Vector3 = rig.shoulder if side == &"right" else _origin(skeleton, other_upper)
	var left_shoulder: Vector3 = _origin(skeleton, other_upper) if side == &"right" else rig.shoulder
	var frame_right := (right_shoulder - left_shoulder).normalized()
	var hips_pos := _origin(skeleton, hips)
	var head_pos := _origin(skeleton, head)
	var up_raw := head_pos - hips_pos
	var frame_up := (up_raw - frame_right * up_raw.dot(frame_right)).normalized()
	rig.frame_right = frame_right
	rig.frame_up = frame_up
	rig.frame_forward = frame_up.cross(frame_right)
	rig.rest_pole = (-frame_up + frame_right * REST_POLE_OUTWARD * side_sign).normalized()

	rig.upper_radius = RADIUS_FRACTIONS["upper"] * rig.upper_len
	rig.fore_radius = RADIUS_FRACTIONS["fore"] * rig.fore_len
	rig.hand_radius = RADIUS_FRACTIONS["hand"] * rig.hand_len
	rig.limits.load_json(LIMITS_PATH)

	if options.has("proxies"):
		rig.proxies = options["proxies"]
	else:
		rig.proxies = _default_proxies(skeleton, left_shoulder, right_shoulder, hips_pos, head_pos, frame_up)
	return rig


## Coarse torso/head/pelvis capsules sized from shoulder width. Characters with unusual
## builds should pass their own via options["proxies"].
static func _default_proxies(skeleton: Skeleton3D, left_shoulder: Vector3, right_shoulder: Vector3, hips_pos: Vector3, head_pos: Vector3, frame_up: Vector3) -> Array:
	var half_width := left_shoulder.distance_to(right_shoulder) * 0.5
	var spine := find_bone(skeleton, ALIASES["spine"])
	var spine_pos := _origin(skeleton, spine) if spine >= 0 else hips_pos
	var shoulder_mid := (left_shoulder + right_shoulder) * 0.5
	var torso_top := spine_pos + frame_up * maxf(0.0, (shoulder_mid - spine_pos).dot(frame_up))
	var head_radius := 0.475 * half_width
	return [
		BodyProxy.make(&"torso", spine_pos, torso_top, 0.75 * half_width),
		BodyProxy.make(&"pelvis", hips_pos - frame_up * 0.35 * half_width, hips_pos + frame_up * 0.25 * half_width, 0.8 * half_width),
		BodyProxy.make(&"head", head_pos, head_pos + frame_up * 0.8 * head_radius, head_radius),
	]
