extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const BUILDING_FACTORY = preload("res://scripts/world/world_building_factory.gd")
const CHARACTER_REGISTRY = preload("res://scripts/world/campaign2_character_definition_registry.gd")
var failures: int = 0

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	var entries: Array = terrain.settlement_layouts
	_check(entries.size() == 8, "Canonical registry should expose Hollowmere, Silverhart, Millbrook, Emberlode, Reddale, Old Mac's Farmstead and both greenskin sites")
	var millbrook_entry := _entry_by_id(entries, "millbrook")
	_check(not millbrook_entry.is_empty(), "Canonical Millbrook definition must be available")
	if millbrook_entry.is_empty():
		quit(1)
		return
	var definition: Dictionary = millbrook_entry.get("definition", {})
	var layout: Dictionary = definition.get("layout", {})
	var origin: Vector2i = millbrook_entry.get("origin", Vector2i.ZERO)
	_check(origin == Vector2i.ZERO, "Millbrook origin must preserve its existing global axial coordinates")
	_check(String(definition.get("presentation", {}).get("mode", "")) == "chunked", "Millbrook must be owned by the streamed chunk presenter")
	_check(String(definition.get("id", "")) == "millbrook", "Settlement ID must remain stable")
	_assert_axial(definition.get("origin", {}), Vector2i.ZERO, "Millbrook origin")

	var buildings: Array = layout.get("buildings", [])
	_check(buildings.size() == 1, "Millbrook should retain its single source-authored house")
	if not buildings.is_empty():
		var house: Dictionary = buildings[0]
		_assert_axial(house.get("center", {}), Vector2i(1, -366), "Millbrook house centre")
		_check(int(house.get("half_q", 0)) == 3 and int(house.get("half_r", 0)) == 3, "House footprint must remain 7x7 axial cells")
		_assert_axial(house.get("door", {}), Vector2i(4, -366), "Millbrook house door")
		_check(house.get("features", []).has("fireplace"), "Millbrook house must retain its fireplace")

	var paths: Array = layout.get("paths", [])
	_check(paths.size() == 1, "Millbrook should retain its authored house spur")
	if not paths.is_empty():
		_assert_axial(paths[0].get("from", {}), Vector2i(5, -366), "Millbrook path start")
		_assert_axial(paths[0].get("to", {}), Vector2i(6, -366), "Millbrook path end")

	var placements: Dictionary = definition.get("placements", {})
	var characters: Array = placements.get("characters", [])
	_check(characters.size() == 2, "Millbrook should retain Petra and the quartermaster as placements")
	var character_ids: Dictionary = {}
	for placement in characters:
		character_ids[String(placement.get("character_id", ""))] = placement
	_check(character_ids.has("petra_hollis"), "Petra Hollis placement must be present")
	_check(character_ids.has("border_war_quartermaster"), "Quartermaster Rurik Voss placement must be present")
	if character_ids.has("petra_hollis"):
		_assert_axial(character_ids["petra_hollis"].get("position", {}), Vector2i(2, -366), "Petra's source position")
	if character_ids.has("border_war_quartermaster"):
		_assert_axial(character_ids["border_war_quartermaster"].get("position", {}), Vector2i(5, -366), "Quartermaster's source position")
	_check(not characters.is_empty() and not characters[0].has("appearance"), "Settlement placements must not duplicate character appearance")
	_check(not characters.is_empty() and not characters[0].has("dialogue_id"), "Settlement placements must not own dialogue identity")

	_check(terrain.terrain_for_hex(Vector2i(1, -366)) == "authored", "Millbrook's building footprint must not receive procedural terrain")
	_check(terrain.gameplay_terrain_for_hex(Vector2i(1, -366)) == "building", "Millbrook building footprint must be blocked gameplay terrain")
	_check(terrain.terrain_for_hex(Vector2i(5, -366)) == "path", "Millbrook's door spur must be rendered as a path")
	_check(terrain.settlement_building_cells.has("1,-366"), "Canonical building occupancy must be indexed")
	_check(terrain.settlement_path_cells.has("5,-366"), "Canonical path occupancy must be indexed")

	_test_emberlode(terrain, entries)
	_test_reddale(terrain, entries)
	_test_silverhart(terrain, entries)
	_test_old_mac_farmstead(terrain, entries)
	_test_skarn_tooth_camp(terrain, entries)
	_test_skarnaks_hold(terrain, entries)

	var hollowmere_entry := _entry_by_id(entries, "hollowmere")
	_check(not hollowmere_entry.is_empty(), "Canonical Hollowmere definition must remain available")
	if not hollowmere_entry.is_empty():
		var hollowmere: Dictionary = hollowmere_entry.get("definition", {})
		_check(String(hollowmere.get("presentation", {}).get("mode", "")) == "location_presenter", "Hollowmere must remain owned by its location presenter")
		_check(hollowmere.get("layout", {}).get("buildings", []).size() > 0, "Hollowmere authored buildings must survive adaptation")
		_check(hollowmere.get("placements", {}).get("characters", []).size() >= 10, "Hollowmere authored character placements must survive adaptation")
		_check(_find_record(hollowmere.get("placements", {}).get("characters", []), "reyna_fletcher").is_empty(), "Reyna must not remain duplicated in Hollowmere after moving to the farmstead")

	if failures > 0:
		push_error("%d canonical settlement layout test(s) failed." % failures)
		quit(1)
		return
	print("Canonical Campaign 2 settlement layout tests passed.")
	quit(0)


