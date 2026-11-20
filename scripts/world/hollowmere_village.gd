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

func _add_hex_surface(node_name: String, cells: Array[Vector2i], material: Material, elevation: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := HexGrid.corner_offsets(HEX_RADIUS * 1.005)
	for hex in cells:
		var centre := HexGrid.axial_to_world(hex, HEX_RADIUS, elevation)
		for i in range(HexGrid.SIDE_COUNT):
			var next_i := (i + 1) % HexGrid.SIDE_COUNT
			surface.set_normal(Vector3.UP)
			surface.add_vertex(centre)
			surface.add_vertex(centre + Vector3(corners[next_i].x, 0.0, corners[next_i].y))
			surface.add_vertex(centre + Vector3(corners[i].x, 0.0, corners[i].y))
	var mesh := surface.commit()
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)

func _present_authored_settlement() -> void:
	var result: Dictionary = AUTHORED_SETTLEMENT_PRESENTER.present(
		self,
		{"id": HOLLOWMERE_SETTLEMENT.SETTLEMENT_ID, "name": HOLLOWMERE_SETTLEMENT.DISPLAY_NAME},
		{
			"buildings": HOLLOWMERE_BUILDINGS.BUILDINGS,
			"routes": HOLLOWMERE_ROUTES.PRESENTATION_ROUTES,
			"bridge": HOLLOWMERE_BRIDGES.BRIDGE_PRESENTATION,
			"fields": HOLLOWMERE_AGRICULTURE.FARM_FIELDS,
			"crop_rows": HOLLOWMERE_AGRICULTURE.FARM_CROP_ROWS,
			"fences": HOLLOWMERE_AGRICULTURE.FARM_FENCES,
			"landmark_props": HOLLOWMERE_PROPS.LANDMARK_PROPS,
			"quest_props": HOLLOWMERE_PROPS.QUEST_PROPS,
			"wayfinding_props": HOLLOWMERE_PROPS.WAYFINDING_PROPS
		},
		{
			"routes": {"path": path_material, "water": water_material, "bank": riverbank_material},
			"bridge": {"timber": timber_material, "dark_wood": dark_wood_material},
			"agriculture": {"field": field_material, "pasture": pasture_material, "crop": crop_material, "fence": fence_material},
			"props": {"dark_wood": dark_wood_material, "stone": stone_material, "timber": timber_material},
			"quest_props": {"fence": fence_material, "dark_wood": dark_wood_material, "blood": _material(Color(0.22, 0.045, 0.025))},
			"wayfinding_props": {"dark_wood": dark_wood_material, "timber": timber_material}
		},
		HEX_RADIUS
	)
	if not bool(result.get("ok", false)):
		push_error("Hollowmere authored settlement presentation failed: %s" % result)

func _create_farm_animals() -> void:
	# Old Mac's surviving herd occupies the fenced southern pasture.
	_spawn_creature("FarmCowA", "cow", "farm", Vector2i(5, 66), 0.82)
	_spawn_creature("FarmCowB", "cow", "farm", Vector2i(10, 69), 0.82)
	_spawn_creature("FarmCowC", "cow", "farm", Vector2i(13, 64), 0.82)
	# A farm horse is present as a visible future mount candidate.
	_spawn_creature("FarmHorse", "horse", "mount", Vector2i(24, 57), 0.82)
	# A second coat variant and a small farm dog use their own original glTF scenes.
	_spawn_creature("FarmWhiteHorse", "horse", "mount", Vector2i(27, 61), 0.82, "Horse_White.gltf")
	_spawn_creature("FarmShiba", "shiba_inu", "farm", Vector2i(19, 60), 0.48, "ShibaInu.gltf")

func _create_wilderness_animals() -> void:
	# Ambient wildlife is placed in the outer forest belt, away from the
	# settlement, farm and roads. These are presentation actors; encounter
	# spawning and combat ownership remain with the world simulation.
	_spawn_creature("WildernessDeer", "deer", "passive_wildlife", Vector2i(-34, 18), 0.78)
	_spawn_creature("WildernessStag", "stag", "passive_wildlife", Vector2i(37, -12), 0.82)
	_spawn_creature("WildernessFox", "fox", "passive_wildlife", Vector2i(-29, -30), 0.72)
	_spawn_creature("WildernessWolf", "wolf", "predator", Vector2i(39, 39), 0.76)

