extends SceneTree
## Ensures shared Ara clips drive each character's native skeleton without
## replacing its bone rests or rebinding its skinned meshes.

const ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const BODY_PATHS := [
	"res://art/characters/ara_runtime/ara_player_female_body.glb",
	"res://art/characters/ara_runtime/ara_player_male_body.glb"
]
const CHARACTER_ASSET_PATHS := [
	"res://art/characters/companions/aldric.glb",
	"res://art/characters/companions/dagna.glb",
	"res://art/characters/companions/wren.glb",
	"res://art/characters/hollowmere/brother_alden.glb",
	"res://art/characters/hollowmere/dray.glb",
	"res://art/characters/hollowmere/elder_marta.glb",
	"res://art/characters/hollowmere/fenn_oakheart.glb",
	"res://art/characters/hollowmere/garrick_holt.glb",
	"res://art/characters/hollowmere/hask.glb",
	"res://art/characters/hollowmere/hendra.glb",
	"res://art/characters/hollowmere/mira_ashbrook.glb",
	"res://art/characters/hollowmere/mirabel_quill.glb",
	"res://art/characters/hollowmere/nix_sharpear.glb",
	"res://art/characters/hollowmere/oskar_vinn.glb",
	"res://art/characters/hollowmere/player_avatar.glb",
	"res://art/characters/hollowmere/reyna_fletcher.glb",
	"res://art/characters/hollowmere/rowan_fletcher.glb",
	"res://art/characters/hollowmere/ser_aldric_thorne.glb",
	"res://art/characters/hollowmere/snik_fangtooth.glb",
	"res://art/characters/hollowmere/tavern_patron.glb",
	"res://art/characters/hollowmere/tomlin.glb",
	"res://art/characters/hollowmere/warlord_grukk_ironhide.glb",
	"res://art/characters/hollowmere/wick_hallow.glb",
	"res://art/characters/hollowmere/wren_talbot.glb",
	"res://art/characters/hollowmere/yvette.glb"
]
const CARRIER_PATH := "res://art/characters/ara_runtime/ara_person_benchmark.glb"
const FACIAL_BONES := ["Jaw", "LeftEye", "RightEye"]

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ResourceLoader.exists(CARRIER_PATH), "Shared Ara animation source is installed")
	for body_path in BODY_PATHS:
		_check(ResourceLoader.exists(body_path), "Player body is installed: " + body_path.get_file())
	if failures > 0:
		_finish()
		return

	await _test_character(BODY_PATHS[0], "Ara female player body", true)
	await _test_character(BODY_PATHS[1], "Ara male player body", true)
	for asset_path in CHARACTER_ASSET_PATHS:
		await _test_character(asset_path, asset_path.get_file().get_basename(), false)
	_finish()


