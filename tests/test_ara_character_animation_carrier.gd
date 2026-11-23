extends SceneTree
## Verifies that a real gameplay Ara body is bound to the shared animated rig.

const ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const BODY_PATH := "res://art/characters/ara_runtime/ara_player_female_body.glb"

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ResourceLoader.exists(BODY_PATH), "Gameplay female Ara body asset is available")
	_check(ResourceLoader.exists("res://art/characters/ara_runtime/ara_person_benchmark.glb"),
		"Animated Ara benchmark carrier is available")
	if failures > 0:
		_finish()
		return

	var actor := ACTOR_SCRIPT.new()
	root.add_child(actor)
	_check(actor.configure(BODY_PATH), "Ara gameplay actor configures from its body asset")
	await process_frame

	var animation_player := actor.animation_player as AnimationPlayer
	_check(animation_player != null, "Gameplay actor receives the benchmark AnimationPlayer")
	var skeleton := _find_skeleton(actor.model_root)
	_check(skeleton != null, "Gameplay actor has the animated carrier Skeleton3D")
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
	for frame in range(20):
		await process_frame
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

	actor.queue_free()
	_finish()


func _find_skeleton(node: Node) -> Skeleton3D:
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
