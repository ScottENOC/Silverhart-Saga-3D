extends Node3D
## Visual smoke-test scene for creature asset variants. Run with F6.

const CREATURE_FACTORY = preload("res://scripts/creatures/creature_visual_factory.gd")

const SHOWCASE_VARIANTS: Array[Dictionary] = [
	{"name": "Small Red", "size": "small", "colour": "red", "x": -3.2},
	{"name": "Medium Natural", "size": "medium", "colour": "natural", "x": 0.0},
	{"name": "Large Gold", "size": "large", "colour": "gold", "x": 3.2}
]

func _ready() -> void:
	_create_lighting()
	_create_ground()
	for variant in SHOWCASE_VARIANTS:
		_spawn_variant(variant)

func _spawn_variant(variant: Dictionary) -> void:
	var creature := CREATURE_FACTORY.create_species(
		"dragon",
		{
			"instance_name": String(variant["name"]).replace(" ", ""),
			"size": variant["size"],
			"colour": variant["colour"],
			"animation": "idle"
		}
	)
	if creature == null:
		return
	creature.position = Vector3(float(variant["x"]), 0.0, 0.0)
	add_child(creature)

	var label := Label3D.new()
	label.text = "%s\n%s %s" % [variant["name"], variant["size"], variant["colour"]]
	label.position = Vector3(float(variant["x"]), 0.05, 2.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.006
	add_child(label)

func _create_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "ShowcaseGround"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(14.0, 10.0)
	ground.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.23, 0.20)
	ground.material_override = material
	ground.position = Vector3(0.0, -0.04, 0.0)
	add_child(ground)

func _create_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	light.light_energy = 1.35
	add_child(light)

	var environment := WorldEnvironment.new()
	var environment_data := Environment.new()
	environment_data.background_mode = Environment.BG_SKY
	environment_data.sky = Sky.new()
	environment_data.sky.sky_material = ProceduralSkyMaterial.new()
	environment_data.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment_data.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = environment_data
	add_child(environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.0, 10.5)
	camera.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	camera.current = true
	camera.fov = 48.0
	add_child(camera)
