extends SceneTree
## Verifies that a real gameplay Ara body is bound to the shared animated rig.

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
const MAX_REST_ORIGIN_DELTA_METRES := 0.025

var failures: int = 0
var reference_skeleton: Skeleton3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for body_path in BODY_PATHS:
		_check(ResourceLoader.exists(body_path), "Gameplay Ara body asset is available: " + body_path.get_file())
	_check(ResourceLoader.exists("res://art/characters/ara_runtime/ara_person_benchmark.glb"),
		"Animated Ara benchmark carrier is available")
	if failures > 0:
		_finish()
		return

	var carrier_packed := load(CARRIER_PATH) as PackedScene
	_check(carrier_packed != null, "Animated benchmark imports as a PackedScene")
	if carrier_packed == null:
		_finish()
		return
	var carrier_root := carrier_packed.instantiate() as Node3D
	root.add_child(carrier_root)
	reference_skeleton = _find_skeleton(carrier_root)
	_check(reference_skeleton != null, "Animated benchmark exposes the reference Skeleton3D")
	if reference_skeleton == null:
		_finish()
		return

	_check_source_rig_compatible(BODY_PATHS[0], "Ara female player body")
	_check_source_rig_compatible(BODY_PATHS[1], "Ara male player body")

	var actor := ACTOR_SCRIPT.new()
	root.add_child(actor)
	var female_configured: bool = actor.configure(BODY_PATHS[0])
	_check(female_configured, "Ara female gameplay actor configures from its body asset")
	if female_configured:
		_check(absf(wrapf(actor.model_root.rotation.y - PI, -PI, PI)) < 0.001,
			"Ara female model forward axis is aligned with the world actor heading")
	if not female_configured:
		actor.free()
		_finish()
		return
	await process_frame

	var animation_player := actor.animation_player as AnimationPlayer
	_check(animation_player != null, "Female gameplay actor receives the benchmark AnimationPlayer")
	var skeleton := _find_skeleton(actor.model_root)
	_check(skeleton != null, "Female gameplay actor has the animated carrier Skeleton3D")
	if animation_player == null or skeleton == null:
		_finish()
		return

	var visible_bound_meshes := 0
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(actor.model_root, meshes)
	for mesh in meshes:
		if mesh.visible and mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == skeleton:
			visible_bound_meshes += 1
	_check(visible_bound_meshes > 0,
		"Visible gameplay body meshes are bound to the animated carrier skeleton")

	_check(actor.set_moving(true), "Gameplay actor selects a real walk/locomotion clip")
	_check(animation_player.current_animation.to_lower().contains("walk")
		or animation_player.current_animation.to_lower().contains("locomotion")
		or animation_player.current_animation.to_lower().contains("run"),
		"Gameplay actor plays a locomotion clip")

	var starting_poses: Array[Transform3D] = []
	for bone_index in range(skeleton.get_bone_count()):
		starting_poses.append(skeleton.get_bone_global_pose(bone_index))
	await create_timer(0.3).timeout
	var changed_bones := 0
	for bone_index in range(skeleton.get_bone_count()):
		if not skeleton.get_bone_global_pose(bone_index).is_equal_approx(starting_poses[bone_index]):
			changed_bones += 1
	_check(changed_bones >= 5,
		"Gameplay walk animation drives the visible character skeleton (%d changed bones)" % changed_bones)

	_check(actor.set_moving(false), "Gameplay actor returns to an idle clip")
	_check(animation_player.current_animation.to_lower().contains("idle")
		or animation_player.current_animation.to_lower().contains("stand"),
		"Gameplay actor selects its idle clip")

	actor.free()
	var male_actor := ACTOR_SCRIPT.new()
	root.add_child(male_actor)
	var male_configured: bool = male_actor.configure(BODY_PATHS[1])
	_check(male_configured, "Ara male gameplay actor configures from its body asset")
	if male_configured:
		_check(absf(wrapf(male_actor.model_root.rotation.y - PI, -PI, PI)) < 0.001,
			"Ara male model forward axis is aligned with the world actor heading")
	if not male_configured:
		male_actor.free()
		_finish()
		return
	await process_frame
	var male_animation_player := male_actor.animation_player as AnimationPlayer
	var male_skeleton := _find_skeleton(male_actor.model_root)
	_check(male_animation_player != null, "Male gameplay actor receives the benchmark AnimationPlayer")
	_check(male_skeleton != null, "Male gameplay actor has the animated carrier Skeleton3D")
	if male_animation_player != null and male_skeleton != null:
		_check(male_skeleton.get_bone_count() >= 72,
			"Male gameplay rig retains shared animation bones and additional anatomy bones")
		for anatomy_bone in ["AnatomyRoot", "AnatomyMid", "AnatomyTip"]:
			_check(male_skeleton.find_bone(anatomy_bone) >= 0,
				"Male gameplay rig preserves independently controlled " + anatomy_bone)
		var male_locomotion_selected := male_actor.set_moving(true)
		_check(male_locomotion_selected, "Male gameplay actor selects a real locomotion clip")
		if male_locomotion_selected:
			var male_starting_poses: Array[Transform3D] = []
			for bone_index in range(male_skeleton.get_bone_count()):
				male_starting_poses.append(male_skeleton.get_bone_global_pose(bone_index))
			await create_timer(0.3).timeout
			var male_changed_bones := 0
			for bone_index in range(male_skeleton.get_bone_count()):
				if not male_skeleton.get_bone_global_pose(bone_index).is_equal_approx(male_starting_poses[bone_index]):
					male_changed_bones += 1
			_check(male_changed_bones >= 5,
				"Male gameplay walk animation drives its skeleton (%d changed bones)" % male_changed_bones)
	male_actor.free()

	for asset_path in CHARACTER_ASSET_PATHS:
		await _assert_character_asset_animated(asset_path, asset_path.get_file().get_basename())
	_finish()