## Registers the existing exterior animal actors in the campaign simulation.
## They remain neutral and dormant until an encounter explicitly activates them.
func register_animals_with_simulation(simulation: WorldSimulation) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation", "registered_ids": []}
	var registered_ids: Array[String] = []
	var skipped: Array[Dictionary] = []
	for child in get_children():
		var actor := child as CreatureActor
		if actor == null:
			continue
		var animal_id := "animal_" + actor.name.to_lower()
		var existing_state := simulation.get_character(animal_id)
		if existing_state != null:
			if existing_state.race != "animal" or existing_state.creature_kind != actor.creature_kind:
				skipped.append({"actor": actor.name, "reason": "existing_state_profile_mismatch"})
				continue
			# Save restoration may have registered this animal before WorldRoot
			# reconnects the exterior presentation actor. Bind to the restored
			# state and restore its saved position/facing without resetting status.
			actor.simulation_state = existing_state
			actor.axial_hex = existing_state.axial
			actor.position = HexGrid.axial_to_world(existing_state.axial, HEX_RADIUS, 0.0)
			actor.rotation.y = deg_to_rad(float(2 - existing_state.facing_direction) * 60.0)
			registered_ids.append(existing_state.id)
			continue
		var state := actor.create_simulation_state(animal_id, actor.name, actor.axial_hex)
		if state == null:
			skipped.append({"actor": actor.name, "reason": "missing_animal_profile"})
			continue
		state.side = "neutral"
		state.combat_dormant = true
		if not state.tags.has("ambient_animal"):
			state.tags.append("ambient_animal")
		var result := simulation.register_animal(state)
		if not bool(result.get("ok", false)):
			skipped.append({"actor": actor.name, "reason": String(result.get("reason", "registration_failed"))})
			continue
		actor.simulation_state = state
		registered_ids.append(state.id)
	return {"ok": skipped.is_empty(), "registered_ids": registered_ids, "skipped": skipped}

func _spawn_creature(actor_name: String, kind: String, behaviour_name: String, hex: Vector2i, scale_factor: float, asset_filename: String = "") -> void:
	var actor := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
	actor.name = actor_name
	actor.creature_kind = kind
	actor.behaviour = behaviour_name
	actor.axial_hex = hex
	actor.add_to_group("creature_actors")
	actor.model_scale = scale_factor
	var filename := asset_filename if not asset_filename.is_empty() else "%s.gltf" % kind.capitalize()
	actor.model_path = "res://art/creatures/quaternius/%s" % filename
	actor.position = HexGrid.axial_to_world(hex, HEX_RADIUS, 0.0)
	actor.rotation.y = deg_to_rad(float(posmod(hex.x * 37 + hex.y * 19, 360)))
	add_child(actor)

func _create_forest() -> void:
	# Hollowmere supplies local terrain/biome rules; the shared world generator
	# owns candidate placement, deterministic variation and model instancing.
	WORLD_VEGETATION_SCRIPT.generate_hex_grid(
		self, -96, 96, -96, 96, 4, HEX_RADIUS,
		Callable(self, "_is_forest_candidate"),
		HEARTLAND_BIOMES.FOREST_DENSITY_OFFSET, HEARTLAND_BIOMES.FOREST_DENSITY_THRESHOLD,
		Callable(self, "_select_cosmo_tree_family"),
		0.78, 0.46, "HollowmereTree"
	)

	# Understorey uses the same generator and catalogue, with a sparser pass.
	WORLD_VEGETATION_SCRIPT.generate_hex_grid(
		self, -96, 96, -96, 96, 8, HEX_RADIUS,
		Callable(self, "_is_understorey_candidate"),
		HEARTLAND_BIOMES.UNDERSTOREY_DENSITY_OFFSET, HEARTLAND_BIOMES.UNDERSTOREY_DENSITY_THRESHOLD,
		Callable(self, "_select_understorey_family"),
		0.68, 0.48, "HollowmereUnderstorey", true
	)

func _is_forest_candidate(hex: Vector2i) -> bool:
	return HollowmereVillageData.is_forest_candidate(hex)

func _is_understorey_candidate(hex: Vector2i) -> bool:
	return HollowmereVillageData.is_forest_candidate(hex) and not HollowmereVillageData.has_tree(hex)

func _select_understorey_family(hex: Vector2i, density_roll: float) -> String:
	return HEARTLAND_BIOMES.select_understorey_family(_is_near_village_stream(hex, 7.0), density_roll)

func _select_cosmo_tree_family(hex: Vector2i, _density_roll: float = 0.0) -> String:
	return HEARTLAND_BIOMES.select_tree_family(hex, _is_near_village_stream(hex, 7.0))

func _is_near_village_stream(hex: Vector2i, distance: float) -> bool:
	return HEARTLAND_BIOMES.is_near_stream(
		hex, distance, HollowmereVillageData._river_centre_r(hex.x)
	)

func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func add_child_to(parent: Node3D, child: Node) -> void:
	parent.add_child(child)