func _test_emberlode(terrain: Campaign2WorldTerrainData, entries: Array) -> void:
	var entry := _entry_by_id(entries, "emberlode")
	_check(not entry.is_empty(), "Canonical Emberlode definition must be available")
	if entry.is_empty():
		return
	var definition: Dictionary = entry.get("definition", {})
	var layout: Dictionary = definition.get("layout", {})
	_check(layout.get("buildings", []).size() == 3, "Emberlode must retain its foreman's hall, bunkhouse and mine entrance")
	_check(layout.get("paths", []).size() == 2, "Emberlode must retain its two authored mine and bunkhouse approaches")
	_check(definition.get("placements", {}).get("characters", []).size() == 3, "Emberlode must retain Corran, Bettina and Rennik")
	_check(definition.get("interiors", []).size() == 3, "Emberlode must retain all three interior definitions")
	var mine := _find_record(definition.get("interiors", []), "emberlode_mine_interior")
	_check(mine.get("floors", []).size() == 3, "Emberlode mine must retain surface, -1 and -2 floors")
	if mine.get("floors", []).size() == 3:
		_check(String(mine.floors[1].get("objects", [])[0].get("ore_type", "")) == "ore_gold", "Working Vein must retain the gold ore node")
		_check(String(mine.floors[2].get("objects", [])[0].get("ore_type", "")) == "gem_blue", "Old Seam must retain the blue gem node")
		_check(mine.floors[2].get("creatures", []).size() == 2, "Old Seam must retain its two source spiders")
	var actors: Array = definition.get("placements", {}).get("characters", [])
	var ids: Dictionary = {}
	for actor in actors:
		ids[String(actor.get("character_id", ""))] = actor
	_check(ids.has("corran_vale") and ids.has("bettina_marrow") and ids.has("rennik_coalmarrow"), "Emberlode character IDs must remain stable")
	_check(terrain.terrain_for_hex(Vector2i(-256, 22)) == "authored", "Emberlode foreman's hall must suppress procedural terrain")
	_check(terrain.terrain_for_hex(Vector2i(-252, 20)) == "path", "Emberlode mine approach must be indexed as a path")
	var factory = BUILDING_FACTORY
	for building in layout.get("buildings", []):
		_check(factory.supports_definition(building), "Emberlode building archetype must be supported: " + String(building.get("id", "")))

func _test_reddale(terrain: Campaign2WorldTerrainData, entries: Array) -> void:
	var entry := _entry_by_id(entries, "reddale")
	_check(not entry.is_empty(), "Canonical Reddale definition must be available")
	if entry.is_empty():
		return
	var definition: Dictionary = entry.get("definition", {})
	var layout: Dictionary = definition.get("layout", {})
	_check(layout.get("buildings", []).size() == 6, "Reddale must retain its guardhouse, reeve house, inn, guildhouse, manor and smithy")
	_check(layout.get("paths", []).size() == 3, "Reddale must retain its authored road approaches")
	_check(definition.get("placements", {}).get("characters", []).size() == 13, "Reddale must retain its twelve existing NPCs plus Mirabel at the nearby source ruin")
	_check(definition.get("interiors", []).size() == 6, "Reddale must retain all six interior/service records")
	var ids: Dictionary = {}
	for actor in definition.get("placements", {}).get("characters", []):
		ids[String(actor.get("character_id", ""))] = actor
	for required_id in ["captain_ilsa_rennick", "watchman_bram_oswick", "reeve_aldous_finch", "nella_brook", "mira_selk", "mirella_thorn", "petra_voss", "osric_vane", "guild_watchman_corley", "baron_corwin_aldervale", "steward_halvard_greer", "torvald_anvik", "mirabel_quill"]:
		_check(ids.has(required_id), "Reddale must retain source NPC " + required_id)
	if ids.has("mirabel_quill"):
		_assert_axial(ids["mirabel_quill"].get("position", {}), Vector2i(156, 26), "Mirabel source position beside Reddale")
	_check(terrain.terrain_for_hex(Vector2i(134, 24)) == "authored", "Reddale guardhouse must suppress procedural terrain")
	_check(terrain.terrain_for_hex(Vector2i(138, 22)) == "path", "Reddale reeve approach must be indexed as a path")
	var factory = BUILDING_FACTORY
	for building in layout.get("buildings", []):
		_check(factory.supports_definition(building), "Reddale building archetype must be supported: " + String(building.get("id", "")))
	var registry = CHARACTER_REGISTRY.new()
	_check(not registry.get_character("corran_vale").is_empty(), "Emberlode NPC profile must resolve through the character registry")
	_check(not registry.get_character("captain_ilsa_rennick").is_empty(), "Reddale NPC profile must resolve through the character registry")