func _check_source_rig_compatible(asset_path: String, label: String) -> void:
	var packed := load(asset_path) as PackedScene
	_check(packed != null, label + " source asset imports")
	if packed == null:
		return
	var source_root := packed.instantiate() as Node3D
	var source_skeleton := _find_skeleton(source_root)
	_check(source_skeleton != null, label + " source asset contains a skeleton")
	if source_skeleton == null:
		source_root.free()
		return
	_check(source_skeleton.get_bone_count() >= reference_skeleton.get_bone_count(),
		label + " contains every benchmark animation bone")
	if source_skeleton.get_bone_count() >= reference_skeleton.get_bone_count():
		for index in range(reference_skeleton.get_bone_count()):
			var expected_name := reference_skeleton.get_bone_name(index)
			var actual_name := source_skeleton.get_bone_name(index)
			_check(actual_name == expected_name,
				"%s shared bone %d is %s (expected %s)" % [label, index, actual_name, expected_name])
			if actual_name != expected_name:
				continue
			var expected_parent := reference_skeleton.get_bone_parent(index)
			var actual_parent := source_skeleton.get_bone_parent(index)
			var expected_parent_name := reference_skeleton.get_bone_name(expected_parent) if expected_parent >= 0 else ""
			var actual_parent_name := source_skeleton.get_bone_name(actual_parent) if actual_parent >= 0 else ""
			_check(actual_parent_name == expected_parent_name,
				"%s bone %s parent matches (%s)" % [label, expected_name, expected_parent_name])
			var expected_rest := reference_skeleton.get_bone_rest(index)
			var actual_rest := source_skeleton.get_bone_rest(index)
			var origin_delta := actual_rest.origin.distance_to(expected_rest.origin)
			_check(origin_delta <= MAX_REST_ORIGIN_DELTA_METRES and actual_rest.basis.is_equal_approx(expected_rest.basis),
				"%s bone %s rest transform matches (origin delta %.2f mm)" % [label, expected_name, origin_delta * 1000.0])
	var source_meshes: Array[MeshInstance3D] = []
	_collect_meshes(source_root, source_meshes)
	var skeleton_node_count := _count_skeletons(source_root)
	var skinned_mesh_count := 0
	var bone_attached_unskinned_count := 0
	for mesh in source_meshes:
		if mesh.mesh == null:
			continue
		if mesh.skin != null:
			skinned_mesh_count += 1
			var mesh_skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
			_check(mesh_skeleton == source_skeleton,
				"%s skinned mesh %s is bound to the primary source skeleton (resolved=%s path=%s)" % [
					label, str(source_root.get_path_to(mesh)),
					str(mesh_skeleton.get_path()) if mesh_skeleton != null else "<unresolved>",
					str(mesh.skeleton)
				])
			continue
		var ancestor := mesh.get_parent()
		while ancestor != null and ancestor != source_root:
			if ancestor is BoneAttachment3D or ancestor is Skeleton3D:
				bone_attached_unskinned_count += 1
				_check(false, "%s has unskinned mesh %s attached beneath %s; flattening would lose its bone attachment" % [
					label, str(source_root.get_path_to(mesh)), str(ancestor.get_path())
				])
				break
			ancestor = ancestor.get_parent()
	print("ARA_RIG_DIAGNOSTIC asset=%s source_bones=%d carrier_bones=%d skeleton_nodes=%d skinned_meshes=%d bone_attached_unskinned_meshes=%d" % [
		asset_path, source_skeleton.get_bone_count(), reference_skeleton.get_bone_count(),
		skeleton_node_count, skinned_mesh_count, bone_attached_unskinned_count
	])
	source_root.free()


