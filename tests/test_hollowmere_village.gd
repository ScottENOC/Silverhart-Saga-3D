extends SceneTree

const MAIN_CAMPAIGN_MAP = preload("res://scripts/world/main_campaign_world_map_data.gd")
const WORLD_SETTLEMENT_PRESENTER = preload("res://scripts/world/world_settlement_presenter.gd")
const HOLLOWMERE_PRESENTATION = preload("res://data/settlements/hollowmere/presentation.gd")
const WORLD_BUILDING_FACTORY = preload("res://scripts/world/world_building_factory.gd")
const HOLLOWMERE_PLACEMENTS = preload("res://data/settlements/hollowmere/placements.gd")
const HOLLOW_TANKARD_LAYOUT = preload("res://data/settlements/hollowmere/interiors/hollow_tankard_layout.gd")
const HOLLOWMERE_TERRAIN = preload("res://data/settlements/hollowmere/terrain.gd")
const HOLLOWMERE_SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const HOLLOWMERE_BUILDINGS = preload("res://data/settlements/hollowmere/buildings.gd")
const TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")

# These test helpers deliberately exercise the generic provider directly. They
# are local test conveniences, not a production compatibility API.
static func _is_in_bounds(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_in_bounds(hex, HOLLOWMERE_TERRAIN.DEFINITION)
static func _is_water(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_water(hex, HOLLOWMERE_TERRAIN.DEFINITION)
static func _is_building(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_building(hex, HOLLOWMERE_TERRAIN.DEFINITION)
static func _is_door(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_door(hex, HOLLOWMERE_TERRAIN.DEFINITION)
static func _is_path(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_path(hex, HOLLOWMERE_TERRAIN.DEFINITION)
static func _is_blocked(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_blocked(hex, HOLLOWMERE_TERRAIN.DEFINITION)
static func _terrain_id_at(hex: Vector2i) -> String:
	return TERRAIN_PROVIDER.terrain_id_at(hex, HOLLOWMERE_TERRAIN.DEFINITION)
static func _is_farm_land(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_farm_land(hex, HOLLOWMERE_TERRAIN.DEFINITION)
static func _is_forest_candidate(hex: Vector2i) -> bool:
	return TERRAIN_PROVIDER.is_forest_candidate(hex, HOLLOWMERE_TERRAIN.DEFINITION)
static func _path_cells() -> Array[Vector2i]:
	return TERRAIN_PROVIDER.path_cells(HOLLOWMERE_TERRAIN.DEFINITION)
static func _water_cells() -> Array[Vector2i]:
	return TERRAIN_PROVIDER.water_cells(HOLLOWMERE_TERRAIN.DEFINITION)

func _initialize() -> void:
	_test_village_uses_shared_vegetation_generator()
	_test_village_bounds_and_terrain()
	_test_generic_terrain_provider_contract()
	_test_main_campaign_world_map()
	_test_road_network_connectivity()
	_test_building_thresholds()
	_test_tavern_door_contract()
	_test_building_definitions_use_shared_factory()
	_test_hollowmere_character_manifest()
	_test_animal_actor_registration()
	print("Hollowmere village tests passed.")
	quit()

func _test_village_bounds_and_terrain() -> void:
	assert(_is_in_bounds(Vector2i(12, 26)), "Rowan's crossroads area must be inside the playable map")
	assert(not _is_in_bounds(Vector2i(60, 60)), "The expanded outer map boundary must still reject distant cells")
	assert(_is_water(Vector2i(0, HOLLOWMERE_SETTLEMENT.STREAM_R)), "The stream should be water")
	assert(_is_blocked(Vector2i(0, HOLLOWMERE_SETTLEMENT.STREAM_R)), "The stream must block movement")
	assert(not _is_water(HOLLOWMERE_SETTLEMENT.BRIDGE), "The bridge must replace the water tile")
	assert(_is_in_bounds(HOLLOWMERE_SETTLEMENT.FARMHOUSE), "The farmhouse must be inside the expanded local map")
	assert(_is_in_bounds(HOLLOWMERE_SETTLEMENT.FARM_BARN), "The barn must be inside the expanded local map")
	assert(_is_building(HOLLOWMERE_SETTLEMENT.FARMHOUSE), "The farmhouse footprint must block movement")
	assert(_is_building(HOLLOWMERE_SETTLEMENT.FARM_BARN), "The barn footprint must block movement")
	assert(_is_farm_land(Vector2i(10, 60)), "Agricultural fields must be tagged as farm land")
	assert(not _is_forest_candidate(Vector2i(10, 60)), "Procedural trees must not grow through farm fields")
	assert(not _is_blocked(HOLLOWMERE_SETTLEMENT.BRIDGE), "The bridge must be traversable")
	assert(_terrain_id_at(Vector2i(0, 15)) == "path", "The general-store threshold should be a path")

func _test_generic_terrain_provider_contract() -> void:
	var definition: Dictionary = HOLLOWMERE_TERRAIN.DEFINITION
	assert(TERRAIN_PROVIDER.is_in_bounds(Vector2i(12, 26), definition), "Generic provider should include the authored playable area")
	assert(not TERRAIN_PROVIDER.is_in_bounds(Vector2i(60, 60), definition), "Generic provider should reject distant cells")
	assert(TERRAIN_PROVIDER.is_water(Vector2i(0, HOLLOWMERE_SETTLEMENT.STREAM_R), definition), "Generic provider should identify the stream")
	assert(not TERRAIN_PROVIDER.is_water(HOLLOWMERE_SETTLEMENT.BRIDGE, definition), "The authored bridge must exempt its cell from water")
	assert(TERRAIN_PROVIDER.is_building(HOLLOWMERE_SETTLEMENT.FARMHOUSE, definition), "Farmhouse footprint must be supplied by authored building data")
	assert(TERRAIN_PROVIDER.is_building(HOLLOWMERE_SETTLEMENT.FARM_BARN, definition), "Barn footprint must be supplied by authored building data")
	assert(TERRAIN_PROVIDER.is_door(HOLLOWMERE_SETTLEMENT.FARMHOUSE_DOOR, definition), "Farmhouse entrance must remain explicit")
	assert(not TERRAIN_PROVIDER.is_blocked(HOLLOWMERE_SETTLEMENT.FARMHOUSE_DOOR, definition), "Authored entrances must remain traversable")
	assert(TERRAIN_PROVIDER.is_path(Vector2i(0, 15), definition), "Store threshold must be on the authored path network")
	assert(TERRAIN_PROVIDER.is_farm_land(Vector2i(10, 60), definition), "Farm bounds must be supplied by authored data")
	assert(not TERRAIN_PROVIDER.is_forest_candidate(Vector2i(10, 60), definition), "Regional woodland rules must respect farm exclusions")
	var authored_path_cells: Array[Vector2i] = TERRAIN_PROVIDER.path_cells(definition)
	assert(not authored_path_cells.is_empty(), "Authored route rules must produce a navigable path network")
	var unique_path_cells: Dictionary = {}
	for path_cell in authored_path_cells:
		assert(not unique_path_cells.has(path_cell), "Path-cell enumeration must not contain duplicates")
		unique_path_cells[path_cell] = true
	assert(TERRAIN_PROVIDER.water_cells(definition).size() == 182, "Authored stream-cell enumeration must preserve the original 182 water cells")

func _test_road_network_connectivity() -> void:
	var path_cells := _path_cells()
	var path_set: Dictionary = {}
	for cell in path_cells:
		path_set[cell] = true
	assert(path_set.has(HOLLOWMERE_SETTLEMENT.CROSSROADS), "The signposted crossroads must be on the road network")
	assert(path_set.has(HOLLOWMERE_SETTLEMENT.BRIDGE), "The north road must include the bridge")
	for road_end in [Vector2i(8, -40), Vector2i(8, 32), Vector2i(-40, 24), Vector2i(16, 24)]:
		assert(path_set.has(road_end), "Each of the four crossroads roads must reach its map edge")

	var start := Vector2i(0, 6)
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for neighbour in HexGrid.neighbors(current):
			if path_set.has(neighbour) and not visited.has(neighbour):
				visited[neighbour] = true
				queue.append(neighbour)

	for destination in [
		HOLLOWMERE_SETTLEMENT.CROSSROADS,
		HOLLOWMERE_SETTLEMENT.BRIDGE,
		Vector2i(8, -40),
		Vector2i(8, 32),
		Vector2i(12, 54),
		Vector2i(-40, 24),
		Vector2i(16, 24),
		Vector2i(0, 15),
		Vector2i(-11, 0),
		Vector2i(0, -10),
		Vector2i(10, 9),
		Vector2i(-4, 9),
		HOLLOWMERE_SETTLEMENT.FARMHOUSE_DOOR,
		HOLLOWMERE_SETTLEMENT.FARM_BARN_DOOR
	]:
		assert(visited.has(destination), "Village road does not connect to %s" % destination)

func _test_building_definitions_use_shared_factory() -> void:
	var ids: Dictionary = {}
	var parent := Node3D.new()
	var constructed := 0
	for definition in HOLLOWMERE_BUILDINGS.BUILDINGS:
		var building_id := String(definition.get("id", ""))
		assert(not building_id.is_empty() and not ids.has(building_id), "Hollowmere building IDs must be unique")
		ids[building_id] = true
		assert(definition.has("center") and definition.has("half_q") and definition.has("half_r") and definition.has("door"), "%s must keep its logical footprint and entrance in the authored definition" % building_id)
		assert(definition.has("dimensions") and definition.has("door_side"), "%s must define its visual geometry and entrance" % building_id)
		var node := WORLD_BUILDING_FACTORY.create_building(parent, {"id": "hollowmere"}, definition)
		assert(node != null, "%s should be constructible through the shared factory" % building_id)
		assert(node.name == String(definition.get("node_name", building_id)), "The authored scene name should be preserved")
		assert(node.get_meta("source_door_hex") == definition.get("door"), "The logical entrance must match the shared building definition")
		if building_id == "old_mac_barn":
			assert(node.find_child("DoorLeaf_Left", true, false) != null and node.find_child("DoorLeaf_Right", true, false) != null, "The barn should use the shared double-door feature")
		constructed += 1
	assert(constructed == 8, "All village and farm buildings should use the shared factory")
	assert(parent.get_child_count() == constructed, "Each authored definition should create exactly one building root")
	parent.free()

	var village := WORLD_SETTLEMENT_PRESENTER.new() as Node3D
	village.call("configure_location", HOLLOWMERE_PRESENTATION.DEFINITION)
	village.call("_create_materials", HOLLOWMERE_PRESENTATION.DEFINITION.palette)
	village.call("_present_authored_features", HOLLOWMERE_PRESENTATION.DEFINITION.features, HexGrid.DEFAULT_RADIUS_M)
	assert(village.get_node_or_null("GeneralStore") != null, "The general store should be factory-built")
	assert(village.get_node_or_null("GeneralStore/StoreSignPresentation/StoreSign") != null, "The store sign should remain a separate add-on feature")
	assert(village.get_node_or_null("Chapel/ChapelBellTowerPresentation/BellTower") != null, "The chapel bell tower should remain a separate add-on feature")
	village.free()
func _test_tavern_door_contract() -> void:
	var door_definition: Dictionary = HOLLOW_TANKARD_LAYOUT.LOGICAL_DEFINITION.get("door", {})
	assert(HOLLOW_TANKARD_LAYOUT.DOOR_HEX == Vector2i(0, 4), "The Tankard door must use the source-authored (0,4) hex")
	assert(door_definition.get("hex", Vector2i.ZERO) == Vector2i(0, 4), "The registered door must use the same source-authored hex")
	assert(String(door_definition.get("id", "")) == HOLLOW_TANKARD_LAYOUT.FRONT_DOOR_ID, "The logical door ID must match the presentation layout")
	assert(not bool(door_definition.get("starts_open", true)), "The Tankard door must start closed for the opening scene")
	assert(bool(door_definition.get("starts_locked", false)), "The Tankard door must start locked until the soldiers enter")

	var door_state := BuildingDoorState.new()
	door_state.configure(
		String(door_definition.get("id", "")),
		String(door_definition.get("building_id", "")),
		Vector2i(door_definition.get("hex", Vector2i.ZERO)),
		bool(door_definition.get("starts_open", true)),
		bool(door_definition.get("starts_locked", false)),
		int(door_definition.get("durability", 20))
	)
	assert(not door_state.is_passable() and door_state.locked, "The opening door must initially block movement")
	assert(door_state.unlock() and door_state.open(), "The soldiers must be able to unlock and open the door")
	assert(door_state.is_passable(), "The opening door must become traversable for the soldiers")
	assert(door_state.close() and not door_state.is_passable(), "The soldiers should be able to close the door behind them")
	assert(not door_state.locked and door_state.open(), "The closed door must remain unlocked so the player can leave")

	var file := FileAccess.open("res://data/world/campaign2_multistory_locations.json", FileAccess.READ)
	assert(file != null, "The shared location manifest must exist")
	var manifest: Variant = JSON.parse_string(file.get_as_text())
	assert(manifest is Dictionary, "The shared location manifest must be valid JSON")
	var tavern: Dictionary = {}
	for location in manifest.get("locations", []):
		if location is Dictionary and String(location.get("id", "")) == "hollowmere_tavern":
			tavern = location
			break
	assert(not tavern.is_empty(), "The Hollow Tankard must remain in the authored location catalogue")
	assert(TERRAIN_PROVIDER.is_path(Vector2i(0, 5), HOLLOWMERE_TERRAIN.DEFINITION), "The Tankard door must connect directly to its source-authored outdoor path")
	var floor_zero: Dictionary = {}
	for floor_data in tavern.get("floors", []):
		if floor_data is Dictionary and int(floor_data.get("floor", 999999)) == 0:
			floor_zero = floor_data
			break
	var manifest_door: Dictionary = {}
	for tile_object in floor_zero.get("tile_objects", []):
		if tile_object is Dictionary and String(tile_object.get("id", "")) == HOLLOW_TANKARD_LAYOUT.FRONT_DOOR_ID:
			manifest_door = tile_object
			break
	assert(not manifest_door.is_empty(), "The shared manifest must use the same Tankard door ID as the live building")
	var manifest_door_position: Dictionary = manifest_door.get("position", {})
	assert(int(manifest_door_position.get("q", -999)) == 0 and int(manifest_door_position.get("r", -999)) == 4, "The manifest door coordinate must match the continuous-world layout")
	assert(String(manifest_door.get("type", "")) == "door_closed" and bool(manifest_door.get("locked", false)), "The manifest must preserve the opening door's initial locked state")


func _test_building_thresholds() -> void:
	assert(_is_blocked(Vector2i(0, 18)), "General-store footprint should block movement")
	assert(_is_blocked(Vector2i(-14, 0)), "Chapel footprint should block movement")
	assert(_is_blocked(Vector2i(0, -12)), "Elder-house footprint should block movement")
	for door in [Vector2i(0, 15), Vector2i(-11, 0), Vector2i(0, -10), Vector2i(10, 9), Vector2i(-4, 9), HOLLOWMERE_SETTLEMENT.FARMHOUSE_DOOR, HOLLOWMERE_SETTLEMENT.FARM_BARN_DOOR]:
		assert(not _is_blocked(door), "Building entrance should remain traversable: %s" % door)

func _test_hollowmere_character_manifest() -> void:
	var file := FileAccess.open("res://data/characters/hollowmere_npcs.json", FileAccess.READ)
	assert(file != null, "Hollowmere Ara profile manifest must exist")
	var manifest: Variant = JSON.parse_string(file.get_as_text())
	assert(manifest is Dictionary, "Hollowmere character manifest must be valid JSON")
	var characters: Array = manifest.get("characters", [])
	assert(characters.size() == 22, "Expected 13 village profiles, the player profile and eight canonical campaign companions")
	var ids: Dictionary = {}
	for profile in characters:
		assert(profile.has("id") and profile.has("game_id") and profile.has("params"))
		assert(not ids.has(profile["id"]), "Character profile IDs must be unique")
		ids[profile["id"]] = true
		var params: Dictionary = profile["params"]
		for slider in ["gender", "age", "muscle", "weight", "height", "proportions"]:
			assert(params.has(slider), "%s is missing Ara slider %s" % [profile["id"], slider])
			assert(float(params[slider]) >= 0.0 and float(params[slider]) <= 1.0)
		if String(profile["role"]) == "player avatar":
			assert(not profile.has("hex"), "Character profile data must not duplicate world placement")
			continue
		assert(not profile.has("hex"), "Character profile data must not duplicate world placement")
		var character_id := String(profile["id"])
		if HOLLOWMERE_PLACEMENTS.CHARACTER_STARTS.has(character_id):
			var spawn: Vector2i = HOLLOWMERE_PLACEMENTS.CHARACTER_STARTS[character_id]
			assert(_is_in_bounds(spawn), "%s spawn is outside Hollowmere" % character_id)
			assert(not _is_blocked(spawn), "%s spawn is not traversable" % character_id)
		else:
			assert(HOLLOWMERE_PLACEMENTS.DEFERRED_COMPANIONS.has(character_id), "%s must have a local start or an explicit deferred recruitment-region marker" % character_id)
	assert(HOLLOWMERE_PLACEMENTS.CHARACTER_STARTS.size() == 13, "Only characters actually present in the opening settlement should have local starts; Reyna is placed at Old Mac’s Farmstead")
	assert(ids.has("elder_marta"), "Elder Marta must retain her authored Hollowmere character profile")
	assert(HOLLOWMERE_PLACEMENTS.CHARACTER_STARTS.has("elder_marta"), "Elder Marta must be placed in the opening village")
	assert(HOLLOWMERE_PLACEMENTS.CHARACTER_STARTS["elder_marta"] == Vector2i(0, -9), "Elder Marta must remain at the authored elder-house position")
	assert(HOLLOWMERE_PLACEMENTS.DEFERRED_COMPANIONS.size() == 8, "Companions outside the opening settlement should remain explicitly deferred or retain their authored external placement")
	assert(HOLLOWMERE_PLACEMENTS.FARM_ANIMALS.size() == 6, "All six farm animal placements must remain authored")
	assert(HOLLOWMERE_PLACEMENTS.WILDERNESS_ANIMALS.size() == 4, "All four ambient wildlife placements must remain authored")
	var companion_names := ["Ser Aldric Thorne", "Nix Sharpear", "Warlord Grukk Ironhide", "Reyna Fletcher", "Mirabel Quill", "Fenn Oakheart", "Brother Alden", "Snik Fangtooth"]
	var companion_count := 0
	for profile in characters:
		if String(profile.get("role", "")) != "companion":
			continue
		companion_count += 1
		# Wren is the authored opening-party character and retains her separate
		# starting-character setup. The eight recruitable campaign companions
		# carry canonical runtime progression records in this manifest.
		if String(profile.get("detail", "")) == "runtime":
			assert(profile.has("progression"), "%s must have source-authored progression" % profile.get("name", "companion"))
			var progression: Dictionary = profile["progression"]
			assert(not progression.get("class_levels", []).is_empty(), "Canonical companions need ordered class levels")
			assert(not progression.get("skill_picks", []).is_empty(), "Canonical companions need authored skill preferences")
	assert(companion_count == 9, "Wren plus eight original campaign companions should be staged in Hollowmere")
	for companion_name in companion_names:
		var found := false
		for profile in characters:
			if String(profile.get("name", "")) == companion_name:
				found = true
				break
		assert(found, "Missing original companion: %s" % companion_name)

func _test_main_campaign_world_map() -> void:
	var grid := MAIN_CAMPAIGN_MAP.generate_grid()
	assert(grid.size() == 16, "The original Campaign 2 strategic map must have 16 rows")
	for row in grid:
		assert(row.size() == 16, "Every strategic map row must have 16 cells")

	for row in grid:
		assert(row[0]["terrain"] == "ocean", "The western edge should be ocean")
	assert(grid[6][6]["faction"] == "humans", "Hollowmere should be in human lands")
	assert(grid[15][5]["faction"] == "elves", "The southern forest belt should be elven territory")
	assert(grid[1][14]["faction"] == "dwarves", "The north-east mountain block should be dwarven")
	assert(grid[10][12]["faction"] == "orcs", "The eastern territory should be orc-held")

	assert(grid[6][6]["poi"]["name"] == "Hollowmere", "Hollowmere must be the starting-village marker")
	assert(grid[3][6]["poi"]["name"] == "Millbrook", "Millbrook should lie north of Hollowmere")
	assert(grid[2][6]["poi"]["name"] == "Silverhart", "Silverhart should lie beyond Millbrook")
	assert(grid[6][7]["poi"]["name"] == "Reddale", "Reddale should lie east of Hollowmere")
	assert(grid[6][4]["poi"]["name"] == "Emberlode", "Emberlode should lie west of Hollowmere")
	assert(grid[7][6]["poi"]["name"] == "Old Mac's Farmstead", "The farmstead should lie south of Hollowmere")

	var river_path := MAIN_CAMPAIGN_MAP.strategic_river_path()
	assert(river_path.size() == 15, "The source river path should contain 15 strategic cells")
	assert(river_path[0] == Vector2i(1, 5))
	assert(river_path[14] == Vector2i(15, 4))
	assert(MAIN_CAMPAIGN_MAP.world_cell_from_local_hex(Vector2i(8, 24)) == Vector2i(6, 6), "The local crossroads must map to Hollowmere's world cell")

func _test_animal_actor_registration() -> void:
	var village := WORLD_SETTLEMENT_PRESENTER.new() as Node3D
	village.call("configure_location", HOLLOWMERE_PRESENTATION.DEFINITION)
	village.call("_spawn_authored_creatures", HOLLOWMERE_PRESENTATION.DEFINITION.creatures, HexGrid.DEFAULT_RADIUS_M)
	var simulation := WorldSimulation.new()
	# Simulate a saved animal already restored into WorldSimulation before
	# WorldRoot reconnects the exterior presentation actors.
	var restored_horse := AnimalCatalog.create_state("horse", "animal_farmhorse", "Farm Horse", Vector2i(30, 61), 991)
	restored_horse.side = "player"
	restored_horse.combat_dormant = false
	restored_horse.facing_direction = 3
	assert(bool(simulation.register_animal(restored_horse).get("ok", false)), "The saved horse fixture should register before scene binding")
	var result: Dictionary = village.call("register_animals_with_simulation", simulation)
	assert(bool(result.get("ok", false)), "All authored Hollowmere animals should register or bind to restored states")
	var registered_ids: Array = result.get("registered_ids", [])
	assert(registered_ids.size() == 10, "The six farm animals and four wilderness animals should be bound")
	assert((result.get("skipped", []) as Array).is_empty(), "No authored animal should be skipped during registration")
	var actor_count := 0
	var farm_horse: CreatureActor
	for child in village.get_children():
		var actor := child as CreatureActor
		if actor == null:
			continue
		actor_count += 1
		assert(actor.axial_hex != Vector2i.ZERO, "%s should retain its authored or restored hex" % actor.name)
		assert(actor.is_in_group("creature_actors"), "%s should be discoverable by mount presentation lookup" % actor.name)
		assert(actor.simulation_state != null, "%s should retain its registered simulation state" % actor.name)
		assert(simulation.get_character(actor.simulation_state.id) == actor.simulation_state, "%s should reference the canonical simulation state" % actor.name)
		if actor.name == "FarmHorse":
			farm_horse = actor
		else:
			assert(actor.simulation_state.side == "neutral", "New ambient animals should remain neutral")
			assert(actor.simulation_state.combat_dormant, "New ambient animals should remain dormant until activated")
			assert(actor.simulation_state.tags.has("ambient_animal"), "New village animals should be tagged as ambient wildlife")
	assert(actor_count == 10, "The test should exercise every authored village animal actor")
	assert(farm_horse != null and farm_horse.simulation_state == restored_horse, "The visual horse must bind to the restored canonical state")
	assert(farm_horse.axial_hex == Vector2i(30, 61), "The visual horse should move to its saved hex")
	assert(farm_horse.position.distance_to(HexGrid.axial_to_world(Vector2i(30, 61), HexGrid.DEFAULT_RADIUS_M, 0.0)) < 0.001, "The visual horse should restore its saved world position")
	assert(is_equal_approx(farm_horse.rotation.y, deg_to_rad(-60.0)), "The visual horse should restore its saved facing")
	assert(restored_horse.side == "player" and not restored_horse.combat_dormant, "Binding must not reset restored animal status")
	var repeated: Dictionary = village.call("register_animals_with_simulation", simulation)
	assert(bool(repeated.get("ok", false)), "Repeated registration should be idempotent")
	assert((repeated.get("registered_ids", []) as Array).size() == 10, "Repeated registration should bind all ten canonical states")
	assert((repeated.get("skipped", []) as Array).is_empty(), "Repeated registration should not report duplicates as errors")
	assert(simulation.characters.size() == 10, "Repeated registration must leave the campaign registry unchanged")
	village.free()
	simulation.free()

func _test_village_uses_shared_vegetation_generator() -> void:
	var village := WORLD_SETTLEMENT_PRESENTER.new() as Node3D
	village.call("configure_location", HOLLOWMERE_PRESENTATION.DEFINITION)
	village.call("_generate_vegetation", HOLLOWMERE_PRESENTATION.DEFINITION.vegetation, HexGrid.DEFAULT_RADIUS_M)
	var canopy_count := 0
	var understorey_count := 0
	for child in village.get_children():
		if String(child.name).begins_with("HollowmereTree_"):
			canopy_count += 1
		elif String(child.name).begins_with("HollowmereUnderstorey_"):
			understorey_count += 1
		if String(child.name).begins_with("HollowmereTree_") or String(child.name).begins_with("HollowmereUnderstorey_"):
			assert(child.has_meta("vegetation_family"), "Generated vegetation must identify its shared catalogue family")
	assert(canopy_count > 0, "The shared generator should populate Hollowmere's canopy")
	assert(understorey_count > 0, "The shared generator should populate Hollowmere's understorey")
	village.free()