func _test_silverhart(terrain: Campaign2WorldTerrainData, entries: Array) -> void:
	var entry := _entry_by_id(entries, "silverhart")
	_check(not entry.is_empty(), "Canonical Silverhart definition must be available")
	if entry.is_empty():
		return
	var definition: Dictionary = entry.get("definition", {})
	var layout: Dictionary = definition.get("layout", {})
	var props: Array = layout.get("props", [])
	_check(String(definition.get("presentation", {}).get("mode", "")) == "chunked", "Silverhart must be owned by the streamed chunk presenter")
	var placements: Array = definition.get("placements", {}).get("characters", [])
	_check(placements.size() == 38, "Silverhart must retain its 38 named palace, guard, merchant, diplomatic, residential and guild NPCs")
	var character_registry = CHARACTER_REGISTRY.new()
	var placement_ids: Dictionary = {}
	for placement in placements:
		var character_id := String(placement.get("character_id", ""))
		placement_ids[character_id] = placement
		_check(not character_registry.get_character(character_id).is_empty(), "Silverhart NPC profile must resolve through the character registry: " + character_id)
	for required_id in [
		"queen_seraphine_corrin", "chancellor_merric_vane", "court_wizard_thessaly",
		"wall_guard_brennan", "royal_guard_denna", "ossian_fell", "perrin_vance",
		"mirelle_sondhe", "corvin_ashe", "lady_miriel_corstane", "master_builder_hallis",
		"ambassador_elarion", "ambassador_brokk_stonehammer", "ambassador_cassia_wren",
		"ambassador_toren_aldwyn", "factor_willem_drass", "high_cleric_adelram",
		"hollis_vane", "sergeant_bell", "nix_the_cutpurse", "osric_fenn", "greta_aldwyn", "tomlin_reed",
		"tessa_nightshade", "corvin_ashe_guildmaster", "marsh_dobbins", "silas_crane"
	]:
		_check(placement_ids.has(required_id), "Silverhart must preserve source NPC placement " + required_id)
	_check(layout.get("buildings", []).size() == 40, "Silverhart must include palace, merchant, noble, diplomatic, commons, middle-ring and Warrens buildings")
	for building_id in [
		"silverhart_stables", "silverhart_general_goods", "silverhart_clothier", "silverhart_magic_shop",
		"silverhart_corstane_manor", "silverhart_builder_house", "silverhart_neighbor_house",
		"silverhart_north_cottage_1", "silverhart_north_cottage_2", "silverhart_north_cottage_3",
		"silverhart_east_house_1", "silverhart_east_house_2", "silverhart_east_house_3", "silverhart_east_house_4",
		"silverhart_elven_embassy", "silverhart_dwarven_embassy", "silverhart_aldenreach_embassy",
		"silverhart_corvane_embassy", "silverhart_ironbond_office", "silverhart_grand_cathedral",
		"silverhart_commons_inn", "silverhart_outlying_house_1", "silverhart_outlying_house_2", "silverhart_outlying_house_3"
	]:
		var district_building := _find_record(layout.get("buildings", []), building_id)
		_check(not district_building.is_empty(), "Silverhart source district building must be present: " + building_id)
		if not district_building.is_empty():
			_check(BUILDING_FACTORY.supports_definition(district_building), "Silverhart district building archetype must be supported: " + building_id)

	var outlying_house_specs := {
		"silverhart_outlying_house_1": {"centre": Vector2i(63, -546), "door": Vector2i(63, -544)},
		"silverhart_outlying_house_2": {"centre": Vector2i(88, -546), "door": Vector2i(88, -544)},
		"silverhart_outlying_house_3": {"centre": Vector2i(20, -476), "door": Vector2i(22, -476)}
	}
	for building_id in outlying_house_specs:
		var outlying: Dictionary = _find_record(layout.get("buildings", []), building_id)
		_assert_axial(outlying.get("center", {}), outlying_house_specs[building_id]["centre"], building_id + " source centre")
		_assert_axial(outlying.get("door", {}), outlying_house_specs[building_id]["door"], building_id + " source door")
	for road_id in [
		"silverhart_merchant_near_street", "silverhart_merchant_far_street", "silverhart_merchant_cross_alley",
		"silverhart_noble_near_street", "silverhart_noble_far_street", "silverhart_noble_cross_alley",
		"silverhart_diplomatic_main_road", "silverhart_elven_embassy_approach", "silverhart_dwarven_embassy_approach",
		"silverhart_aldenreach_embassy_approach", "silverhart_corvane_embassy_approach",
		"silverhart_ironbond_approach", "silverhart_cathedral_approach"
	]:
		_check(not _find_record(layout.get("paths", []), road_id).is_empty(), "Silverhart district street must be present: " + road_id)
	_check(layout.get("paths", []).size() == 33, "Silverhart must retain palace routes and both quarter street grids")
	for route in layout.get("paths", []):
		if route.get("points") is Array:
			_check(route.get("widths", []).size() == route.get("points", []).size(), "Every Silverhart polyline must define a width at each control point: " + String(route.get("id", "")))
	for building_id in [
		"silverhart_middle_ring_house_1", "silverhart_middle_ring_house_2", "silverhart_middle_ring_house_3",
		"silverhart_middle_ring_house_4", "silverhart_middle_ring_house_5", "silverhart_middle_ring_house_6",
		"silverhart_warrens_shack_1", "silverhart_warrens_shack_2", "silverhart_warrens_shack_3",
		"silverhart_thieves_guild", "silverhart_thieves_guild_vault"
	]:
		var outer_building := _find_record(layout.get("buildings", []), building_id)
		_check(not outer_building.is_empty(), "Silverhart outer-city building must be present: " + building_id)
		if not outer_building.is_empty():
			_check(BUILDING_FACTORY.supports_definition(outer_building), "Silverhart outer-city building archetype must be supported: " + building_id)
	for road_id in [
		"silverhart_middle_ring_road", "silverhart_middle_ring_south_connector",
		"silverhart_middle_ring_house_spur_1", "silverhart_middle_ring_house_spur_2",
		"silverhart_middle_ring_house_spur_3", "silverhart_middle_ring_house_spur_4",
		"silverhart_middle_ring_house_spur_5", "silverhart_middle_ring_house_spur_6",
		"silverhart_city_gate_approach", "silverhart_warrens_approach"
	]:
		_check(not _find_record(layout.get("paths", []), road_id).is_empty(), "Silverhart outer-city route must be present: " + road_id)
	var middle_road := _find_record(layout.get("paths", []), "silverhart_middle_ring_road")
	var middle_points: Array = middle_road.get("points", [])
	_check(middle_points.size() == 7, "Middle ring must retain its six source corners and closure")
	if middle_points.size() == 7:
		_assert_axial(middle_points[0], Vector2i(53, -496), "Middle ring east corner")
		_assert_axial(middle_points[2], Vector2i(8, -541), "Middle ring north corner")
		_assert_axial(middle_points[4], Vector2i(-37, -451), "Middle ring south-west corner")

	var market_table := _find_record(props, "silverhart_commons_market_table")
	_check(not market_table.is_empty(), "Silverhart Commons market square must retain the source table at (8,-521)")
	if not market_table.is_empty():
		_assert_axial(market_table.get("anchor", {}), Vector2i(8, -521), "Silverhart Commons market table")
		_check(market_table.get("parts", []).size() == 5, "Market table must retain its tabletop and four legs")
	var city_wall_cells := 0
	var city_towers := 0
	for prop in props:
		var prop_id := String(prop.get("id", ""))
		if prop_id.begins_with("silverhart_city_wall_watchtower_"):
			city_towers += 1
		elif prop_id.begins_with("silverhart_city_wall_"):
			city_wall_cells += 1
	_check(city_wall_cells == 357, "Outer city wall must preserve all 360 radius-60 cells except the three-cell south gate")
	_check(city_towers == 2, "Outer city wall must include both source gate watchtowers")
	var guild_vault := _find_record(layout.get("buildings", []), "silverhart_thieves_guild_vault")
	_check(guild_vault.get("door_enabled", true) == false, "The guild vault must not expose a normal visible entrance")
	var vault_interior := _find_record(definition.get("interiors", []), "silverhart_thieves_guild_vault_interior")
	_check(not vault_interior.is_empty(), "Silverhart must retain the hidden guild vault interior definition")
	if not vault_interior.is_empty():
		_assert_axial(vault_interior.get("secret_entry", {}), Vector2i(19, -426), "Hidden guild vault secret door")
		var vault_objects: Array = vault_interior.get("objects", [])
		_check(vault_objects.size() == 1 and String(vault_objects[0].get("type", "")) == "storage_chest", "Hidden guild vault must retain its source treasure chest")
	_check(not _find_record(props, "silverhart_city_gate_arch").is_empty(), "Outer city gate arch must be presented")
	_check(terrain.terrain_for_hex(Vector2i(8, -541)) == "path", "Middle ring road must be indexed at its north corner")
	_check(terrain.terrain_for_hex(Vector2i(-35, -454)) == "path", "Middle-ring diagonal house spur must include its first cube-rounded intermediate hex")
	_check(terrain.terrain_for_hex(Vector2i(-36, -452)) == "path", "Middle-ring diagonal house spur must remain continuous to the ring")
	_check(terrain.terrain_for_hex(Vector2i(8, -436)) == "path", "Outer city gate approach must reach the three-cell gate")
	_check(not _find_record(layout.get("paths", []), "silverhart_city_gate_span").is_empty(), "The three-cell outer gate must be represented by its own crossing route")
	for gate_cell in [Vector2i(8, -436), Vector2i(7, -436), Vector2i(6, -436)]:
		_check(terrain.terrain_for_hex(gate_cell) == "path", "Every source outer gate cell must be traversable path: " + str(gate_cell))
	for warrens_node in [Vector2i(2, -430), Vector2i(5, -430), Vector2i(11, -430)]:
		_check(terrain.terrain_for_hex(warrens_node) == "path", "Source Warrens road node must remain paved at " + str(warrens_node))
	_check(terrain.settlement_wall_cells.size() == 495, "Both Silverhart palisade rings must be indexed for gameplay traversal")
	_check(terrain.settlement_ladder_cells.size() == 2, "The two inner-wall ladders must be registered as climbable crossings")
	_check(terrain.terrain_for_hex(Vector2i(8, -473)) == "palisade_wall", "Inner curtain wall must be exposed as palisade terrain")
	_check(terrain.is_walkable_for_hex(Vector2i(8, -473)), "Palisade walls must remain traversable at a high movement cost, as in the source game")
	_check(terrain.movement_multiplier_for_hex(Vector2i(8, -473)) == 15.0, "Unassisted palisade crossing must carry the source high movement cost")
	_check(terrain.is_walkable_for_hex(Vector2i(20, -519)), "Authored ladder cells must allow wall crossing")
	_check(terrain.movement_multiplier_for_hex(Vector2i(20, -519)) == 2.0, "A ladder must reduce its palisade crossing to the source low movement cost")
	_check(terrain.terrain_for_hex(Vector2i(68, -496)) == "palisade_wall", "Outer city wall must be exposed as palisade terrain")
	_check(terrain.is_walkable_for_hex(Vector2i(68, -496)), "Outer city palisade must remain climbable at a high movement cost")
	_check(terrain.movement_multiplier_for_hex(Vector2i(68, -496)) == 15.0, "Outer city palisade must retain its high movement cost")
	var expected_centres := {
		"silverhart_grand_hall": Vector2i(8, -496),
		"silverhart_barracks": Vector2i(22, -494),
		"silverhart_council_chamber": Vector2i(-6, -494),
		"silverhart_royal_wizard_tower": Vector2i(-7, -482),
		"silverhart_queens_bedroom": Vector2i(8, -505)
	}
	for building_id in expected_centres:
		var building := _find_record(layout.get("buildings", []), building_id)
		_check(not building.is_empty(), "Silverhart source palace building must be present: " + building_id)
		if not building.is_empty():
			_assert_axial(building.get("center", {}), expected_centres[building_id], building_id + " source centre")
			_check(BUILDING_FACTORY.supports_definition(building), "Silverhart building archetype must be supported: " + building_id)
	var barracks_route := _find_record(layout.get("paths", []), "silverhart_barracks_courtyard")
	var barracks_points: Array = barracks_route.get("points", [])
	_check(barracks_points.size() == 3, "Barracks spur must preserve the source L-shaped courtyard route")
	if barracks_points.size() == 3:
		_assert_axial(barracks_points[0], Vector2i(9, -487), "Barracks spur courtyard start")
		_assert_axial(barracks_points[1], Vector2i(17, -487), "Barracks spur east-west leg")
		_assert_axial(barracks_points[2], Vector2i(17, -494), "Barracks spur barracks approach")
	var council_route := _find_record(layout.get("paths", []), "silverhart_council_courtyard")
	var council_points: Array = council_route.get("points", [])
	_check(council_points.size() == 3, "Council spur must preserve the source L-shaped courtyard route")
	if council_points.size() == 3:
		_assert_axial(council_points[0], Vector2i(-1, -494), "Council spur chamber approach")
		_assert_axial(council_points[1], Vector2i(-1, -487), "Council spur north-south leg")
		_assert_axial(council_points[2], Vector2i(7, -487), "Council spur courtyard end")
	_check(terrain.terrain_for_hex(Vector2i(8, -496)) == "authored", "Silverhart Grand Hall footprint must suppress procedural terrain")
	_check(terrain.terrain_for_hex(Vector2i(8, -495)) == "path", "Silverhart palace approach must be indexed as authored path")
	_check(terrain.terrain_for_hex(Vector2i(9, -487)) == "path", "Silverhart courtyard must be indexed from source route geometry")
	_check(terrain.terrain_for_hex(Vector2i(17, -494)) == "path", "Silverhart barracks door spur must reach its source door")
	var ring_road := _find_record(layout.get("paths", []), "silverhart_outer_ring_road")
	var ring_points: Array = ring_road.get("points", [])
	_check(ring_points.size() == 7, "Silverhart outer ring road must preserve the six source hex-ring corners and closure")
	if ring_points.size() == 7:
		_assert_axial(ring_points[0], Vector2i(38, -496), "Outer ring east corner")
		_assert_axial(ring_points[1], Vector2i(38, -526), "Outer ring north-east corner")
		_assert_axial(ring_points[2], Vector2i(8, -526), "Outer ring north corner")
		_assert_axial(ring_points[3], Vector2i(-22, -496), "Outer ring west corner")
		_assert_axial(ring_points[4], Vector2i(-22, -466), "Outer ring south-west corner")
		_assert_axial(ring_points[5], Vector2i(8, -466), "Outer ring south corner")
		_assert_axial(ring_points[6], Vector2i(38, -496), "Outer ring closure")
	for ring_corner in [Vector2i(38, -496), Vector2i(38, -526), Vector2i(8, -526), Vector2i(-22, -496), Vector2i(-22, -466), Vector2i(8, -466)]:
		_check(terrain.terrain_for_hex(ring_corner) == "path", "Silverhart source outer ring road must be indexed at " + str(ring_corner))
	_check(terrain.terrain_for_hex(Vector2i(8, -472)) == "path", "Silverhart gate exterior road must meet the southern ring-road corner")
	_check(props.size() == 513, "Silverhart must include both palisade rings, nine watchtowers, two ladders, two gate arches, one plaza fountain, bounty board and Commons market table")
	var wall_cells := 0
	var tower_ids: Array[String] = []
	var ladder_ids: Array[String] = []
	for prop in props:
		var prop_id := String(prop.get("id", ""))
		if prop_id.begins_with("silverhart_curtain_wall_"):
			wall_cells += 1
		elif prop_id.begins_with("silverhart_watchtower_"):
			tower_ids.append(prop_id)
		elif prop_id.begins_with("silverhart_wall_ladder_"):
			ladder_ids.append(prop_id)
	_check(wall_cells == 138, "Curtain wall must follow every radius-23 source hex")
	_check(tower_ids.size() == 7, "All seven source watchtower positions must be represented")
	_check(ladder_ids.size() == 2, "Both source ladder access points must be represented")
	for tower in [
		Vector2i(10, -475), Vector2i(6, -473), Vector2i(31, -496),
		Vector2i(-15, -496), Vector2i(8, -519), Vector2i(31, -519), Vector2i(-15, -473)
	]:
		var found := false
		for prop in props:
			if String(prop.get("id", "")).begins_with("silverhart_watchtower_") and prop.get("anchor") == tower:
				found = true
		_check(found, "Silverhart source watchtower must be positioned at " + str(tower))
	for ladder in [Vector2i(20, -519), Vector2i(-4, -507)]:
		var found := false
		for prop in props:
			if String(prop.get("id", "")).begins_with("silverhart_wall_ladder_") and prop.get("anchor") == ladder:
				found = true
		_check(found, "Silverhart source ladder must be positioned at " + str(ladder))