func _test_character(asset_path: String, label: String, check_face_rests: bool) -> void:
	var actor := ACTOR_SCRIPT.new()
	root.add_child(actor)
	var configured: bool = actor.configure(asset_path)
	_check(configured, label + " configures")
	if not configured:
		actor.queue_free()
		return
	await process_frame

	var target_skeleton := _find_skeleton(actor.model_root)
	var source_skeleton := _find_skeleton(actor.animation_source_root) if actor.animation_source_root != null else null
	var player := actor.animation_player as AnimationPlayer
	_check(target_skeleton != null, label + " retains its native Skeleton3D")
	_check(source_skeleton != null, label + " has the shared animation source skeleton")
	_check(player != null, label + " receives the shared AnimationPlayer")
	_check(actor.skeleton_retargeter != null, label + " installs a live skeleton retargeter")
	if target_skeleton == null or source_skeleton == null or player == null or actor.skeleton_retargeter == null:
		actor.queue_free()
		return

	_check(target_skeleton != source_skeleton, label + " keeps source and target skeletons separate")
	_check(actor.model_root != actor.animation_source_root, label + " keeps the original character scene as the visible model")
	_check(absf(wrapf(actor.model_root.rotation.y - PI, -PI, PI)) < 0.001,
		label + " model forward axis is aligned with world actor heading")

	var visible_native_mesh := false
	var target_meshes: Array[MeshInstance3D] = []
	_collect_meshes(actor.model_root, target_meshes)
	for mesh in target_meshes:
		if mesh.visible and mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == target_skeleton:
			visible_native_mesh = true
			break
	_check(visible_native_mesh, label + " visible skinned mesh remains bound to its native skeleton")

	var source_meshes: Array[MeshInstance3D] = []
	_collect_meshes(actor.animation_source_root, source_meshes)
	for mesh in source_meshes:
		if mesh.mesh != null:
			_check(not mesh.visible, label + " hides benchmark-only mesh " + mesh.name)

	var facial_rests: Dictionary = {}
	if check_face_rests:
		for bone_name in FACIAL_BONES:
			var target_index := target_skeleton.find_bone(bone_name)
			var source_index := source_skeleton.find_bone(bone_name)
			_check(target_index >= 0, label + " contains native facial bone " + bone_name)
			_check(source_index >= 0, label + " animation source contains facial bone " + bone_name)
			if target_index < 0 or source_index < 0:
				continue
			var target_rest := target_skeleton.get_bone_rest(target_index)
			var source_rest := source_skeleton.get_bone_rest(source_index)
			facial_rests[bone_name] = target_rest
			if bone_name == "Jaw":
				_check(target_rest.origin.distance_to(source_rest.origin) > 0.025,
					label + " jaw retains its distinct native rest position")
	_check(actor.set_moving(true), label + " selects a locomotion clip")
	var clip_name := player.current_animation.to_lower()
	_check(clip_name.contains("walk") or clip_name.contains("locomotion") or clip_name.contains("run"),
		label + " plays a locomotion clip")

	var starting_poses: Array[Transform3D] = []
	var starting_source_poses: Array[Transform3D] = []
	for bone_index in range(target_skeleton.get_bone_count()):
		starting_poses.append(target_skeleton.get_bone_pose(bone_index))
	for bone_index in range(source_skeleton.get_bone_count()):
		starting_source_poses.append(source_skeleton.get_bone_global_pose(bone_index))
	var modifier_calls_before: int = actor.skeleton_retargeter.process_call_count
	await create_timer(0.3).timeout
	var changed_bones := 0
	var changed_source_bones := 0
	for bone_index in range(source_skeleton.get_bone_count()):
		if not source_skeleton.get_bone_global_pose(bone_index).is_equal_approx(starting_source_poses[bone_index]):
			changed_source_bones += 1
	for bone_index in range(target_skeleton.get_bone_count()):
		if not target_skeleton.get_bone_pose(bone_index).is_equal_approx(starting_poses[bone_index]):
			changed_bones += 1
	print("ARA_RETARGET_DIAGNOSTIC label=%s clip=%s source_changed=%d modifier_calls=%d target_changed=%d source_root=%s" % [label, player.current_animation, changed_source_bones, actor.skeleton_retargeter.process_call_count - modifier_calls_before, changed_bones, player.root_node])
	print("ARA_RETARGET_WRITE_DIAGNOSTIC label=%s writes=%d changed_writes=%d source_pose=%s output_pose=%s readback_pose=%s" % [label, actor.skeleton_retargeter.write_count, actor.skeleton_retargeter.changed_write_count, actor.skeleton_retargeter.last_source_pose, actor.skeleton_retargeter.last_written_pose, actor.skeleton_retargeter.last_readback_pose])
	_check(changed_source_bones >= 5,
		label + " locomotion animates the benchmark source skeleton (%d changed bones)" % changed_source_bones)
	_check(actor.skeleton_retargeter.process_call_count > modifier_calls_before,
		label + " executes the SkeletonModifier3D callback")
	_check(changed_bones >= 5,
		label + " locomotion drives the native skeleton (%d changed bones)" % changed_bones)

	for bone_name in facial_rests:
		var bone_index := target_skeleton.find_bone(bone_name)
		_check(target_skeleton.get_bone_rest(bone_index).is_equal_approx(facial_rests[bone_name]),
			label + " preserves native " + bone_name + " rest transform during animation")

	_check(actor.set_moving(false), label + " returns to idle")
	actor.queue_free()
	await process_frame


func _find_skeleton(node: Node) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures > 0:
		push_error("ARA_NATIVE_RIG_RETARGET_TEST: %d failure(s)" % failures)
		quit(1)
		return
	print("ARA_NATIVE_RIG_RETARGET_TEST: PASS")
	quit(0)
