extends SceneTree
## Renders Wren's independently exported modular components on the Ara benchmark
## skeleton while the imported Ara clips drive that shared skeleton.

const BENCHMARK_PATH := "res://art/characters/ara_validation/ara_wren_benchmark.glb"
const COMPONENT_PATHS := [
	"res://art/characters/ara_validation/modular/body.glb",
	"res://art/characters/ara_validation/modular/hair.glb",
	"res://art/characters/ara_validation/modular/shirt.glb",
	"res://art/characters/ara_validation/modular/trousers.glb",
	"res://art/characters/ara_validation/weapon_sword.glb",
]
const ANIMATIONS := [
	{"clip": "Idle", "file": "ara-wren-idle.png", "time": 0.5},
	{"clip": "Walk", "file": "ara-wren-walk.png", "time": 0.65},
	{"clip": "Run", "file": "ara-wren-run.png", "time": 0.55},
	{"clip": "Strafe left", "file": "ara-wren-strafe-left.png", "time": 0.55},
	{"clip": "Turn left 90°", "file": "ara-wren-turn-left.png", "time": 0.7},
	{"clip": "Jump", "file": "ara-wren-jump.png", "time": 0.55},
	{"clip": "Sword slash", "file": "ara-wren-sword-slash.png", "time": 0.55},
]
const OUTPUT_DIR := "res://artifacts/ara-animation"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_path)

	var benchmark := load(BENCHMARK_PATH) as PackedScene
	_check(benchmark != null, "Benchmark character scene imports")
	if benchmark == null:
		_finish()
		return

	var character := benchmark.instantiate() as Node3D
	_check(character != null, "Benchmark character instantiates")
	if character == null:
		_finish()
		return
	root.add_child(character)
	await process_frame

	var skeleton := _find_skeleton(character)
	var player := _find_animation_player(character)
	_check(skeleton != null, "Character contains the Ara Skeleton3D")
	_check(player != null, "Character contains the Ara AnimationPlayer")
	if skeleton == null or player == null:
		_finish()
		return

	# Hide the benchmark's combined mesh. The visible character is assembled
	# from the separately exported Ara components below.
	var source_meshes: Array[MeshInstance3D] = []
	_collect_meshes(character, source_meshes)
	for mesh in source_meshes:
		mesh.visible = false

	var attached_meshes: Array[MeshInstance3D] = []
	for component_path in COMPONENT_PATHS:
		var packed := load(component_path) as PackedScene
		_check(packed != null, "Component imports: " + component_path.get_file())
		if packed == null:
			continue
		var component_root := packed.instantiate() as Node3D
		if component_root == null:
			_check(false, "Component root is Node3D: " + component_path.get_file())
			continue
		character.add_child(component_root)
		var component_skeleton := _find_skeleton(component_root)
		_check(component_skeleton != null, "Component carries rig: " + component_path.get_file())
		if component_skeleton == null:
			component_root.queue_free()
			continue
		_check_rig_names(skeleton, component_skeleton, component_path.get_file())
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(component_root, meshes)
		_check(not meshes.is_empty(), "Component has a visible mesh: " + component_path.get_file())
		for mesh in meshes:
			mesh.reparent(character, true)
			mesh.skeleton = mesh.get_path_to(skeleton)
			mesh.visible = true
			attached_meshes.append(mesh)
		component_root.queue_free()
		await process_frame

	_check(attached_meshes.size() >= 5, "Five modular parts are attached to the shared rig")
	for mesh in attached_meshes:
		_check(mesh.get_node_or_null(mesh.skeleton) == skeleton,
			"Mesh binds to shared skeleton: " + mesh.name)

	_setup_stage()
	await process_frame
	var active_camera := root.get_viewport().get_camera_3d()
	_check(active_camera != null, "Review viewport has an active camera")
	if active_camera == null:
		_finish()
		return

	for animation_data in ANIMATIONS:
		var clip: String = animation_data["clip"]
		_check(player.has_animation(clip), "Animation clip exists: " + clip)
		if not player.has_animation(clip):
			continue
		player.stop()
		player.play(clip)
		var animation := player.get_animation(clip)
		var sample_time := minf(float(animation_data["time"]), animation.length * 0.8)
		player.seek(sample_time, true)
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var screenshot := root.get_texture().get_image()
		if screenshot.is_empty():
			_check(false, "Viewport screenshot captured for " + clip)
			continue
		var destination := output_path.path_join(String(animation_data["file"]))
		var error := screenshot.save_png(destination)
		_check(error == OK, "Screenshot saved: " + destination)
		print("ARA_VISUAL_CAPTURE=", destination, " size=", screenshot.get_width(), "x", screenshot.get_height())

	_finish()

func _setup_stage() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12.0, 12.0)
	var floor := MeshInstance3D.new()
	floor.name = "StudioFloor"
	floor.mesh = floor_mesh
	floor.position.y = -0.025
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.12, 0.15, 0.19)
	floor_material.roughness = 0.92
	floor.material_override = floor_material
	root.add_child(floor)

	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color(0.055, 0.07, 0.09)
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.68, 0.72, 0.82)
	world.ambient_light_energy = 0.75
	world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = world
	root.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	key_light.light_energy = 1.6
	key_light.shadow_enabled = true
	root.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-3.0, 3.5, 4.0)
	fill_light.light_energy = 2.0
	fill_light.omni_range = 9.0
	root.add_child(fill_light)

	var camera := Camera3D.new()
	camera.name = "AraAnimationReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	camera.position = Vector3(2.8, 2.1, 5.2)
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.make_current()
	print("ARA_REVIEW_CAMERA=", camera.get_path(), " active=", root.get_viewport().get_camera_3d() == camera)

	var label := Label3D.new()
	label.text = "WREN TALBOT  •  ARA MODULAR RIG"
	label.position = Vector3(0.0, 2.05, 0.0)
	label.font_size = 48
	label.pixel_size = 0.0018
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.9, 0.92, 0.96)
	root.add_child(label)

func _check_rig_names(reference: Skeleton3D, candidate: Skeleton3D, label: String) -> void:
	_check(candidate.get_bone_count() == reference.get_bone_count(),
		"Rig bone count matches: " + label)
	if candidate.get_bone_count() != reference.get_bone_count():
		return
	for bone_index in range(reference.get_bone_count()):
		_check(candidate.get_bone_name(bone_index) == reference.get_bone_name(bone_index),
			"Rig bone order matches: %s / %d" % [label, bone_index])

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
		print("ARA_VISUAL_ANIMATION_CAPTURE: PASS")
		quit(0)
	else:
		push_error("ARA_VISUAL_ANIMATION_CAPTURE: %d failure(s)" % failures.size())
		for failure in failures:
			push_error(failure)
		quit(1)