func _test_old_mac_farmstead(terrain: Campaign2WorldTerrainData, entries: Array) -> void:
	var entry := _entry_by_id(entries, "old_mac_farmstead")
	_check(not entry.is_empty(), "Canonical Old Mac's Farmstead definition must be available")
	if entry.is_empty():
		return
	var definition: Dictionary = entry.get("definition", {})
	var layout: Dictionary = definition.get("layout", {})
	_check(layout.get("buildings", []).size() == 1, "Old Mac's Farmstead must retain its source farmhouse")
	_check(layout.get("paths", []).size() == 1, "Old Mac's Farmstead must retain its short road spur")
	_check(layout.get("fields", []).size() == 7, "Old Mac's pasture and six fence runs must survive canonical adaptation")
	_check(layout.get("props", []).size() == 8, "The broken fence rail and seven blood-trail marks must be retained as quest props")
	var blood_spatter_ids := [
		"old_mac_blood_spatter_01", "old_mac_blood_spatter_02",
		"old_mac_blood_spatter_03", "old_mac_blood_spatter_04",
		"old_mac_blood_spatter_06", "old_mac_blood_spatter_08",
		"old_mac_blood_spatter_10"
	]
	for index in range(blood_spatter_ids.size()):
		var spatter := _find_record(layout.get("props", []), blood_spatter_ids[index])
		_check(not spatter.is_empty(), "Source blood trail mark must be present: " + blood_spatter_ids[index])
		if not spatter.is_empty():
			var expected_q: int = [-10, -11, -12, -13, -15, -17, -19][index]
			_assert_axial(spatter.get("anchor", {}), Vector2i(expected_q, 194), "Blood trail source step %s" % blood_spatter_ids[index])
			var expected_visibility := "obvious" if index < 4 else "knowledge_nature"
			_check(String(spatter.get("evidence_visibility", "")) == expected_visibility, "Blood trail evidence visibility must preserve source progression")
	var farmhouse := _find_record(layout.get("buildings", []), "old_mac_farmhouse")
	_assert_axial(farmhouse.get("center", {}), Vector2i(0, 194), "Old Mac farmhouse centre")
	_assert_axial(farmhouse.get("door", {}), Vector2i(3, 194), "Old Mac farmhouse door")
	var farmstead_characters: Array = definition.get("placements", {}).get("characters", [])
	var actor := _find_record(farmstead_characters, "old_mac")
	_assert_axial(actor.get("position", {}), Vector2i(1, 194), "Old Mac source placement")
	_check(farmstead_characters.size() == 2, "Old Mac and Reyna must be the two source-authored farmstead character placements")
	var reyna_actor := _find_record(farmstead_characters, "reyna_fletcher")
	_assert_axial(reyna_actor.get("position", {}), Vector2i(6, 198), "Reyna source placement relative to the farm centre")
	var sheep: Array = definition.get("placements", {}).get("creatures", [])
	_check(sheep.size() == 2, "Old Mac's two source sheep must be retained as creature placements")
	var sheep_a := _find_record(sheep, "OldMacSheepA")
	var sheep_b := _find_record(sheep, "OldMacSheepB")
	_check(String(sheep_a.get("kind", "")) == "sheep" and String(sheep_a.get("dialogue_id", "")) == "farm_sheep", "First sheep must retain its passive sheep profile and dialogue identity")
	_check(String(sheep_b.get("kind", "")) == "sheep" and String(sheep_b.get("dialogue_id", "")) == "farm_sheep", "Second sheep must retain its passive sheep profile and dialogue identity")
	_assert_axial(sheep_a.get("position", {}), Vector2i(-4, 193), "First sheep source position")
	_assert_axial(sheep_b.get("position", {}), Vector2i(-5, 195), "Second sheep source position")
	_check(terrain.terrain_for_hex(Vector2i(0, 194)) == "authored", "Old Mac farmhouse must suppress procedural terrain")
	_check(terrain.terrain_for_hex(Vector2i(4, 194)) == "path", "Old Mac farmhouse spur must be indexed as a path")
	_check(BUILDING_FACTORY.supports_definition(farmhouse), "Old Mac farmhouse must use the shared cottage archetype")
	var npc_registry = CHARACTER_REGISTRY.new()
	_check(String(npc_registry.get_character("old_mac").get("dialogue_id", "")) == "old_mac", "Old Mac identity must resolve from the character catalogue")
	var materials: Dictionary = definition.get("presentation", {}).get("materials", {})
	_check(materials.get("agriculture", {}).has("pasture") and materials.get("agriculture", {}).has("fence"), "Farmstead agriculture must have shared material bindings")
	_check(layout.get("fields", []).size() > 0 and layout.fields[0].get("corners", []).size() == 4, "Pasture boundary must remain a four-corner authored polygon")