func _count_skeletons(node: Node) -> int:
	var count := 1 if node is Skeleton3D else 0
	for child in node.get_children():
		count += _count_skeletons(child)
	return count


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
		push_error("%d Ara animation carrier assertion(s) failed." % failures)
		quit(1)
		return
	print("Ara gameplay animation carrier integration tests passed.")
	quit(0)


func _assert_character_asset_animated(asset_path: String, label: String) -> void:
	_check_source_rig_compatible(asset_path, label)
	var actor := ACTOR_SCRIPT.new()
	root.add_child(actor)
	var configured: bool = actor.configure(asset_path)
	_check(configured, label + " configures")
	if configured:
		_check(absf(wrapf(actor.model_root.rotation.y - PI, -PI, PI)) < 0.001,
			label + " model forward axis is aligned with the world actor heading")
	if not configured:
		actor.free()
		return
	await process_frame
	var player := actor.animation_player as AnimationPlayer
	var skeleton := _find_skeleton(actor.model_root)
	_check(player != null, label + " has an animation player")
	_check(skeleton != null, label + " has a skeleton")
	if player != null and skeleton != null:
		var locomotion_selected := actor.set_moving(true)
		_check(locomotion_selected, label + " selects a locomotion clip")
		var bound_mesh_found := false
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(actor.model_root, meshes)
		for mesh in meshes:
			if mesh.visible and mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) == skeleton:
				bound_mesh_found = true
				break
		_check(bound_mesh_found, label + " has a visible skinned mesh bound to its animated skeleton")
		if locomotion_selected:
			var starting_poses: Array[Transform3D] = []
			for bone_index in range(skeleton.get_bone_count()):
				starting_poses.append(skeleton.get_bone_global_pose(bone_index))
			await create_timer(0.18).timeout
			var changed_bones := 0
			for bone_index in range(skeleton.get_bone_count()):
				if not skeleton.get_bone_global_pose(bone_index).is_equal_approx(starting_poses[bone_index]):
					changed_bones += 1
			_check(changed_bones >= 5, label + " walk animation drives its visible skeleton (%d changed bones)" % changed_bones)
	actor.free()
