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

var failures: int = 0


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

	var actor := ACTOR_SCRIPT.new()
	root.add_child(actor)
	var female_configured: bool = actor.configure(BODY_PATHS[0])
	_check(female_configured, "Ara female gameplay actor configures from its body asset")
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
		_check(male_actor.set_moving(true), "Male gameplay actor selects a real locomotion clip")
	male_actor.free()

	for asset_path in CHARACTER_ASSET_PATHS:
		await _assert_character_asset_animated(asset_path, asset_path.get_file().get_basename())
	_finish()


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
	var actor := ACTOR_SCRIPT.new()
	root.add_child(actor)
	var configured: bool = actor.configure(asset_path)
	_check(configured, label + " configures")
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