func _test_skarn_tooth_camp(terrain: Campaign2WorldTerrainData, entries: Array) -> void:
	var entry := _entry_by_id(entries, "skarn_tooth_camp")
	_check(not entry.is_empty(), "Canonical Skarn-tooth Camp definition must be available")
	if entry.is_empty():
		return
	var definition: Dictionary = entry.get("definition", {})
	var buildings: Array = definition.get("layout", {}).get("buildings", [])
	_check(buildings.size() == 7, "Skarn-tooth Camp must retain its chief hut, five huts and central campfire")
	var expected := {
		"skarn_tooth_chiefs_hut": Vector2i(203, 21),
		"skarn_tooth_hut_nw": Vector2i(200, 22),
		"skarn_tooth_hut_ne": Vector2i(206, 22),
		"skarn_tooth_hut_sw": Vector2i(200, 25),
		"skarn_tooth_hut_se": Vector2i(206, 25),
		"skarn_tooth_hut_south": Vector2i(203, 26),
		"skarn_tooth_campfire": Vector2i(203, 23)
	}
	for building_id in expected:
		var building := _find_record(buildings, building_id)
		_check(not building.is_empty(), "Source goblin camp structure must be present: " + building_id)
		if not building.is_empty():
			_assert_axial(building.get("center", {}), expected[building_id], building_id + " source position")
			_check(BUILDING_FACTORY.supports_definition(building), "Goblin camp structure must use a supported shared archetype: " + building_id)
	_check(terrain.terrain_for_hex(Vector2i(203, 21)) == "authored", "Chief hut footprint must suppress procedural terrain")
	_check(terrain.settlement_building_cells.has("203,21"), "Chief hut occupancy must be indexed by streamed world terrain")
	var props: Array = definition.get("layout", {}).get("props", [])
	_check(props.size() == 1, "Skarn-tooth Camp must retain the source goblin scout journal as a physical map prop")
	var scout_note := _find_record(props, "skarn_tooth_goblin_scout_note")
	_check(not scout_note.is_empty(), "Goblin scout note prop must retain its stable source ID")
	if not scout_note.is_empty():
		_assert_axial(scout_note.get("anchor", {}), Vector2i(204, 21), "Goblin scout note source position beside the chief hut")
		_check(String(scout_note.get("feature_type", "")) == "quest_props", "Goblin scout journal must use the streamed quest-prop presenter")
		_check(scout_note.get("parts", []).size() == 4, "Goblin scout note must render parchment and its three ink lines")
		_check(String(scout_note.get("source", "")).contains("goblin_scout_note"), "Goblin scout note must retain source journal identity")
	_check(String(definition.get("source", "")).contains("buildGoblinCamp"), "Goblin camp must retain source traceability")
	var placements: Array = definition.get("placements", {}).get("characters", [])
	_check(placements.size() == 8, "Skarn-tooth Camp should populate its chief, lieutenant, shaman, trader and three guards")
	var ids: Dictionary = {}
	for placement in placements:
		ids[String(placement.get("character_id", ""))] = placement
	var registry := CHARACTER_REGISTRY.new()
	var expected_npcs := {
		"chief_skarnub": Vector2i(203, 22),
		"nix_sharpear": Vector2i(202, 23),
		"gralk_bonecaster": Vector2i(204, 23),
		"grondle_camp_trader": Vector2i(202, 24),
		"skarn_goblin_guard_01": Vector2i(203, 24),
		"skarn_goblin_guard_02": Vector2i(204, 24),
		"skarn_goblin_skulker": Vector2i(203, 25),
		"ser_aldric_thorne": Vector2i(204, 22)
	}
	for character_id in expected_npcs:
		_check(ids.has(character_id), "Skarn-tooth Camp should place " + character_id)
		if ids.has(character_id):
			_assert_axial(ids[character_id].get("position", {}), expected_npcs[character_id], character_id + " source position")
		var profile := registry.get_character(character_id)
		_check(not profile.is_empty(), "Skarn-tooth NPC profile should resolve: " + character_id)
		if not profile.is_empty():
			_check(profile.has("source_position"), "Skarn-tooth NPC should retain its original source placement: " + character_id)
	_check(String(registry.get_character("chief_skarnub").get("dialogue_id", "")) == "chief_skarnub", "Chief Skarnub should retain his source dialogue ID")
	_check(String(registry.get_character("nix_sharpear").get("dialogue_id", "")) == "nix_sharpear", "Nix Sharpear should retain his source dialogue ID")
	var aldric_profile := registry.get_character("ser_aldric_thorne")
	_check(String(aldric_profile.get("dialogue_id", "")) == "ser_aldric_captive", "Ser Aldric should retain his captive dialogue ID")
	_check(bool(aldric_profile.get("tied_up", false)), "Ser Aldric should enter the camp as a captive")


