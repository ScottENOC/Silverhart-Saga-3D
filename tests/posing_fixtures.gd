extends RefCounted
## Synthetic characters for posing tests. Rig space: x = character right, y = up,
## forward = up.cross(right) = -z. Two proportions so tests cannot pass by tuning to one body.

const ArmRig := preload("res://scripts/posing/arm_rig.gd")
const BodyProxy := preload("res://scripts/posing/body_proxy.gd")

const LIMITS_PATH := "res://data/posing/arm_joint_limits.json"
const MATERIALS_PATH := "res://data/posing/contact_materials.json"

## scale: uniform body scale. arm_ratio: forearm length multiplier (changes proportions).
static func character_params(scale: float, arm_ratio: float) -> Dictionary:
	return {
		"scale": scale,
		"shoulder_x": 0.20 * scale,
		"shoulder_y": 1.45 * scale,
		"upper_len": 0.30 * scale,
		"fore_len": 0.26 * scale * arm_ratio,
		"hand_len": 0.18 * scale,
		"head_y": 1.58 * scale,
		"nose": Vector3(0.0, 1.60 * scale, -0.105 * scale),
	}


static func adult() -> Dictionary:
	return character_params(1.0, 1.0)


static func small() -> Dictionary:
	return character_params(0.82, 1.08)


static func proxies_for(p: Dictionary, with_helm: bool = false) -> Array:
	var s: float = p["scale"]
	var list: Array = [
		BodyProxy.make(&"torso", Vector3(0, 1.05, 0) * s, Vector3(0, 1.45, 0) * s, 0.15 * s),
		BodyProxy.make(&"pelvis", Vector3(0, 0.88, 0) * s, Vector3(0, 1.0, 0) * s, 0.16 * s),
		BodyProxy.make(&"head", Vector3(0, 1.58, 0) * s, Vector3(0, 1.66, 0) * s, 0.095 * s),
	]
	if with_helm:
		list.append(BodyProxy.make(&"helm", Vector3(0, 1.58, 0) * s, Vector3(0, 1.66, 0) * s, 0.125 * s))
	return list


static func make_rig(p: Dictionary, side: StringName = &"right", with_helm: bool = false) -> RefCounted:
	var rig: RefCounted = ArmRig.new()
	var sign_value := 1.0 if side == &"right" else -1.0
	rig.side = side
	rig.shoulder = Vector3(sign_value * p["shoulder_x"], p["shoulder_y"], 0.0)
	rig.upper_len = p["upper_len"]
	rig.fore_len = p["fore_len"]
	rig.hand_len = p["hand_len"]
	rig.frame_right = Vector3.RIGHT
	rig.frame_up = Vector3.UP
	rig.frame_forward = Vector3.UP.cross(Vector3.RIGHT)
	rig.rest_pole = (Vector3.DOWN + Vector3.RIGHT * 0.35 * sign_value).normalized()
	rig.upper_radius = 0.04 * p["scale"]
	rig.fore_radius = 0.035 * p["scale"]
	rig.hand_radius = 0.03 * p["scale"]
	rig.proxies = proxies_for(p, with_helm)
	rig.limits.load_json(LIMITS_PATH)
	return rig


## Mixamo-style skeleton in an "arms hanging" rest pose, identity bone rotations.
## Bone positions are model space; local rests are offsets from the parent.
## Pass the scene-tree root as `parent`: in Godot 4.7.2 a Skeleton3D outside the tree keeps stale
## global poses after its bones are modified, so tests must use in-tree skeletons.
static func make_skeleton(p: Dictionary, omit: Array = [], parent: Node = null) -> Skeleton3D:
	var s: float = p["scale"]
	var sx: float = p["shoulder_x"]
	var sy: float = p["shoulder_y"]
	var elbow_y: float = sy - p["upper_len"]
	var wrist_y: float = elbow_y - p["fore_len"]
	var h: float = p["hand_len"]
	# name, parent, model-space position
	var bones: Array = [
		["Hips", "", Vector3(0, 0.95 * s, 0)],
		["Spine", "Hips", Vector3(0, 1.05 * s, 0)],
		["Spine1", "Spine", Vector3(0, 1.20 * s, 0)],
		["Spine2", "Spine1", Vector3(0, 1.35 * s, 0)],
		["Neck", "Spine2", Vector3(0, 1.50 * s, 0)],
		["Head", "Neck", Vector3(0, p["head_y"], 0)],
	]
	for side in ["Left", "Right"]:
		var x := sx if side == "Right" else -sx
		bones.append([side + "Arm", "Spine2", Vector3(x, sy, 0)])
		bones.append([side + "ForeArm", side + "Arm", Vector3(x, elbow_y, 0)])
		bones.append([side + "Hand", side + "ForeArm", Vector3(x, wrist_y, 0)])
		bones.append([side + "HandMiddle1", side + "Hand", Vector3(x, wrist_y - h * 0.28, 0)])
		bones.append([side + "HandMiddle2", side + "HandMiddle1", Vector3(x, wrist_y - h * 0.56, 0)])
		bones.append([side + "HandMiddle3", side + "HandMiddle2", Vector3(x, wrist_y - h * 0.78, 0)])
		bones.append([side + "HandMiddle4", side + "HandMiddle3", Vector3(x, wrist_y - h, 0)])

	var skeleton := Skeleton3D.new()
	if parent != null:
		parent.add_child(skeleton)
	var positions := {}
	var skipped: Array = omit.duplicate()   # an omitted bone takes its descendants with it
	for entry in bones:
		if skipped.has(entry[0]) or skipped.has(entry[1]):
			skipped.append(entry[0])
			continue
		var index := skeleton.add_bone(entry[0])
		positions[entry[0]] = entry[2]
		if entry[1] != "":
			skeleton.set_bone_parent(index, skeleton.find_bone(entry[1]))
			skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, entry[2] - positions[entry[1]]))
		else:
			skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, entry[2]))
	skeleton.reset_bone_poses()
	return skeleton
