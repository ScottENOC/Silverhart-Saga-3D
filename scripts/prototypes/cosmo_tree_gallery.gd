extends Node3D

## 64-tree seasonal comparison gallery: 16 generated models shown in all four seasons.
## Run scenes/prototypes/cosmo_tree_gallery.tscn with F6.
##
## Controls:
##   Left mouse drag: orbit
##   Mouse wheel: zoom
##   WASD / arrow keys: pan
##   F: reset camera

const TREE_PATHS: Array[String] = [
	"res://art/environment/trees/cosmo_generated/ash_01.glb",
	"res://art/environment/trees/cosmo_generated/ash_02.glb",
	"res://art/environment/trees/cosmo_generated/cherry_01.glb",
	"res://art/environment/trees/cosmo_generated/cherry_02.glb",
	"res://art/environment/trees/cosmo_generated/laurel_01.glb",
	"res://art/environment/trees/cosmo_generated/laurel_02.glb",
	"res://art/environment/trees/cosmo_generated/low_poly_tree_01.glb",
	"res://art/environment/trees/cosmo_generated/low_poly_tree_02.glb",
	"res://art/environment/trees/cosmo_generated/pine_01.glb",
	"res://art/environment/trees/cosmo_generated/pine_02.glb",
	"res://art/environment/trees/cosmo_generated/spruce_01.glb",
	"res://art/environment/trees/cosmo_generated/spruce_02.glb",
	"res://art/environment/trees/cosmo_generated/willow_01.glb",
	"res://art/environment/trees/cosmo_generated/willow_02.glb",
	"res://art/environment/trees/cosmo_generated/winter_oak_01.glb",
	"res://art/environment/trees/cosmo_generated/winter_oak_02.glb",
]

const SEASONS := ["SPRING", "SUMMER", "AUTUMN", "WINTER"]
const EVERGREEN_MODELS := ["laurel", "pine", "spruce"]
const COLUMN_SPACING := 12.0
const ROW_SPACING := 22.0
const GROUND_WIDTH := 194.0
const GROUND_DEPTH := 104.0
const CAMERA_START_DISTANCE := 154.0
const CAMERA_MIN_DISTANCE := 24.0
const CAMERA_MAX_DISTANCE := 260.0
const CAMERA_PAN_SPEED := 38.0
const MOUSE_SENSITIVITY := 0.006

const SEASON_LEAF_TINTS := [
	Color(0.78, 1.0, 0.66), # Spring: fresh light green
	Color(0.70, 0.91, 0.55), # Summer: full green
	Color(1.0, 0.57, 0.20), # Autumn: amber/orange
	Color(0.64, 0.76, 0.82), # Winter evergreen: cool green-blue
]
const SEASON_GROUND_TINTS := [
	Color(0.38, 0.48, 0.31),
	Color(0.30, 0.40, 0.27),
	Color(0.48, 0.36, 0.23),
	Color(0.72, 0.79, 0.83),
]

var _camera: Camera3D
var _camera_target := Vector3(0.0, 3.0, 0.0)
var _camera_yaw := 0.0
var _camera_pitch := 0.48
var _camera_distance := CAMERA_START_DISTANCE
var _dragging := false


func _ready() -> void:
	_build_environment()
	_build_season_bands()
	_build_trees()
	_create_camera()
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(CAMERA_MIN_DISTANCE, _camera_distance * 0.88)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(CAMERA_MAX_DISTANCE, _camera_distance / 0.88)
			_update_camera()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_camera_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_camera_pitch = clampf(_camera_pitch + event.relative.y * MOUSE_SENSITIVITY, 0.12, 1.25)
		_update_camera()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			_camera_target = Vector3(0.0, 3.0, 0.0)
			_camera_yaw = 0.0
			_camera_pitch = 0.48
			_camera_distance = CAMERA_START_DISTANCE
			_update_camera()


func _process(delta: float) -> void:
	var forward := Vector3(sin(_camera_yaw), 0.0, cos(_camera_yaw))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var movement := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		movement -= forward
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		movement += forward
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement -= right
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement += right
	if movement.length_squared() > 0.0:
		_camera_target += movement.normalized() * CAMERA_PAN_SPEED * delta * maxf(1.0, _camera_distance / 70.0)
		_update_camera()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.20, 0.34, 0.48)
	sky_material.sky_horizon_color = Color(0.72, 0.79, 0.82)
	sky_material.ground_bottom_color = Color(0.16, 0.19, 0.16)
	sky_material.ground_horizon_color = Color(0.48, 0.52, 0.45)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.name = "Gallery Sun"
	sunlight.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sunlight.light_energy = 1.25
	sunlight.shadow_enabled = true
	add_child(sunlight)


