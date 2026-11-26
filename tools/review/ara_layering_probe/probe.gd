extends SceneTree
## Review probe (not a CI test): which writer wins when the real AraSkeletonRetargeter and another
## SkeletonModifier3D touch the same bone? Uses two copies of the real carrier, with the source
## animation paused on a fixed pose so frame timing cannot matter.
##
## Run after the carrier GLB has been imported:
##   godot --headless --path . --script res://tools/review/ara_layering_probe/probe.gd
## The harness validates itself (case A). Exit code 1 if any expectation fails.
## Caveats: script errors do not change Godot's exit code; run through tools/ci/run_godot_checked.sh.

const RETARGETER := preload("res://scripts/presentation/ara_skeleton_retargeter.gd")
const OVERRIDE := preload("res://tools/review/ara_layering_probe/override_modifier.gd")
const RECORDER := preload("res://tools/review/ara_layering_probe/recorder_modifier.gd")
const CARRIER_PATH := "res://art/characters/ara_runtime/ara_person_benchmark.glb"
const TOLERANCE_DEG := 0.05

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _find(node: Node, class_name_value: String) -> Node:
	if node.get_class() == class_name_value:
		return node
	for child in node.get_children():
		var found := _find(child, class_name_value)
		if found != null:
			return found
	return null


func _deg(a: Quaternion, b: Quaternion) -> float:
	return rad_to_deg(a.angle_to(b))


func _expect(condition: bool, message: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + message)
	if not condition:
		_failures += 1


func _setup(order: Array, influence: float = 1.0) -> Dictionary:
	var source := (load(CARRIER_PATH) as PackedScene).instantiate()
	var target := (load(CARRIER_PATH) as PackedScene).instantiate()
	get_root().add_child(source)
	get_root().add_child(target)
	var player := _find(source, "AnimationPlayer") as AnimationPlayer
	(_find(target, "AnimationPlayer") as AnimationPlayer).stop()
	var source_skeleton := _find(source, "Skeleton3D") as Skeleton3D
	var target_skeleton := _find(target, "Skeleton3D") as Skeleton3D
	var arm := target_skeleton.find_bone("RightArm")
	var made := {"source": source, "target": target, "source_skeleton": source_skeleton, "arm": arm}
	for kind in order:
		var modifier: SkeletonModifier3D
		match kind:
			"retargeter":
				modifier = RETARGETER.new()
				modifier.call("configure", source_skeleton, target_skeleton)
			"override":
				modifier = OVERRIDE.new()
				modifier.bone = arm
				modifier.rotation_target = Quaternion(Vector3(0, 0, 1), 1.2)
				modifier.influence = influence
				made["override"] = modifier
			"recorder":
				modifier = RECORDER.new()
				modifier.bone = arm
				made["recorder"] = modifier
		target_skeleton.add_child(modifier)
		made["skeleton"] = target_skeleton
	player.play("Walk")
	player.seek(0.35, true)
	player.pause()
	return made


func _settle() -> void:
	for i in range(3):
		await process_frame


func _release(case: Dictionary) -> void:
	case["source"].free()
	case["target"].free()


func _run() -> void:
	await process_frame
	var forced := Quaternion(Vector3(0, 0, 1), 1.2)

	var a := _setup(["retargeter", "recorder"])
	await _settle()
	var animation_pose: Quaternion = a.source_skeleton.get_bone_pose_rotation(a.arm)
	var rest_pose: Quaternion = a.source_skeleton.get_bone_rest(a.arm).basis.get_rotation_quaternion()
	_expect(_deg(animation_pose, rest_pose) > 5.0, "harness: the paused animation pose differs from rest (%.1f deg)" % _deg(animation_pose, rest_pose))
	_expect(_deg(a.recorder.last, animation_pose) < TOLERANCE_DEG, "A: identical rigs, retargeter reproduces the animation pose (%.3f deg)" % _deg(a.recorder.last, animation_pose))
	_release(a)

	var b := _setup(["retargeter", "override", "recorder"])
	await _settle()
	_expect(_deg(b.recorder.last, forced) < TOLERANCE_DEG, "B: a modifier AFTER the retargeter wins (%.3f deg from override)" % _deg(b.recorder.last, forced))
	_release(b)

	var c := _setup(["override", "retargeter", "recorder"])
	await _settle()
	var c_animation: Quaternion = c.source_skeleton.get_bone_pose_rotation(c.arm)
	_expect(_deg(c.recorder.last, c_animation) < TOLERANCE_DEG, "C: a modifier BEFORE the retargeter is overwritten (%.3f deg from animation)" % _deg(c.recorder.last, c_animation))
	_release(c)

	var d := _setup(["retargeter", "override", "recorder"], 0.5)
	await _settle()
	var d_animation: Quaternion = d.source_skeleton.get_bone_pose_rotation(d.arm)
	var halfway := d_animation.slerp(forced, 0.5)
	_expect(_deg(d.recorder.last, halfway) < TOLERANCE_DEG, "D: influence 0.5 gives the exact halfway blend (%.3f deg from slerp)" % _deg(d.recorder.last, halfway))
	_release(d)

	var e := _setup(["retargeter", "recorder"])
	e.skeleton.set_bone_pose_rotation(e.arm, forced)
	await _settle()
	var e_animation: Quaternion = e.source_skeleton.get_bone_pose_rotation(e.arm)
	_expect(_deg(e.recorder.last, e_animation) < TOLERANCE_DEG, "E: a plain set_bone_pose_rotation outside any modifier is overwritten (%.3f deg from animation)" % _deg(e.recorder.last, e_animation))
	_release(e)

	var f := _setup(["retargeter", "override", "recorder"])
	await _settle()
	f.override.active = false
	await _settle()
	var f_animation: Quaternion = f.source_skeleton.get_bone_pose_rotation(f.arm)
	_expect(_deg(f.recorder.last, f_animation) < TOLERANCE_DEG, "F: switching the modifier off returns to the animation with no residue (%.3f deg)" % _deg(f.recorder.last, f_animation))
	_release(f)

	print("PROBE RESULT: %s" % ("all expectations held" if _failures == 0 else "%d expectation(s) failed" % _failures))
	quit(1 if _failures > 0 else 0)
