extends Node3D

## Temporary visual gallery for the Cosmo Tree Gen evaluation collection.
## Open scenes/prototypes/cosmo_tree_gallery.tscn and run it with F6.

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

const COLUMNS := 4
const SPACING := 18.0
const GROUND_SIZE := 82.0
const GALLERY_CENTER := Vector3.ZERO


func _ready() -> void:
	_build_environment()
	_build_trees()


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
	environment.ambient_light_sky_contribution = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.name = "Gallery Sun"
	sunlight.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sunlight.light_energy = 1.25
	sunlight.shadow_enabled = true
	add_child(sunlight)

	var ground := MeshInstance3D.new()
	ground.name = "Neutral Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.28, 0.34, 0.25)
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	ground.position.y = -0.08
	add_child(ground)

	var camera := Camera3D.new()
	camera.name = "Gallery Camera"
	camera.position = Vector3(37.0, 39.0, 49.0)
	camera.fov = 58.0
	camera.look_at(Vector3(0.0, 4.0, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)


func _build_trees() -> void:
	for index in range(TREE_PATHS.size()):
		var path := TREE_PATHS[index]
		var packed_scene := load(path) as PackedScene
		if packed_scene == null:
			push_error("Could not load tree scene: " + path)
			continue

		var column := index % COLUMNS
		var row := index / COLUMNS
		var x := (float(column) - 1.5) * SPACING
		var z := (float(row) - 1.5) * SPACING

		var tree_instance := packed_scene.instantiate()
		tree_instance.name = path.get_file().get_basename()
		add_child(tree_instance)
		tree_instance.position = Vector3(x, 0.0, z)

		var label := Label3D.new()
		label.name = "Tree Label"
		label.text = path.get_file().get_basename().replace("_", " ").capitalize()
		label.position = Vector3(x, 0.25, z + 4.5)
		label.font_size = 42
		label.outline_size = 8
		label.modulate = Color(0.96, 0.96, 0.88)
		label.outline_modulate = Color(0.08, 0.10, 0.08, 1.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

		print("COSMO_GALLERY_TREE: ", path)