func _build_season_bands() -> void:
	for season_index in range(SEASONS.size()):
		var center_z := (float(season_index) - 1.5) * ROW_SPACING
		var band := MeshInstance3D.new()
		band.name = SEASONS[season_index] + " Ground"
		var plane := PlaneMesh.new()
		plane.size = Vector2(GROUND_WIDTH, ROW_SPACING - 1.0)
		band.mesh = plane
		var material := StandardMaterial3D.new()
		material.albedo_color = SEASON_GROUND_TINTS[season_index]
		material.roughness = 1.0
		band.material_override = material
		band.position = Vector3(0.0, -0.10, center_z)
		add_child(band)

		var season_label := Label3D.new()
		season_label.name = SEASONS[season_index] + " Heading"
		season_label.text = SEASONS[season_index]
		season_label.font_size = 112
		season_label.outline_size = 16
		season_label.modulate = Color(1.0, 1.0, 1.0)
		season_label.outline_modulate = Color(0.08, 0.10, 0.08, 1.0)
		season_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		season_label.position = Vector3(-GROUND_WIDTH * 0.5 + 2.0, 0.2, center_z - 7.0)
		add_child(season_label)


func _build_trees() -> void:
	for model_index in range(TREE_PATHS.size()):
		var path := TREE_PATHS[model_index]
		var packed_scene := load(path) as PackedScene
		if packed_scene == null:
			push_error("Could not load tree scene: " + path)
			continue

		var model_name := path.get_file().get_basename()
		var column := model_index
		var x := (float(column) - 7.5) * COLUMN_SPACING

		for season_index in range(SEASONS.size()):
			var center_z := (float(season_index) - 1.5) * ROW_SPACING
			var tree_instance := packed_scene.instantiate()
			tree_instance.name = model_name + "_" + SEASONS[season_index].to_lower()
			add_child(tree_instance)
			tree_instance.position = Vector3(x, 0.0, center_z + 1.0)
			_apply_season(tree_instance, model_name, season_index)

			var label := Label3D.new()
			label.name = "Tree Label"
			label.text = model_name.replace("_", " ").capitalize()
			label.font_size = 34
			label.outline_size = 7
			label.modulate = Color(0.98, 0.98, 0.92)
			label.outline_modulate = Color(0.08, 0.10, 0.08, 1.0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = Vector3(x, 0.25, center_z + 7.0)
			add_child(label)

		print("COSMO_SEASONAL_MODEL: ", model_name, " across four seasons")


func _apply_season(tree_root: Node, model_name: String, season_index: int) -> void:
	var evergreen := false
	for evergreen_name in EVERGREEN_MODELS:
		if model_name.begins_with(evergreen_name):
			evergreen = true
			break

	var leaf_tint: Color = SEASON_LEAF_TINTS[season_index]
	if season_index == 3 and not evergreen:
		# The generator has no separate leafless winter mesh. Hide the leaf cards
		# so the underlying fine branches remain visible, rather than pretending
		# a full canopy is a convincing winter deciduous tree.
		leaf_tint.a = 0.0

	_apply_leaf_materials_recursive(tree_root, leaf_tint)


func _apply_leaf_materials_recursive(node: Node, tint: Color) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh_instance := node as MeshInstance3D
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material is ShaderMaterial:
				var source_shader_material := source_material as ShaderMaterial
				var shader := source_shader_material.shader
				if shader != null and shader.resource_path.ends_with("leaves.gdshader"):
					var seasonal_material := source_shader_material.duplicate(true) as ShaderMaterial
					seasonal_material.set_shader_parameter("albedo", tint)
					mesh_instance.set_surface_override_material(surface_index, seasonal_material)
	for child in node.get_children():
		_apply_leaf_materials_recursive(child, tint)


func _create_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Orbit Camera"
	_camera.fov = 58.0
	_camera.current = true
	add_child(_camera)


func _update_camera() -> void:
	if _camera == null:
		return
	var horizontal_distance := _camera_distance * cos(_camera_pitch)
	var vertical_distance := _camera_distance * sin(_camera_pitch)
	var offset := Vector3(
		sin(_camera_yaw) * horizontal_distance,
		vertical_distance,
		cos(_camera_yaw) * horizontal_distance
	)
	_camera.position = _camera_target + offset
	_camera.look_at(_camera_target, Vector3.UP)
