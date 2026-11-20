class_name HollowmereVillage
extends Node3D
## Exterior presentation for the first playable location. Buildings and paths are
## intentionally blockout-quality; the underlying layout is the authored map.

const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M
const GROUND_SIZE: float = 420.0
const ORGANIC_FEATURES = preload("res://scripts/world/organic_world_features.gd")
const WORLD_VEGETATION_SCRIPT = preload("res://scripts/world/world_vegetation_generator.gd")
const HEARTLAND_BIOMES = preload("res://data/world/regions/silverhart_heartland/biomes.gd")
const CREATURE_ACTOR_SCRIPT = preload("res://scripts/presentation/creature_actor.gd")
const WORLD_BUILDING_FACTORY = preload("res://scripts/world/world_building_factory.gd")
const POLYLINE_FEATURE_FACTORY = preload("res://scripts/world/world_polyline_feature_factory.gd")
const BRIDGE_FEATURE_FACTORY = preload("res://scripts/world/world_bridge_feature_factory.gd")
const AGRICULTURAL_FEATURE_FACTORY = preload("res://scripts/world/world_agricultural_feature_factory.gd")
const PROP_FEATURE_FACTORY = preload("res://scripts/world/world_prop_feature_factory.gd")
const AUTHORED_SETTLEMENT_PRESENTER = preload("res://scripts/world/authored_settlement_presenter.gd")
const HOLLOWMERE_SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const HOLLOWMERE_BUILDINGS = preload("res://data/settlements/hollowmere/buildings.gd")
const HOLLOWMERE_ROUTES = preload("res://data/settlements/hollowmere/routes.gd")
const HOLLOWMERE_BRIDGES = preload("res://data/settlements/hollowmere/bridges.gd")
const HOLLOWMERE_AGRICULTURE = preload("res://data/settlements/hollowmere/agriculture.gd")
const HOLLOWMERE_PROPS = preload("res://data/settlements/hollowmere/props.gd")
var grass_material: StandardMaterial3D
var path_material: StandardMaterial3D
var water_material: StandardMaterial3D
var riverbank_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var plaster_material: StandardMaterial3D
var timber_material: StandardMaterial3D
var dark_wood_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var glass_material: StandardMaterial3D
var foliage_materials: Array[StandardMaterial3D] = []
var field_material: StandardMaterial3D
var crop_material: StandardMaterial3D
var pasture_material: StandardMaterial3D
var fence_material: StandardMaterial3D

func _ready() -> void:
	_create_materials()
	_create_ground()
	_present_authored_settlement()
	_create_farm_animals()
	_create_wilderness_animals()
	_create_forest()

func _material(colour: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = roughness
	result.metallic = metallic
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _create_materials() -> void:
	grass_material = _material(Color(0.27, 0.36, 0.23))
	path_material = _material(Color(0.43, 0.34, 0.23))
	water_material = _material(Color(0.16, 0.31, 0.36), 0.22)
	riverbank_material = _material(Color(0.22, 0.25, 0.17))
	stone_material = _material(Color(0.38, 0.37, 0.33))
	plaster_material = _material(Color(0.61, 0.53, 0.40))
	timber_material = _material(Color(0.31, 0.18, 0.10))
	dark_wood_material = _material(Color(0.16, 0.09, 0.05))
	roof_material = _material(Color(0.24, 0.25, 0.22))
	glass_material = _material(Color(0.29, 0.45, 0.49, 0.72), 0.18)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	field_material = _material(Color(0.30, 0.32, 0.17))
	crop_material = _material(Color(0.48, 0.43, 0.22))
	pasture_material = _material(Color(0.24, 0.34, 0.19))
	fence_material = _material(Color(0.28, 0.17, 0.09))
	foliage_materials = [
		_material(Color(0.19, 0.30, 0.17)),
		_material(Color(0.24, 0.35, 0.19)),
		_material(Color(0.29, 0.38, 0.22))
	]

func _create_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "HollowmereGrassland"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground.mesh = mesh
	ground.position.y = -0.22
	ground.material_override = grass_material
	add_child(ground)

