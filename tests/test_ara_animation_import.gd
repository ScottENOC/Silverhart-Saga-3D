extends SceneTree

const BENCHMARK_PATH := "res://art/characters/ara_validation/ara_wren_benchmark.glb"
const COMPONENT_PATHS := {
	"body": "res://art/characters/ara_validation/modular/body.glb",
	"hair": "res://art/characters/ara_validation/modular/hair.glb",
	"shirt": "res://art/characters/ara_validation/modular/shirt.glb",
	"trousers": "res://art/characters/ara_validation/modular/trousers.glb",
}
const REQUIRED_ANIMATIONS := ["Idle", "Walk", "Run", "Strafe left", "Jump"]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var benchmark_resource := load(BENCHMARK_PATH) as PackedScene
	_check(benchmark_resource != null, "Ara benchmark GLB imports as a PackedScene")
	if benchmark_resource == null:
		_finish()
		return

	var benchmark_root := benchmark_resource.instantiate() as Node3D
	_check(benchmark_root != null, "Ara benchmark scene has a Node3D root")
	if benchmark_root == null:
		_finish()
		return
	root.add_child(benchmark_root)
	await process_frame

	var canonical_skeleton := _find_skeleton(benchmark_root)
	var animation_player := _find_animation_player(benchmark_root)
	_check(canonical_skeleton != null, "Benchmark scene contains a Skeleton3D")
	_check(animation_player != null, "Benchmark scene contains an AnimationPlayer")
	if canonical_skeleton == null or animation_player == null:
		_finish()
		return

	print("ARA_BENCHMARK_BONES=", canonical_skeleton.get_bone_count())
	_check(canonical_skeleton.get_bone_count() == 69, "Benchmark rig has the expected 69 bones")

	var animation_names := animation_player.get_animation_list()
	print("ARA_ANIMATIONS=", animation_names.size())
	for animation_name in REQUIRED_ANIMATIONS:
		_check(animation_player.has_animation(animation_name), "Animation clip exists: " + animation_name)

	# The benchmark mesh is only a rig/animation carrier in this test. Replace
	# its visible mesh with the independently exported modular components.
	var benchmark_meshes: Array[MeshInstance3D] = []
	_collect_meshes(benchmark_root, benchmark_meshes)
	for mesh_instance in benchmark_meshes:
		mesh_instance.visible = false

	var attached_meshes: Array[MeshInstance3D] = []
	for component_name in COMPONENT_PATHS:
		var component_path: String = COMPONENT_PATHS[component_name]
		var component_resource := load(component_path) as PackedScene
		_check(component_resource != null, "Component imports: " + component_name)
		if component_resource == null:
			continue
		var component_root := component_resource.instantiate() as Node3D
		_check(component_root != null, "Component has a Node3D root: " + component_name)
		if component_root == null:
			continue
		benchmark_root.add_child(component_root)
		var component_skeleton := _find_skeleton(component_root)
		_check(component_skeleton != null, "Component has a Skeleton3D: " + component_name)
		if component_skeleton == null:
			component_root.queue_free()
			continue
		_check_same_rig(canonical_skeleton, component_skeleton, component_name)

		var component_meshes: Array[MeshInstance3D] = []
		_collect_meshes(component_root, component_meshes)
		_check(not component_meshes.is_empty(), "Component contains skinned mesh data: " + component_name)
		for mesh_instance in component_meshes:
			mesh_instance.reparent(benchmark_root, true)
			mesh_instance.skeleton = mesh_instance.get_path_to(canonical_skeleton)
			attached_meshes.append(mesh_instance)
		component_root.queue_free()
		await process_frame

	_check(attached_meshes.size() >= 4, "Body, hair, shirt and trousers are attached")
	for mesh_instance in attached_meshes:
		_check(mesh_instance.get_node_or_null(mesh_instance.skeleton) == canonical_skeleton,
			"Mesh uses the shared animated skeleton: " + mesh_instance.name)

	# Confirm that the imported Walk clip actually changes the canonical rig.
	if animation_player.has_animation("Walk"):
		var starting_poses: Array[Transform3D] = []
		for bone_index in range(canonical_skeleton.get_bone_count()):
			starting_poses.append(canonical_skeleton.get_bone_global_pose(bone_index))
		animation_player.play("Walk")
		for frame in range(30):
			await process_frame
		var changed_bones := 0
		for bone_index in range(canonical_skeleton.get_bone_count()):
			if not canonical_skeleton.get_bone_global_pose(bone_index).is_equal_approx(starting_poses[bone_index]):
				changed_bones += 1
		print("ARA_WALK_CHANGED_BONES=", changed_bones)
		_check(changed_bones >= 5, "Walk clip drives the shared skeleton (at least five bones change)")
		_check(animation_player.is_playing(), "Walk clip remains active after playback")

	_finish()

func _check_same_rig(reference: Skeleton3D, candidate: Skeleton3D, label: String) -> void:
	_check(candidate.get_bone_count() == reference.get_bone_count(),
		label + " bone count matches the benchmark rig")
	if candidate.get_bone_count() != reference.get_bone_count():
		return
	for bone_index in range(reference.get_bone_count()):
		_check(candidate.get_bone_name(bone_index) == reference.get_bone_name(bone_index),
			"%s bone %d name matches" % [label, bone_index])
		_check(candidate.get_bone_rest(bone_index).is_equal_approx(reference.get_bone_rest(bone_index)),
			"%s bone %d bind/rest transform matches" % [label, bone_index])

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
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
		failures.append(message)
		push_error("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("ARA_ANIMATION_INTEGRATION_TEST: PASS")
		quit(0)
	else:
		push_error("ARA_ANIMATION_INTEGRATION_TEST: %d failure(s)" % failures.size())
		for failure in failures:
			push_error(failure)
		quit(1)
