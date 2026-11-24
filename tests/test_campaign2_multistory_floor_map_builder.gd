extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
const LOCATION_STATE = preload("res://scripts/simulation/campaign2_multistory_location_state.gd")
const FLOOR_BUILDER = preload("res://scripts/world/campaign2_multistory_floor_map_builder.gd")
var failures: int = 0

func _initialize() -> void:
	var registry = REGISTRY.new()
	var definition: Dictionary = registry.get_definition("kragmoor")
	_check(not definition.is_empty(), "Kragmoor source floor definition must be available")
	var state = LOCATION_STATE.new()
	_check(bool(state.configure(definition).get("ok", false)), "Kragmoor traversal state must configure")

	for floor_number in [0, -1, -2, -3, -4, -5]:
		var result: Dictionary = FLOOR_BUILDER.build_floor_map(definition, floor_number, state)
		_check(bool(result.get("ok", false)), "Every Kragmoor floor must build a logical map: %d" % floor_number)
		if not bool(result.get("ok", false)):
			continue
		var map_data: HexMapData = result.get("map_data") as HexMapData
		_check(map_data != null and not map_data.cells.is_empty(), "Each floor must contain walkable and wall cells")
		for actor in result.get("actors", []):
			var position: Dictionary = actor.get("position", {})
			_check(map_data.is_walkable(Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))), "Every source actor must stand on a walkable floor hex")
		for creature in result.get("creatures", []):
			var position: Dictionary = creature.get("position", {})
			_check(map_data.is_walkable(Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))), "Every source creature must stand on a walkable floor hex")
		for tile_object in result.get("tile_objects", []):
			var position: Dictionary = tile_object.get("position", {})
			_check(map_data.is_walkable(Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))), "Every tile object must be placed on a walkable floor hex")

	var guild_definition: Dictionary = registry.get_definition("silverhart_thieves_guild")
	var guild_state = LOCATION_STATE.new()
	_check(bool(guild_state.configure(guild_definition).get("ok", false)), "Thieves' Guild state must configure with its hidden vault")
	var concealed_guild: Dictionary = FLOOR_BUILDER.build_floor_map(guild_definition, 0, guild_state)
	var concealed_map: HexMapData = concealed_guild.get("map_data") as HexMapData
	_check(not _has_object(concealed_guild.get("tile_objects", []), "guild_hidden_vault_door"), "Undiscovered secret door must not be presented")
	_check(not _has_object(concealed_guild.get("tile_objects", []), "guild_vault_chest"), "Undiscovered vault contents must not be presented")
	_check(concealed_map.is_walkable(Vector2i(18, -426)), "The Guild's dead-end corridor must reach the concealed wall")
	_check(not concealed_map.is_walkable(Vector2i(19, -426)) and not concealed_map.is_walkable(Vector2i(20, -426)), "Undiscovered vault must remain sealed and absent from the walkable map")
	_check(bool(guild_state.discover_secret("guild_hidden_vault_door").get("ok", false)), "The Guild secret door must be discoverable in persistent location state")
	var revealed_guild: Dictionary = FLOOR_BUILDER.build_floor_map(guild_definition, 0, guild_state)
	var revealed_map: HexMapData = revealed_guild.get("map_data") as HexMapData
	_check(_has_object(revealed_guild.get("tile_objects", []), "guild_hidden_vault_door"), "Discovered secret door must be presented")
	_check(_has_object(revealed_guild.get("tile_objects", []), "guild_vault_chest"), "Discovered vault contents must be presented")
	_check(revealed_map.is_walkable(Vector2i(19, -426)) and revealed_map.is_walkable(Vector2i(20, -426)), "Discovered vault must become walkable through its hidden door")


	# Silverhart's merchant-quarter interiors are built from the source room
	# footprints, with their exterior doors opening onto walkable floor cells.
	var merchant_door_hexes := {
		"silverhart_stables": Vector2i(-19, -502),
		"silverhart_general_goods": Vector2i(-19, -490),
		"silverhart_clothier": Vector2i(-32, -502),
		"silverhart_magic_shop": Vector2i(-32, -490)
	}
	for interior_id in merchant_door_hexes:
		var interior_definition: Dictionary = registry.get_definition(interior_id)
		var interior_state = LOCATION_STATE.new()
		_check(bool(interior_state.configure(interior_definition).get("ok", false)), "Merchant interior state must configure: " + interior_id)
		var interior_result: Dictionary = FLOOR_BUILDER.build_floor_map(interior_definition, 0, interior_state)
		_check(bool(interior_result.get("ok", false)), "Merchant interior floor must build: " + interior_id)
		if not bool(interior_result.get("ok", false)):
			continue
		var interior_map: HexMapData = interior_result.get("map_data") as HexMapData
		_check(interior_map.is_walkable(merchant_door_hexes[interior_id]), "Merchant entrance must be walkable: " + interior_id)
		for object_variant in interior_result.get("tile_objects", []):
			var object_position: Dictionary = object_variant.get("position", {})
			var object_hex := Vector2i(int(object_position.get("q", 0)), int(object_position.get("r", 0)))
			_check(interior_map.is_walkable(object_hex), "Merchant fixture must sit on walkable interior floor: " + String(object_variant.get("id", "")))
	var emberlode_definition: Dictionary = registry.get_definition("emberlode_mine")
	var emberlode_state = LOCATION_STATE.new()
	_check(bool(emberlode_state.configure(emberlode_definition).get("ok", false)), "Emberlode Mine traversal state must configure")
	for floor_number in [0, -1, -2]:
		var mine_result: Dictionary = FLOOR_BUILDER.build_floor_map(emberlode_definition, floor_number, emberlode_state)
		_check(bool(mine_result.get("ok", false)), "Every Emberlode mine floor must build: %d" % floor_number)
		if not bool(mine_result.get("ok", false)):
			continue
		var mine_map: HexMapData = mine_result.get("map_data") as HexMapData
		_check(mine_map != null and not mine_map.cells.is_empty(), "Every Emberlode floor must contain a logical map")
		for mine_object in mine_result.get("tile_objects", []):
			var object_position: Dictionary = mine_object.get("position", {})
			_check(mine_map.is_walkable(Vector2i(int(object_position.get("q", 0)), int(object_position.get("r", 0)))), "Every Emberlode mine object must be on a walkable hex")
		for creature in mine_result.get("creatures", []):
			var creature_position: Dictionary = creature.get("position", {})
			_check(mine_map.is_walkable(Vector2i(int(creature_position.get("q", 0)), int(creature_position.get("r", 0)))), "Every source spider placement must be on a walkable Old Seam hex")
	var mine_surface_map: HexMapData = FLOOR_BUILDER.build_floor_map(emberlode_definition, 0, emberlode_state).get("map_data") as HexMapData
	_check(mine_surface_map.is_walkable(Vector2i(-254, 14)), "Emberlode surface must preserve the source carveBuilding row shift on its western edge")
	_check(not mine_surface_map.is_walkable(Vector2i(-254, 17)), "Emberlode surface must not mirror the source carveBuilding row shift")
	_check(mine_surface_map.is_walkable(Vector2i(-252, 18)) and mine_surface_map.is_walkable(Vector2i(-252, 17)) and mine_surface_map.is_walkable(Vector2i(-252, 16)) and mine_surface_map.is_walkable(Vector2i(-252, 15)), "Emberlode source door, room floor and stair must remain directly connected")
	var working_vein_map: HexMapData = FLOOR_BUILDER.build_floor_map(emberlode_definition, -1, emberlode_state).get("map_data") as HexMapData
	_check(working_vein_map.is_walkable(Vector2i(-252, 15)) and working_vein_map.is_walkable(Vector2i(-252, 17)), "Working Vein must connect both source stair positions")
	var old_seam_result: Dictionary = FLOOR_BUILDER.build_floor_map(emberlode_definition, -2, emberlode_state)
	_check(old_seam_result.get("creatures", []).size() == 2, "Old Seam must expose both spider spawn placements to the campaign actor layer")

	var cove_definition: Dictionary = registry.get_definition("thieves_cove")
	var cove_state = LOCATION_STATE.new()
	_check(bool(cove_state.configure(cove_definition).get("ok", false)), "Thieves' Cove traversal state must configure")
	for floor_number in [0, -1, -2, -9]:
		var cove_result: Dictionary = FLOOR_BUILDER.build_floor_map(cove_definition, floor_number, cove_state)
		_check(bool(cove_result.get("ok", false)), "Every Thieves' Cove floor must build: %d" % floor_number)
		if not bool(cove_result.get("ok", false)):
			continue
		var cove_map: HexMapData = cove_result.get("map_data") as HexMapData
		_check(cove_map != null and not cove_map.cells.is_empty(), "Every Thieves' Cove level must contain a logical map")
		_check(cove_map.is_walkable(Vector2i(-274, 40)), "Every Thieves' Cove level must preserve its source stair/junction anchor")
	var cove_surface: Dictionary = FLOOR_BUILDER.build_floor_map(cove_definition, 0, cove_state)
	_check(_has_object(cove_surface.get("tile_objects", []), "sunken_cave_front_door"), "Cove entrance must retain its source west-facing door")
	_check(_has_object(cove_surface.get("tile_objects", []), "transition_0_-1"), "Cove entrance must connect down to the den")
	var cove_den: Dictionary = FLOOR_BUILDER.build_floor_map(cove_definition, -1, cove_state)
	_check(_has_object(cove_den.get("tile_objects", []), "transition_-1_0"), "Den must connect back to the entrance")
	_check(_has_object(cove_den.get("tile_objects", []), "transition_-1_-2"), "Den must connect down to the hidden vault")
	_check(_has_object(cove_den.get("tile_objects", []), "transition_-1_-9"), "Den must retain its separate wilderness tunnel junction")
	var cove_vault: Dictionary = FLOOR_BUILDER.build_floor_map(cove_definition, -2, cove_state)
	_check(_has_object(cove_vault.get("tile_objects", []), "transition_-2_-1"), "Hidden vault must connect back to the den")
	var cove_tunnel: Dictionary = FLOOR_BUILDER.build_floor_map(cove_definition, -9, cove_state)
	_check(cove_tunnel.get("walkable_hexes", []).size() == 1, "Wilderness tunnel junction must remain a one-cell stub")

	var crypt_definition: Dictionary = registry.get_definition("vessel_seekers_crypt")
	var crypt_state = LOCATION_STATE.new()
	_check(bool(crypt_state.configure(crypt_definition).get("ok", false)), "Vessel-Seeker crypt state must configure")
	var crypt_result: Dictionary = FLOOR_BUILDER.build_floor_map(crypt_definition, 0, crypt_state)
	_check(bool(crypt_result.get("ok", false)), "Vessel-Seeker crypt source floor must build")
	if bool(crypt_result.get("ok", false)):
		var crypt_map: HexMapData = crypt_result.get("map_data") as HexMapData
		_check(_has_walkable_path(crypt_map, Vector2i(29, -154), Vector2i(49, -154)), "Crypt entrance, ossuary and ritual chambers must form one connected walkable layout")
		_check(_has_object(crypt_result.get("tile_objects", []), "crypt_entrance_door") and _has_object(crypt_result.get("tile_objects", []), "crypt_ossuary_door") and _has_object(crypt_result.get("tile_objects", []), "crypt_ritual_door"), "Crypt must emit all three source door openings")
		_check(crypt_result.get("actors", []).is_empty() and crypt_result.get("creatures", []).is_empty(), "Map-only crypt floor must leave encounters to campaign systems")
	var barrow_definition: Dictionary = registry.get_definition("corvin_ashgrave_barrow")
	var barrow_state = LOCATION_STATE.new()
	_check(bool(barrow_state.configure(barrow_definition).get("ok", false)), "Corvin Ashgrave barrow state must configure")
	var barrow_result: Dictionary = FLOOR_BUILDER.build_floor_map(barrow_definition, 0, barrow_state)
	_check(bool(barrow_result.get("ok", false)), "Corvin Ashgrave source floor must build")
	if bool(barrow_result.get("ok", false)):
		var barrow_map: HexMapData = barrow_result.get("map_data") as HexMapData
		_check(_has_walkable_path(barrow_map, Vector2i(60, -160), Vector2i(72, -160)), "Barrow antechamber and sanctum must form one connected walkable layout")
		_check(barrow_map.is_walkable(Vector2i(60, -160)), "Barrow entrance doorway must be walkable")
		_check(barrow_map.is_walkable(Vector2i(63, -160)), "Barrow antechamber centre must be walkable")
		_check(barrow_map.is_walkable(Vector2i(66, -160)) and barrow_map.is_walkable(Vector2i(67, -160)) and barrow_map.is_walkable(Vector2i(68, -160)) and barrow_map.is_walkable(Vector2i(69, -160)), "Source corridor must connect the antechamber to the sanctum doorway")
		_check(barrow_map.is_walkable(Vector2i(72, -160)), "Lich sanctum centre must be walkable")
		_check(_has_object(barrow_result.get("tile_objects", []), "barrow_entrance_door") and _has_object(barrow_result.get("tile_objects", []), "lich_sanctum_door"), "Both source door openings must be emitted")
		_check(barrow_result.get("actors", []).is_empty() and barrow_result.get("creatures", []).is_empty(), "Map-only barrow floor must leave encounters to campaign systems")

	var elven_definition: Dictionary = registry.get_definition("silthandriel")
	var elven_state = LOCATION_STATE.new()
	_check(bool(elven_state.configure(elven_definition).get("ok", false)), "Sil'thandriel traversal state must configure")
	var tree_base: Dictionary = FLOOR_BUILDER.build_floor_map(elven_definition, 0, elven_state)
	_check(bool(tree_base.get("ok", false)), "Sil'thandriel surface stair must build without inventing a room")
	_check((tree_base.get("wall_hexes", []) as Array).is_empty(), "The open surface clearing must not acquire enclosing walls")
	_check(_has_object(tree_base.get("tile_objects", []), "tree_stair_up"), "Surface tree stair must be presented")
	var lower_canopy: Dictionary = FLOOR_BUILDER.build_floor_map(elven_definition, 1, elven_state)
	_check(bool(lower_canopy.get("ok", false)), "Lower Canopy platforms and connecting corridors must build")
	_check(_has_object(lower_canopy.get("tile_objects", []), "lodge_herb_patch_west"), "West lodge herb patch must be presented")
	_check(_has_object(lower_canopy.get("tile_objects", []), "lodge_herb_patch_east"), "East lodge herb patch must be presented")
	var upper_court: Dictionary = FLOOR_BUILDER.build_floor_map(elven_definition, 2, elven_state)
	_check(bool(upper_court.get("ok", false)), "Upper Court pavilion must build")
	_check((upper_court.get("wall_hexes", []) as Array).is_empty(), "Open-air Court must not generate a wall ring")
	_check(_has_object(upper_court.get("tile_objects", []), "court_throne"), "Upper Court throne must be presented")

	# Northwatch's hexagonal keep and Ridgehold's flat keep are
	# represented by exact source-authored floor/wall masks, not rectangles.
	var northwatch_definition: Dictionary = registry.get_definition("northwatch_keep")
	var northwatch_state = LOCATION_STATE.new()
	_check(bool(northwatch_state.configure(northwatch_definition).get("ok", false)), "Northwatch keep state must configure")
	var northwatch_result: Dictionary = FLOOR_BUILDER.build_floor_map(northwatch_definition, 0, northwatch_state)
	_check(bool(northwatch_result.get("ok", false)), "Northwatch keep source floor must build")
	if bool(northwatch_result.get("ok", false)):
		var northwatch_map: HexMapData = northwatch_result.get("map_data") as HexMapData
		_check(northwatch_result.get("walkable_hexes", []).size() == 67, "Northwatch keep must retain its 61-cell core and six open corner gaps")
		_check(northwatch_result.get("wall_hexes", []).size() == 24, "Northwatch keep must retain its 24 closed wall-ring cells")
		for gap in [Vector2i(273, -21), Vector2i(273, -26), Vector2i(268, -26), Vector2i(263, -21), Vector2i(263, -16), Vector2i(268, -16)]:
			_check(northwatch_map.is_walkable(gap), "Every source keep corner gap must remain walkable: %s" % gap)
		_check(not northwatch_map.is_walkable(Vector2i(273, -22)), "Northwatch keep wall ring must remain closed between its source gaps")
		_check(_has_object(northwatch_result.get("tile_objects", []), "northwatch_keep_fireplace"), "Northwatch keep fireplace must be presented")
		_check(_has_object(northwatch_result.get("tile_objects", []), "northwatch_keep_door"), "Northwatch keep primary source gap must be presented as an entrance")
	var ridgehold_definition: Dictionary = registry.get_definition("ridgehold_keep")
	var ridgehold_state = LOCATION_STATE.new()
	_check(bool(ridgehold_state.configure(ridgehold_definition).get("ok", false)), "Ridgehold keep state must configure")
	var ridgehold_result: Dictionary = FLOOR_BUILDER.build_floor_map(ridgehold_definition, 0, ridgehold_state)
	_check(bool(ridgehold_result.get("ok", false)), "Ridgehold keep source floor must build")
	if bool(ridgehold_result.get("ok", false)):
		var ridgehold_map: HexMapData = ridgehold_result.get("map_data") as HexMapData
		_check(ridgehold_result.get("walkable_hexes", []).size() == 16, "Ridgehold keep must retain its 15-cell room and open source doorway")
		_check(ridgehold_result.get("wall_hexes", []).size() == 17, "Ridgehold keep must retain its source wall ring around the open door")
		_check(ridgehold_map.is_walkable(Vector2i(426, 45)), "Ridgehold keep source east doorway must be walkable")
		_check(ridgehold_map.is_walkable(Vector2i(426, 43)), "Ridgehold keep fireplace hex must be walkable")
		_check(not ridgehold_map.is_walkable(Vector2i(425, 42)), "Ridgehold keep wall ring must remain solid")
		_check(_has_object(ridgehold_result.get("tile_objects", []), "ridgehold_keep_fireplace"), "Ridgehold keep fireplace must be presented")
		_check(_has_object(ridgehold_result.get("tile_objects", []), "ridgehold_keep_door"), "Ridgehold keep source door must be presented")

	var gate_hall: Dictionary = FLOOR_BUILDER.build_floor_map(definition, 0, state)
	var gate_map: HexMapData = gate_hall.get("map_data") as HexMapData
	_check(gate_map.is_walkable(Vector2i(908, -605)), "The source Gate Hall entrance door must be walkable")
	_check(gate_map.is_walkable(Vector2i(908, -610)), "The Gate Hall stair must be walkable")

	var great_hall: Dictionary = FLOOR_BUILDER.build_floor_map(definition, -1, state)
	var great_map: HexMapData = great_hall.get("map_data") as HexMapData
	_check(great_map.has_cell(Vector2i(908, -630)) and not great_map.is_walkable(Vector2i(908, -630)), "The Great Hall must retain its source wall ring")

	var sealed: Dictionary = FLOOR_BUILDER.build_floor_map(definition, -4, state)
	_check(not _has_object(sealed.get("tile_objects", []), "transition_-4_-5"), "The final stair must not exist before the quest")
	_check((sealed.get("map_data") as HexMapData).is_walkable(Vector2i(890, -605)), "The hidden stair location remains part of the existing tunnel floor")
	_check(not _has_object(sealed.get("tile_objects", []), "transition_-4_-5"), "The hidden floor hex must not expose a stair object before the quest")
	state.complete_quest("deepholds_infestation")
	var revealed: Dictionary = FLOOR_BUILDER.build_floor_map(definition, -4, state)
	_check(_has_object(revealed.get("tile_objects", []), "transition_-4_-5"), "The quest must add the stair-down object to the Lower Tunnels")
	_check((revealed.get("map_data") as HexMapData).is_walkable(Vector2i(890, -605)), "The revealed stair hex must be walkable")

	var emberlode_building_registry := REGISTRY.new()
	var emberlode_building_entrances := {
		"emberlode_bunkhouse": Vector2i(-252, 26),
		"emberlode_foremans_hall": Vector2i(-253, 22)
	}
	for location_id in emberlode_building_entrances:
		var emberlode_building_definition: Dictionary = emberlode_building_registry.get_definition(location_id)
		var emberlode_building_state = LOCATION_STATE.new()
		_check(bool(emberlode_building_state.configure(emberlode_building_definition).get("ok", false)), "Emberlode building state must configure: " + location_id)
		var emberlode_building_result: Dictionary = FLOOR_BUILDER.build_floor_map(emberlode_building_definition, 0, emberlode_building_state)
		_check(bool(emberlode_building_result.get("ok", false)), "Emberlode building floor must build: " + location_id)
		if not bool(emberlode_building_result.get("ok", false)):
			continue
		var emberlode_building_map: HexMapData = emberlode_building_result.get("map_data") as HexMapData
		_check(emberlode_building_map.is_walkable(emberlode_building_entrances[location_id]), "Emberlode building entrance must be walkable: " + location_id)
		for emberlode_building_object in emberlode_building_result.get("tile_objects", []):
			var emberlode_building_position: Dictionary = emberlode_building_object.get("position", {})
			var emberlode_building_hex := Vector2i(int(emberlode_building_position.get("q", 0)), int(emberlode_building_position.get("r", 0)))
			_check(emberlode_building_map.is_walkable(emberlode_building_hex), "Emberlode building fixture must be walkable: " + String(emberlode_building_object.get("id", "")))
		if location_id == "emberlode_foremans_hall":
			_check(_has_object(emberlode_building_result.get("tile_objects", []), "emberlode_foremans_hall_fireplace"), "Foreman's Hall must retain its source fireplace")

	var abandoned_house_registry := REGISTRY.new()
	var abandoned_house_definition: Dictionary = abandoned_house_registry.get_definition("abandoned_house")
	var abandoned_house_state = LOCATION_STATE.new()
	_check(bool(abandoned_house_state.configure(abandoned_house_definition).get("ok", false)), "Abandoned House traversal state must configure")
	var abandoned_house_result: Dictionary = FLOOR_BUILDER.build_floor_map(abandoned_house_definition, 0, abandoned_house_state)
	_check(bool(abandoned_house_result.get("ok", false)), "Abandoned House floor must build")
	var abandoned_house_map: HexMapData = abandoned_house_result.get("map_data") as HexMapData
	_check(abandoned_house_map != null and not abandoned_house_map.cells.is_empty(), "Abandoned House must produce a walkable source floor")
	_check(abandoned_house_map.is_walkable(Vector2i(11, -176)), "Abandoned House west entrance must be walkable")
	_check(_has_object(abandoned_house_result.get("tile_objects", []), "abandoned_house_journal"), "Abandoned House journal must be present in the built floor map")
	_check(_has_object(abandoned_house_result.get("tile_objects", []), "phylactery_altar"), "Phylactery altar must be present in the built floor map")

	var guild_den_registry := REGISTRY.new()
	var guild_den_definition: Dictionary = guild_den_registry.get_definition("hollowmere_guild_den")
	var guild_den_state = LOCATION_STATE.new()
	_check(bool(guild_den_state.configure(guild_den_definition).get("ok", false)), "Hollowmere Guild Den traversal state must configure")
	var guild_den_result: Dictionary = FLOOR_BUILDER.build_floor_map(guild_den_definition, 0, guild_den_state)
	_check(bool(guild_den_result.get("ok", false)), "Hollowmere Guild Den floor must build")
	var guild_den_map: HexMapData = guild_den_result.get("map_data") as HexMapData
	_check(guild_den_map != null and not guild_den_map.cells.is_empty(), "Guild Den must produce a walkable source floor")
	_check(guild_den_map.is_walkable(Vector2i(-12, -6)), "Guild Den south entrance must be walkable")
	_check(_has_object(guild_den_result.get("tile_objects", []), "hollowmere_guild_den_door"), "Guild Den entrance must be presented as a door")

	var millbrook_registry := REGISTRY.new()
	var millbrook_definition: Dictionary = millbrook_registry.get_definition("millbrook_house")
	var millbrook_state = LOCATION_STATE.new()
	_check(bool(millbrook_state.configure(millbrook_definition).get("ok", false)), "Millbrook house traversal state must configure")
	var millbrook_result: Dictionary = FLOOR_BUILDER.build_floor_map(millbrook_definition, 0, millbrook_state)
	_check(bool(millbrook_result.get("ok", false)), "Millbrook house floor must build")
	var millbrook_map: HexMapData = millbrook_result.get("map_data") as HexMapData
	_check(millbrook_map != null and not millbrook_map.cells.is_empty(), "Millbrook house must produce a walkable source floor")
	_check(millbrook_map.is_walkable(Vector2i(4, -366)), "Millbrook house east entrance must be walkable")
	_check(_has_object(millbrook_result.get("tile_objects", []), "millbrook_house_fireplace"), "Millbrook house fireplace must be presented")

	var farmhouse_registry := REGISTRY.new()
	var farmhouse_definition: Dictionary = farmhouse_registry.get_definition("old_mac_farmhouse")
	var farmhouse_state = LOCATION_STATE.new()
	_check(bool(farmhouse_state.configure(farmhouse_definition).get("ok", false)), "Old Mac's farmhouse state must configure")
	var farmhouse_result: Dictionary = FLOOR_BUILDER.build_floor_map(farmhouse_definition, 0, farmhouse_state)
	_check(bool(farmhouse_result.get("ok", false)), "Old Mac's farmhouse floor must build")
	var farmhouse_map: HexMapData = farmhouse_result.get("map_data") as HexMapData
	_check(farmhouse_map != null and not farmhouse_map.cells.is_empty(), "Farmhouse must produce a walkable source floor")
	_check(farmhouse_map.is_walkable(Vector2i(3, 194)), "Farmhouse east entrance must be walkable")

	var hollowmere_building_registry := REGISTRY.new()
	var hollowmere_building_entrances := {
		"hollowmere_chapel": Vector2i(-11, 0),
		"hollowmere_general_store": Vector2i(0, 15),
		"hollowmere_house": Vector2i(0, -10),
		"hollowmere_store": Vector2i(10, 0),
		"hollowmere_tavern": Vector2i(0, 4),
		"mira_house": Vector2i(10, 9),
		"oskar_house": Vector2i(-4, 9)
	}
	for location_id in hollowmere_building_entrances:
		var hollowmere_building_definition: Dictionary = hollowmere_building_registry.get_definition(location_id)
		var hollowmere_building_state = LOCATION_STATE.new()
		_check(bool(hollowmere_building_state.configure(hollowmere_building_definition).get("ok", false)), "Hollowmere building state must configure: " + location_id)
		var hollowmere_building_result: Dictionary = FLOOR_BUILDER.build_floor_map(hollowmere_building_definition, 0, hollowmere_building_state)
		_check(bool(hollowmere_building_result.get("ok", false)), "Hollowmere building floor must build: " + location_id)
		if not bool(hollowmere_building_result.get("ok", false)):
			continue
		var hollowmere_building_map: HexMapData = hollowmere_building_result.get("map_data") as HexMapData
		_check(hollowmere_building_map.is_walkable(hollowmere_building_entrances[location_id]), "Hollowmere entrance must be walkable: " + location_id)
		for hollowmere_object in hollowmere_building_result.get("tile_objects", []):
			var hollowmere_position: Dictionary = hollowmere_object.get("position", {})
			var hollowmere_hex := Vector2i(int(hollowmere_position.get("q", 0)), int(hollowmere_position.get("r", 0)))
			_check(hollowmere_building_map.is_walkable(hollowmere_hex), "Hollowmere fixture must sit on walkable floor: " + String(hollowmere_object.get("id", "")))
		if location_id == "hollowmere_tavern":
			for tavern_fixture_id in ["hollowmere_tavern_fireplace", "hollowmere_tavern_table_east", "hollowmere_tavern_bench_east", "hollowmere_tavern_table_west", "hollowmere_tavern_bench_west"]:
				_check(_has_object(hollowmere_building_result.get("tile_objects", []), tavern_fixture_id), "Tavern must retain its source fixture: " + tavern_fixture_id)
		if location_id == "hollowmere_general_store":
			_check(_has_object(hollowmere_building_result.get("tile_objects", []), "hollowmere_general_store_counter"), "General store must retain its source counter")

	var reddale_registry := REGISTRY.new()
	var reddale_entrances := {
		"reddale_guardhouse": Vector2i(137, 24),
		"reddale_guildhouse": Vector2i(143, 34),
		"reddale_inn": Vector2i(138, 28),
		"reddale_manor": Vector2i(143, 14),
		"reddale_reeve_house": Vector2i(138, 20),
		"reddale_smithy": Vector2i(137, 32)
	}
	var reddale_expected_fixtures := {
		"reddale_guardhouse": ["guardhouse_fireplace"],
		"reddale_guildhouse": ["guildhouse_fireplace", "guildhouse_table", "guildhouse_ledgers"],
		"reddale_inn": ["inn_fireplace"],
		"reddale_manor": ["manor_fireplace", "manor_table", "baron_tariff_records"],
		"reddale_reeve_house": [],
		"reddale_smithy": ["smithy_fireplace", "smithy_bed"]
	}
	for location_id in reddale_entrances:
		var reddale_definition: Dictionary = reddale_registry.get_definition(location_id)
		var reddale_state = LOCATION_STATE.new()
		_check(bool(reddale_state.configure(reddale_definition).get("ok", false)), "Reddale location state must configure: " + location_id)
		var reddale_result: Dictionary = FLOOR_BUILDER.build_floor_map(reddale_definition, 0, reddale_state)
		_check(bool(reddale_result.get("ok", false)), "Reddale interior floor must build: " + location_id)
		if not bool(reddale_result.get("ok", false)):
			continue
		var reddale_map: HexMapData = reddale_result.get("map_data") as HexMapData
		_check(reddale_map.is_walkable(reddale_entrances[location_id]), "Reddale entrance must be walkable: " + location_id)
		for fixture_id in reddale_expected_fixtures[location_id]:
			_check(_has_object(reddale_result.get("tile_objects", []), fixture_id), "Reddale source fixture must be presented: " + fixture_id)
		for reddale_object in reddale_result.get("tile_objects", []):
			var reddale_position: Dictionary = reddale_object.get("position", {})
			var reddale_hex := Vector2i(int(reddale_position.get("q", 0)), int(reddale_position.get("r", 0)))
			_check(reddale_map.is_walkable(reddale_hex), "Reddale fixture must sit on walkable floor: " + String(reddale_object.get("id", "")))

	if failures > 0:
		push_error("%d multi-story floor map test(s) failed." % failures)
		quit(1)
		return
	print("Kragmoor source-authored floor maps validated.")
	quit(0)

func _has_walkable_path(map_data: HexMapData, start: Vector2i, goal: Vector2i) -> bool:
	if map_data == null or not map_data.is_walkable(start) or not map_data.is_walkable(goal):
		return false
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			return true
		for neighbour in HexGrid.neighbors(current):
			if visited.has(neighbour) or not map_data.is_walkable(neighbour):
				continue
			visited[neighbour] = true
			queue.append(neighbour)
	return false

func _has_object(objects: Array, object_id: String) -> bool:
	for object in objects:
		if object is Dictionary and String(object.get("id", "")) == object_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