func _test_skarnaks_hold(terrain: Campaign2WorldTerrainData, entries: Array) -> void:
	var entry := _entry_by_id(entries, "skarnaks_hold")
	_check(not entry.is_empty(), "Canonical Skarnak's Hold definition must be available")
	if entry.is_empty():
		return
	var definition: Dictionary = entry.get("definition", {})
	var buildings: Array = definition.get("layout", {}).get("buildings", [])
	_check(buildings.size() == 9, "Skarnak's Hold must retain its warlord hut, seven huts and central fire")
	var expected := {
		"skarnaks_warlord_hut": Vector2i(428, 14),
		"skarnaks_hut_west_north": Vector2i(424, 16),
		"skarnaks_hut_east_north": Vector2i(432, 16),
		"skarnaks_hut_west_south": Vector2i(424, 19),
		"skarnaks_hut_east_south": Vector2i(432, 19),
		"skarnaks_hut_south": Vector2i(428, 20),
		"skarnaks_hut_southwest": Vector2i(426, 20),
		"skarnaks_hut_northeast": Vector2i(430, 14),
		"skarnaks_central_fire": Vector2i(428, 17)
	}
	for building_id in expected:
		var building := _find_record(buildings, building_id)
		_check(not building.is_empty(), "Source orc stronghold structure must be present: " + building_id)
		if not building.is_empty():
			_assert_axial(building.get("center", {}), expected[building_id], building_id + " source position")
			_check(BUILDING_FACTORY.supports_definition(building), "Orc stronghold structure must use a supported shared archetype: " + building_id)
	_check(terrain.terrain_for_hex(Vector2i(428, 14)) == "authored", "Warlord hut must occupy its clearing footprint")
	_check(terrain.terrain_for_hex(Vector2i(420, 17)) == "path", "Stronghold west gate must connect to the authored road approach")
	_check(terrain.terrain_for_hex(Vector2i(436, 17)) == "climbable_wall", "Orc stronghold perimeter must remain a climbable wall")
	_check(String(definition.get("source", "")).contains("buildOrcStronghold"), "Orc stronghold must retain source traceability")
	var placements: Array = definition.get("placements", {}).get("characters", [])
	_check(placements.size() == 6, "Skarnak's Hold should populate its warlord, trader and four guards")
	var ids: Dictionary = {}
	for placement in placements:
		ids[String(placement.get("character_id", ""))] = placement
	var registry := CHARACTER_REGISTRY.new()
	var expected_npcs := {
		"warlord_grukk_ironhide": Vector2i(428, 15),
		"kesh_stronghold_trader": Vector2i(427, 19),
		"skarnak_orc_guard_01": Vector2i(425, 18),
		"skarnak_orc_guard_02": Vector2i(431, 18),
		"skarnak_orc_skirmisher": Vector2i(425, 19),
		"skarnak_orc_guard_04": Vector2i(431, 19)
	}
	for character_id in expected_npcs:
		_check(ids.has(character_id), "Skarnak's Hold should place " + character_id)
		if ids.has(character_id):
			_assert_axial(ids[character_id].get("position", {}), expected_npcs[character_id], character_id + " source position")
		var profile := registry.get_character(character_id)
		_check(not profile.is_empty(), "Skarnak's Hold NPC profile should resolve: " + character_id)
	_check(String(registry.get_character("warlord_grukk_ironhide").get("dialogue_id", "")) == "orc_warlord", "Grukk should retain his source dialogue ID")
	_check(String(registry.get_character("kesh_stronghold_trader").get("dialogue_id", "")) == "orc_trader", "Kesh should retain his source dialogue ID")

func _entry_by_id(entries: Array, settlement_id: String) -> Dictionary:
	for entry in entries:
		if String(entry.get("id", "")) == settlement_id:
			return entry
	return {}

func _assert_axial(value: Variant, expected: Vector2i, label: String) -> void:
	if value is Vector2i:
		_check(value == expected, "%s should be %s, got %s" % [label, expected, value])
	elif value is Dictionary:
		var actual := Vector2i(int(value.get("q", 999999)), int(value.get("r", 999999)))
		_check(actual == expected, "%s should be %s, got %s" % [label, expected, actual])
	else:
		_check(false, "%s must be an axial coordinate" % label)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _find_record(records: Array, record_id: String) -> Dictionary:
	for record in records:
		if not record is Dictionary:
			continue
		for key in ["id", "character_id", "building_id"]:
			if String(record.get(key, "")) == record_id:
				return record
	return {}
