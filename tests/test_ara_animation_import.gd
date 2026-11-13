extends SceneTree
## Runs only against the versioned runtime package emitted by Build Wren Workshop.
## Ordinary game-code validation deliberately does not require generated GLBs.

const ASSET_ROOT := "res://art/characters/ara_runtime/"
const MANIFEST_PATH := ASSET_ROOT + "manifest.json"
const BENCHMARK_PATH := ASSET_ROOT + "ara_person_benchmark.glb"
const RIGGED_ASSETS := [
	"ara_person_body.glb",
	"ara_person_modular_underwear.glb",
	"ara_person_male_body.glb"
]
const EXPECTED_ASSETS := [
	"ara_person_benchmark.glb",
	"ara_person_body.glb",
	"ara_person_modular.glb",
	"ara_person_modular_underwear.glb",
	"ara_person_male_body.glb"
]
const MAX_REST_ORIGIN_DELTA_METRES := 0.025

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := _validate_manifest()
	if manifest.is_empty():
		_finish()
		return

	# Exercise the same loader used by game presentation code, not just ResourceLoader.
	var actor := AraCharacterActor.new()
	root.add_child(actor)
	_check(actor.configure(BENCHMARK_PATH), "AraCharacterActor loads the packaged animated benchmark")
	if actor.model_root == null or actor.animation_player == null:
		_finish()
		return

	var canonical_skeleton := _find_skeleton(actor.model_root)
	_check(canonical_skeleton != null, "Animated benchmark contains a Skeleton3D")
	_check(actor.animation_player.get_animation_list().size() > 0, "Animated benchmark contains animation clips")
	if canonical_skeleton == null:
		_finish()
		return

	var modular_root := _load_scene(ASSET_ROOT + "ara_person_modular.glb", "modular outfit")
	if modular_root != null:
		var modular_skeleton := _find_skeleton(modular_root)
		_check(modular_skeleton != null, "Modular outfit contains a Skeleton3D")
		var modular_meshes: Array[MeshInstance3D] = []
		_collect_meshes(modular_root, modular_meshes)
		_check(not modular_meshes.is_empty(), "Modular outfit contains renderable mesh components")
		if modular_skeleton != null:
			_check_same_rig(canonical_skeleton, modular_skeleton, "modular outfit")
		root.add_child(modular_root)

	for asset_name in RIGGED_ASSETS:
		var asset_root := _load_scene(ASSET_ROOT + asset_name, asset_name)
		if asset_root == null:
			continue
		var skeleton := _find_skeleton(asset_root)
		_check(skeleton != null, asset_name + " contains a Skeleton3D")
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(asset_root, meshes)
		_check(not meshes.is_empty(), asset_name + " contains renderable mesh components")
		if skeleton != null:
			_check_same_rig(canonical_skeleton, skeleton, asset_name)
		root.add_child(asset_root)

	# Confirm that an actual imported clip drives the rig. Prefer Walk, but use
	# the first available clip if Ara changes its clip naming in a later build.
	var animation_player := actor.animation_player
	var animation_names := animation_player.get_animation_list()
	var selected_animation := ""
	for animation_name in animation_names:
		if str(animation_name).to_lower().contains("walk"):
			selected_animation = str(animation_name)
			break
	if selected_animation.is_empty() and not animation_names.is_empty():
		selected_animation = str(animation_names[0])
	_check(not selected_animation.is_empty(), "At least one animation can be selected for playback")
	if not selected_animation.is_empty():
		var starting_poses: Array[Transform3D] = []
		for bone_index in range(canonical_skeleton.get_bone_count()):
			starting_poses.append(canonical_skeleton.get_bone_global_pose(bone_index))
		animation_player.play(selected_animation)
		for frame in range(30):
			await process_frame
		var changed_bones := 0
		for bone_index in range(canonical_skeleton.get_bone_count()):
			if not canonical_skeleton.get_bone_global_pose(bone_index).is_equal_approx(starting_poses[bone_index]):
				changed_bones += 1
		_check(changed_bones >= 5, "Animation '%s' drives at least five bones (changed %d)" % [selected_animation, changed_bones])

	_finish()

func _validate_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_check(false, "Runtime asset manifest is present")
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(parsed is Dictionary, "Runtime asset manifest is valid JSON")
	if not parsed is Dictionary:
		return {}
	var manifest: Dictionary = parsed
	_check(int(manifest.get("schema_version", 0)) == 1, "Runtime asset manifest schema is supported")
	_check(str(manifest.get("package_version", "")).length() == 40, "Package is pinned to a full source commit SHA")
	var assets: Dictionary = manifest.get("assets", {})
	for asset_name in EXPECTED_ASSETS:
		_check(assets.has(asset_name), "Manifest declares " + asset_name)
		if not assets.has(asset_name):
			continue
		var asset_path: String = ASSET_ROOT + str(asset_name)
		_check(FileAccess.file_exists(asset_path), "Packaged asset exists: " + asset_name)
		if not FileAccess.file_exists(asset_path):
			continue
		var expected: Dictionary = assets[asset_name]
		_check(_file_size(asset_path) == int(expected.get("size_bytes", -1)),
			"Packaged asset size matches manifest: " + asset_name)
		_check(FileAccess.get_sha256(asset_path) == str(expected.get("sha256", "")),
			"Packaged asset SHA-256 matches manifest: " + asset_name)
	return manifest

func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1

func _load_scene(path: String, label: String) -> Node3D:
	var packed := load(path) as PackedScene
	_check(packed != null, label + " imports as a PackedScene")
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	_check(instance != null, label + " has a Node3D root")
	return instance

func _check_same_rig(reference: Skeleton3D, candidate: Skeleton3D, label: String) -> void:
	_check(candidate.get_bone_count() == reference.get_bone_count(), label + " bone count matches the animated rig")
	if candidate.get_bone_count() != reference.get_bone_count():
		return
	var largest_origin_delta := 0.0
	for bone_index in range(reference.get_bone_count()):
		_check(candidate.get_bone_name(bone_index) == reference.get_bone_name(bone_index),
			"%s bone %d name/order matches" % [label, bone_index])
		var reference_rest := reference.get_bone_rest(bone_index)
		var candidate_rest := candidate.get_bone_rest(bone_index)
		var origin_delta := candidate_rest.origin.distance_to(reference_rest.origin)
		largest_origin_delta = maxf(largest_origin_delta, origin_delta)
		_check(origin_delta <= MAX_REST_ORIGIN_DELTA_METRES and candidate_rest.basis.is_equal_approx(reference_rest.basis),
			"%s bone %d rest transform is compatible" % [label, bone_index])
	print("ARA_%s_MAX_REST_ORIGIN_DELTA_MM=" % label.to_upper().replace(" ", "_"),
		snappedf(largest_origin_delta * 1000.0, 0.1))

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
