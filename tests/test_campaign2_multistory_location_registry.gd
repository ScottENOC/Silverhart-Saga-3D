extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
var failures: int = 0

func _initialize() -> void:
	var registry = REGISTRY.new()
	_check(registry.validation_errors.is_empty(), "Source-authored multi-story locations must validate")
	var invalid_row_shift_registry = REGISTRY.new()
	var invalid_row_shift_result: Dictionary = invalid_row_shift_registry.configure({
		"schema_version": 1,
		"coordinate_system": "campaign2_local_axial_qr",
		"locations": [{
			"id": "invalid_row_shift_test",
			"anchor": {"q": 0, "r": 0},
			"floors": [{
				"floor": 0,
				"rooms": [{"center": {"q": 0, "r": 0}, "half_width": 2, "half_height": 2, "row_shift_mode": "unknown"}],
				"corridors": [],
				"tile_objects": [],
				"actors": [],
				"creatures": []
			}],
			"transitions": []
		}]
	})
	_check(not bool(invalid_row_shift_result.get("ok", true)), "Registry must reject unknown source room row-shift modes")
	_check(registry.location_ids() == ["abandoned_house","corvin_ashgrave_barrow","emberlode_bunkhouse","emberlode_foremans_hall","emberlode_mine","hollowmere_chapel","hollowmere_general_store","hollowmere_guild_den","hollowmere_house","hollowmere_store","hollowmere_tavern","kragmoor","lich_chapterhouse","millbrook_house","mira_house","northwatch_keep","old_mac_farmhouse","oskar_house","reddale_guardhouse","reddale_guildhouse","reddale_inn","reddale_manor","reddale_reeve_house","reddale_smithy","ridgehold_keep","silthandriel","silverhart_aldenreach_embassy","silverhart_builder_house","silverhart_city_tunnel","silverhart_clothier","silverhart_commons_inn","silverhart_corstane_manor","silverhart_corvane_embassy","silverhart_dwarven_embassy","silverhart_east_house_four","silverhart_east_house_one","silverhart_east_house_three","silverhart_east_house_two","silverhart_elven_embassy","silverhart_general_goods","silverhart_grand_cathedral","silverhart_ironbond_office","silverhart_magic_shop","silverhart_middle_ring_house_east","silverhart_middle_ring_house_north","silverhart_middle_ring_house_northeast","silverhart_middle_ring_house_southeast","silverhart_middle_ring_house_southwest","silverhart_middle_ring_house_west","silverhart_noble_neighbor_house","silverhart_north_cottage_one","silverhart_north_cottage_three","silverhart_north_cottage_two","silverhart_outlying_house_east","silverhart_outlying_house_far_east","silverhart_outlying_house_west","silverhart_palace","silverhart_palace_barracks","silverhart_palace_council_chamber","silverhart_palace_tunnel","silverhart_palace_wizard_tower","silverhart_stables","silverhart_thieves_guild","silverhart_warrens_shack_centre","silverhart_warrens_shack_east","silverhart_warrens_shack_west","thieves_cove","vessel_seekers_crypt"], "Kragmoor and all source-authored interiors must be registered")
	var emberlode_centres := {
		"emberlode_bunkhouse": Vector2i(-252, 28),
		"emberlode_foremans_hall": Vector2i(-256, 22)
	}
	for location_id in emberlode_centres:
		var emberlode_location: Dictionary = registry.get_definition(location_id)
		var emberlode_anchor: Dictionary = emberlode_location.get("anchor", {})
		var expected_centre: Vector2i = emberlode_centres[location_id]
		_check(int(emberlode_anchor.get("q", 0)) == expected_centre.x and int(emberlode_anchor.get("r", 0)) == expected_centre.y, "Emberlode building anchor must match buildEmberlode: " + location_id)
		var emberlode_floor := registry.get_floor_definition(location_id, 0)
		_check(emberlode_floor.get("rooms", []).size() == 1, "Emberlode building must retain one source room: " + location_id)
		var emberlode_room: Dictionary = emberlode_floor.get("rooms", [])[0]
		_check(int(emberlode_room.get("half_width", 0)) == 3 and int(emberlode_room.get("half_height", 0)) == 2, "Emberlode building footprint must match carveBuilding: " + location_id)
		_check(String(emberlode_room.get("row_shift_mode", "")) == "source_building", "Emberlode building must preserve carveBuilding row shift: " + location_id)
		_check(_has_record(emberlode_floor.get("tile_objects", []), location_id + ("_north_door" if location_id == "emberlode_bunkhouse" else "_east_door")), "Emberlode building must retain its source entrance: " + location_id)

	var hollowmere_centres := {
		"hollowmere_chapel": Vector2i(-14, 0),
		"hollowmere_general_store": Vector2i(0, 18),
		"hollowmere_house": Vector2i(0, -12),
		"hollowmere_store": Vector2i(14, 0),
		"hollowmere_tavern": Vector2i(0, 0),
		"mira_house": Vector2i(12, 9),
		"oskar_house": Vector2i(-6, 9)
	}
	var hollowmere_doors := {
		"hollowmere_chapel": "hollowmere_chapel_east_door",
		"hollowmere_general_store": "hollowmere_general_store_north_door",
		"hollowmere_house": "hollowmere_house_south_door",
		"hollowmere_store": "hollowmere_store_west_door",
		"hollowmere_tavern": "hollowmere_tavern_south_door",
		"mira_house": "mira_house_west_door",
		"oskar_house": "oskar_house_east_door"
	}
	for location_id in hollowmere_centres:
		var hollowmere_location: Dictionary = registry.get_definition(location_id)
		var hollowmere_anchor: Dictionary = hollowmere_location.get("anchor", {})
		var expected_centre: Vector2i = hollowmere_centres[location_id]
		_check(int(hollowmere_anchor.get("q", 0)) == expected_centre.x and int(hollowmere_anchor.get("r", 0)) == expected_centre.y, "Hollowmere building anchor must match setupVillageScene: " + location_id)
		var hollowmere_floor := registry.get_floor_definition(location_id, 0)
		_check(hollowmere_floor.get("rooms", []).size() == 1, "Hollowmere building must retain one source room: " + location_id)
		_check(_has_record(hollowmere_floor.get("tile_objects", []), hollowmere_doors[location_id]), "Hollowmere building must retain its source entrance: " + location_id)
	var tavern_floor := registry.get_floor_definition("hollowmere_tavern", 0)
	_check(int(tavern_floor.get("rooms", [])[0].get("half_width", 0)) == 6 and int(tavern_floor.get("rooms", [])[0].get("half_height", 0)) == 4, "Tavern floor dimensions must match its source q/r loops")
	_check(bool(_find_record(tavern_floor.get("tile_objects", []), "hollowmere_tavern_south_door").get("locked", false)), "Tavern entrance must preserve its initially locked state")
	_check(_has_record(tavern_floor.get("tile_objects", []), "hollowmere_tavern_fireplace"), "Tavern must retain its source fireplace")
	_check(_has_record(registry.get_floor_definition("hollowmere_general_store", 0).get("tile_objects", []), "hollowmere_general_store_counter"), "General store must retain its source counter")

	var guild_den: Dictionary = registry.get_definition("hollowmere_guild_den")
	_check(int(guild_den.get("anchor", {}).get("q", 0)) == -12 and int(guild_den.get("anchor", {}).get("r", 0)) == -8, "Hollowmere Guild Den anchor must match buildHollowmereGuildDen")
	var guild_den_floor := registry.get_floor_definition("hollowmere_guild_den", 0)
	_check(guild_den_floor.get("rooms", []).size() == 1, "Hollowmere Guild Den must retain its single source-authored room")
	var guild_den_room: Dictionary = guild_den_floor.get("rooms", [])[0]
	_check(int(guild_den_room.get("half_width", 0)) == 2 and int(guild_den_room.get("half_height", 0)) == 2, "Guild Den footprint must match carveBuilding")
	_check(String(guild_den_room.get("row_shift_mode", "")) == "source_building", "Guild Den must preserve carveBuilding's source row shift")
	_check(_has_record(guild_den_floor.get("tile_objects", []), "hollowmere_guild_den_door"), "Guild Den must retain its south entrance")
	_check(guild_den_floor.get("actors", []).is_empty(), "Guild Den map port must not import its campaign-owned contact")

	var millbrook: Dictionary = registry.get_definition("millbrook_house")
	_check(int(millbrook.get("anchor", {}).get("q", 0)) == 1 and int(millbrook.get("anchor", {}).get("r", 0)) == -366, "Millbrook house anchor must match buildMillbrook relative to its north-road waypoint")
	var millbrook_floor := registry.get_floor_definition("millbrook_house", 0)
	_check(millbrook_floor.get("rooms", []).size() == 1, "Millbrook house must retain its single source-authored room")
	var millbrook_room: Dictionary = millbrook_floor.get("rooms", [])[0]
	_check(int(millbrook_room.get("half_width", 0)) == 3 and int(millbrook_room.get("half_height", 0)) == 3, "Millbrook house footprint must match carveFlatRoom")
	_check(_has_record(millbrook_floor.get("tile_objects", []), "millbrook_house_east_door"), "Millbrook house must retain its east entrance")
	_check(_has_record(millbrook_floor.get("tile_objects", []), "millbrook_house_fireplace"), "Millbrook house must retain its source fireplace")

	var farmhouse: Dictionary = registry.get_definition("old_mac_farmhouse")
	_check(int(farmhouse.get("anchor", {}).get("q", 0)) == 0 and int(farmhouse.get("anchor", {}).get("r", 0)) == 194, "Old Mac's farmhouse anchor must match buildFarmstead")
	var farmhouse_floor := registry.get_floor_definition("old_mac_farmhouse", 0)
	_check(farmhouse_floor.get("rooms", []).size() == 1, "Old Mac's farmhouse must retain its source-authored room")
	var farmhouse_room: Dictionary = farmhouse_floor.get("rooms", [])[0]
	_check(int(farmhouse_room.get("half_width", 0)) == 3 and int(farmhouse_room.get("half_height", 0)) == 2, "Farmhouse footprint must match carveBuilding")
	_check(String(farmhouse_room.get("row_shift_mode", "")) == "source_building", "Farmhouse must preserve carveBuilding row shift")
	_check(_has_record(farmhouse_floor.get("tile_objects", []), "old_mac_farmhouse_east_door"), "Farmhouse must retain its source east entrance")

	var reddale_centres := {
		"reddale_guardhouse": Vector2i(134, 24),
		"reddale_guildhouse": Vector2i(146, 34),
		"reddale_inn": Vector2i(138, 30),
		"reddale_manor": Vector2i(146, 14),
		"reddale_reeve_house": Vector2i(138, 18),
		"reddale_smithy": Vector2i(134, 32)
	}
	for location_id in reddale_centres:
		var reddale_location: Dictionary = registry.get_definition(location_id)
		var reddale_anchor: Dictionary = reddale_location.get("anchor", {})
		var expected_centre: Vector2i = reddale_centres[location_id]
		_check(int(reddale_anchor.get("q", 0)) == expected_centre.x and int(reddale_anchor.get("r", 0)) == expected_centre.y, "Reddale building anchor must match buildReddale: " + location_id)
		var reddale_floor := registry.get_floor_definition(location_id, 0)
		_check(reddale_floor.get("rooms", []).size() == 1, "Reddale building must retain one source room: " + location_id)
		var reddale_room: Dictionary = reddale_floor.get("rooms", [])[0]
		_check(int(reddale_room.get("half_width", 0)) == 3 and int(reddale_room.get("half_height", 0)) == 2, "Reddale building footprint must match carveBuilding: " + location_id)
		_check(String(reddale_room.get("row_shift_mode", "")) == "source_building", "Reddale building must preserve carveBuilding row shift: " + location_id)
		_check(_has_record(reddale_floor.get("tile_objects", []), location_id + "_door"), "Reddale building must retain its source entrance: " + location_id)

	var palace: Dictionary = registry.get_definition("silverhart_palace")
	_check(int(palace.get("anchor", {}).get("q", 0)) == 8 and int(palace.get("anchor", {}).get("r", 0)) == -496, "Silverhart Grand Hall anchor must match buildSilverhartPalace")
	_check(palace.get("floors", []).size() == 2, "Silverhart Grand Hall must preserve its two source floors")
	var grand_hall := registry.get_floor_definition("silverhart_palace", 0)
	_check(grand_hall.get("actors", []).size() == 4, "Grand Hall must retain the Queen and three source royal guards")
	_check(_has_record(grand_hall.get("tile_objects", []), "throne"), "Grand Hall must retain its throne")
	var gallery := registry.get_floor_definition("silverhart_palace", 1)
	_check(gallery.get("rooms", []).size() == 1, "Grand Hall gallery must retain its source room")
	_check(palace.get("transitions", []).size() == 2, "Grand Hall and gallery must retain reciprocal source stairs")

	_check(palace.get("floors", [])[0].get("rooms", []).size() == 2, "Grand Hall floor must also contain the source Queen's private chambers")
	_check(palace.get("floors", [])[0].get("corridors", []).size() == 1, "Queen's chambers must connect through the source rear passage")
	var grand_hall_objects: Array = grand_hall.get("tile_objects", [])
	_check(_has_record(grand_hall_objects, "queen_chambers_rear_door"), "Queen's chambers must retain the single rear door")
	_check(_has_record(grand_hall_objects, "queen_chambers_bed"), "Queen's chambers must retain the source bed")
	_check(_has_record(grand_hall_objects, "queen_chambers_fireplace"), "Queen's chambers must retain the source fireplace")

	var council: Dictionary = registry.get_definition("silverhart_palace_council_chamber")
	_check(int(council.get("anchor", {}).get("q", 0)) == -6 and int(council.get("anchor", {}).get("r", 0)) == -494, "Council chamber anchor must match buildSilverhartPalace")
	var council_floor := registry.get_floor_definition("silverhart_palace_council_chamber", 0)
	_check(council_floor.get("rooms", []).size() == 1, "Council chamber must retain its source-authored room")
	_check(council_floor.get("actors", []).size() == 1 and String(council_floor.get("actors", [])[0].get("id", "")) == "chancellor_merric_vane", "Council chamber must retain Chancellor Merric Vane")
	_check(_has_record(council_floor.get("tile_objects", []), "council_front_door"), "Council chamber must retain its source entrance")
	_check(_has_record(council_floor.get("tile_objects", []), "council_table"), "Council chamber must retain its council table")
	_check(_has_record(council_floor.get("tile_objects", []), "palace_secret_passage"), "Council chamber must retain the source hidden passage to the palace tunnel network")
	_check(_has_record(council_floor.get("tile_objects", []), "guild_big_score_prize"), "Council chamber must retain the source Guild Big Score evidence marker")
	var palace_tunnel: Dictionary = registry.get_definition("silverhart_palace_tunnel")
	_check(int(palace_tunnel.get("anchor", {}).get("q", 0)) == -9 and int(palace_tunnel.get("anchor", {}).get("r", 0)) == -492, "Palace tunnel junction must match buildSilverhartPalace tunnelPalaceHex")
	var palace_surface_anchor := registry.get_floor_definition("silverhart_palace_tunnel", 0)
	_check(not palace_surface_anchor.is_empty() and palace_surface_anchor.get("rooms", []).is_empty(), "Palace tunnel surface floor must be an external host-location anchor, not duplicate chamber geometry")
	var palace_tunnel_floor := registry.get_floor_definition("silverhart_palace_tunnel", -9)
	_check(palace_tunnel_floor.get("rooms", []).size() == 1 and palace_tunnel_floor.get("tile_objects", []).size() == 1, "Palace tunnel endpoint must remain the source one-cell floor -9 stub")
	_check(_has_record(palace_tunnel_floor.get("tile_objects", []), "palace_tunnel_junction"), "Palace tunnel stub must retain its source junction object")

	var barracks: Dictionary = registry.get_definition("silverhart_palace_barracks")
	_check(barracks.get("floors", []).size() == 2, "Palace barracks must retain its mess hall and loft")
	_check(registry.get_floor_definition("silverhart_palace_barracks", 0).get("actors", []).size() == 3, "Barracks must retain the three source guards")
	_check(_has_record(registry.get_floor_definition("silverhart_palace_barracks", 1).get("tile_objects", []), "barracks_bed_4"), "Barracks loft must retain all source bed positions")

	var wizard_tower: Dictionary = registry.get_definition("silverhart_palace_wizard_tower")
	_check(wizard_tower.get("floors", []).size() == 3, "Wizard's tower must retain its ground floor, study and observatory")
	_check(registry.get_floor_definition("silverhart_palace_wizard_tower", 0).get("actors", []).size() == 1, "Wizard's tower must retain Court Wizard Thessaly")
	_check(_has_record(registry.get_floor_definition("silverhart_palace_wizard_tower", 0).get("tile_objects", []), "wizard_corruption_ledger"), "Wizard's tower must retain its source corruption ledger")
	_check(_has_record(registry.get_floor_definition("silverhart_palace_wizard_tower", 1).get("tile_objects", []), "wizard_spire_notes"), "Wizard's study must retain its source notes")

	var guild: Dictionary = registry.get_definition("silverhart_thieves_guild")
	_check(int(guild.get("anchor", {}).get("q", 0)) == 14 and int(guild.get("anchor", {}).get("r", 0)) == -426, "Thieves' Guild anchor must match buildSilverhartPalace")
	var guild_floor := registry.get_floor_definition("silverhart_thieves_guild", 0)
	_check(guild_floor.get("actors", []).size() == 2, "Thieves' Guild must retain Tessa Nightshade and Guildmaster Corvin Ashe")
	_check(_has_record(guild_floor.get("tile_objects", []), "thieves_guild_front_door"), "Thieves' Guild must retain its source entrance")
	_check(_has_record(guild_floor.get("tile_objects", []), "guild_hidden_vault_door"), "The hidden vault door must be registered")
	_check(guild_floor.get("rooms", []).size() == 2, "Guild and concealed vault must have separate source-authored rooms")
	_check(String(guild_floor.get("rooms", [])[1].get("hidden_by_secret", "")) == "guild_hidden_vault_door", "Vault room must remain hidden behind its own secret door")
	var guild_chest := _record_by_id(guild_floor.get("tile_objects", []), "guild_vault_chest")
	_check(guild_chest.get("items", []) == ["gem_blue", "gem_red", "silvertongue_ring"], "Hidden vault must retain its three source treasure items")


	# The merchant quarter's first four source interiors must be separate,
	# traversable floor maps rather than exterior-only building records.
	var merchant_entrances := {
		"silverhart_stables": "stables_front_door",
		"silverhart_general_goods": "general_goods_front_door",
		"silverhart_clothier": "clothier_front_door",
		"silverhart_magic_shop": "magic_shop_front_door"
	}
	for interior_id in merchant_entrances:
		var interior: Dictionary = registry.get_definition(interior_id)
		_check(not interior.is_empty(), "Silverhart merchant interior must be registered: " + interior_id)
		_check(interior.get("floors", []).size() == 1, "Merchant interior must have its source ground floor: " + interior_id)
		var interior_floor := registry.get_floor_definition(interior_id, 0)
		_check(interior_floor.get("rooms", []).size() == 1, "Merchant interior must retain its source room: " + interior_id)
		_check(_has_record(interior_floor.get("tile_objects", []), merchant_entrances[interior_id]), "Merchant interior must retain its source entrance: " + interior_id)
	var stables_floor := registry.get_floor_definition("silverhart_stables", 0)
	_check(_has_record(stables_floor.get("tile_objects", []), "stables_pen"), "Royal stables must retain the source pen feature")
	var general_goods_floor := registry.get_floor_definition("silverhart_general_goods", 0)
	_check(_has_record(general_goods_floor.get("tile_objects", []), "guild_initiation_prize"), "General goods must retain the Thieves' Guild initiation evidence")
	_check(_has_record(general_goods_floor.get("tile_objects", []), "city_secret_passage"), "General goods must retain the source hidden passage to the city tunnel network")
	var city_tunnel: Dictionary = registry.get_definition("silverhart_city_tunnel")
	_check(int(city_tunnel.get("anchor", {}).get("q", 0)) == -20 and int(city_tunnel.get("anchor", {}).get("r", 0)) == -489, "City tunnel junction must match buildSilverhartPalace tunnelCityHex")
	var city_surface_anchor := registry.get_floor_definition("silverhart_city_tunnel", 0)
	_check(not city_surface_anchor.is_empty() and city_surface_anchor.get("rooms", []).is_empty(), "City tunnel surface floor must be an external host-location anchor, not duplicate store geometry")
	var city_tunnel_floor := registry.get_floor_definition("silverhart_city_tunnel", -9)
	_check(city_tunnel_floor.get("rooms", []).size() == 1 and city_tunnel_floor.get("tile_objects", []).size() == 1, "City tunnel endpoint must remain the source one-cell floor -9 stub")
	_check(_has_record(city_tunnel_floor.get("tile_objects", []), "city_tunnel_junction"), "City tunnel stub must retain its source junction object")
	var clothier_floor := registry.get_floor_definition("silverhart_clothier", 0)
	_check(_has_record(clothier_floor.get("tile_objects", []), "clothier_bed"), "Clothier must retain the sourcekeeper's bed")
	var magic_shop_floor := registry.get_floor_definition("silverhart_magic_shop", 0)
	_check(_has_record(magic_shop_floor.get("tile_objects", []), "magic_shop_bed"), "Magic shop must retain the dealer's bed")

	var elven_capital: Dictionary = registry.get_definition("silthandriel")
	_check(int(elven_capital.get("anchor", {}).get("q", 0)) == -252 and int(elven_capital.get("anchor", {}).get("r", 0)) == 934, "Sil'thandriel anchor must match buildElvenCapital")
	_check(elven_capital.get("floors", []).size() == 3, "Sil'thandriel must retain its surface, lower canopy and upper court")
	var tree_base := registry.get_floor_definition("silthandriel", 0)
	_check(tree_base.get("rooms", []).is_empty(), "Sil'thandriel surface clearing must not be turned into an enclosed building")
	_check(_has_record(tree_base.get("tile_objects", []), "tree_stair_up"), "The great tree's source stair must lead into the lower canopy")
	var lower_canopy := registry.get_floor_definition("silthandriel", 1)
	_check(lower_canopy.get("rooms", []).size() == 2, "Lower Canopy must retain the Archive and Healer Lodge platforms")
	_check(lower_canopy.get("corridors", []).size() == 2, "Lower Canopy must retain the tree access and Archive-to-Lodge rope bridge")
	_check(_has_record(lower_canopy.get("tile_objects", []), "lodge_herb_patch_west") and _has_record(lower_canopy.get("tile_objects", []), "lodge_herb_patch_east"), "Healer Lodge must retain both source herb patches")
	var upper_court := registry.get_floor_definition("silthandriel", 2)
	_check(String(upper_court.get("rooms", [])[0].get("wall_mode", "")) == "open", "Court of the Silver Leaf must remain an open-air pavilion")
	_check(_has_record(upper_court.get("tile_objects", []), "court_throne"), "Upper Court must retain its source throne")
	_check(elven_capital.get("transitions", []).size() == 4, "Sil'thandriel must retain reciprocal stairs between all three levels")

	var definition: Dictionary = registry.get_definition("kragmoor")
	_check(int(definition.get("anchor", {}).get("q", 0)) == 908 and int(definition.get("anchor", {}).get("r", 0)) == -626, "Kragmoor anchor must match buildDwarvenKingdom")
	_check(int(definition.get("massif_radius", 0)) == 25, "Kragmoor must retain the source solid-massif radius")
	var expected_floors := [0, -1, -2, -3, -4, -5]
	var actual_floors: Array[int] = []
	for floor_variant in definition.get("floors", []):
		actual_floors.append(int(floor_variant.get("floor", 999999)))
	_check(actual_floors == expected_floors, "Kragmoor must preserve surface, four open underground levels and the sealed fifth level")
	var great_hall := registry.get_floor_definition("kragmoor", -1)
	_check(great_hall.get("actors", []).size() == 3, "Great Hall must contain King Balrik and both source guards")
	_check(_has_record(great_hall.get("tile_objects", []), "throne"), "Great Hall must retain its throne")
	var vault := registry.get_floor_definition("kragmoor", -2)
	_check(vault.get("actors", []).size() == 2, "Vault/Runeforge must contain the trader and master runesmith")
	_check(_has_record(vault.get("tile_objects", []), "rune_forge"), "Runeforge must retain its forge object")
	var mine := registry.get_floor_definition("kragmoor", -3)
	_check(_has_record(mine.get("tile_objects", []), "mine_ledger"), "Deep Mine must retain the foreman's ledger")
	_check(mine.get("actors", []).size() == 1, "Deep Mine must contain Foreman Dornik")
	var tunnels := registry.get_floor_definition("kragmoor", -4)
	_check(tunnels.get("creatures", []).size() == 3, "Lower Tunnels must preserve two spiders and the Broodmother")
	var deep := registry.get_floor_definition("kragmoor", -5)
	_check(deep.get("creatures", []).size() == 1, "Sunken Deep must contain the Ember-Wreathed Horror")
	_check(int(deep.get("creatures", [])[0].get("health", 0)) == 160, "The Horror must retain its source health")
	_check(deep.get("creatures", [])[0].get("inventory", []).count("starmetal_ore") == 2, "The Horror must retain both source Starmetal drops")
	var gate: Dictionary = definition.get("quest_gates", [])[0] if not definition.get("quest_gates", []).is_empty() else {}
	_check(String(gate.get("quest_id", "")) == "deepholds_infestation", "Sunken Deep must be gated by the source infestation quest ID")
	_check(String(gate.get("quest_title", "")) == "What Nests Below", "Sunken Deep must retain the source quest title")
	_check(not bool(gate.get("initially_available", true)) and bool(gate.get("reveal_is_idempotent", false)), "Sunken Deep passage must begin sealed and reveal idempotently")
	var gated_transition := false
	for transition in definition.get("transitions", []):
		if int(transition.get("from_floor", 999)) == -4 and int(transition.get("to_floor", 999)) == -5:
			gated_transition = not bool(transition.get("initially_available", true)) and String(transition.get("unlocked_by_quest", "")) == "deepholds_infestation"
	_check(gated_transition, "The -4 to -5 stair must be locked behind What Nests Below")
	var thieves_cove: Dictionary = registry.get_definition("thieves_cove")
	_check(int(thieves_cove.get("anchor", {}).get("q", 0)) == -274 and int(thieves_cove.get("anchor", {}).get("r", 0)) == 40, "Thieves' Cove must retain the source west-road offset")
	_check(thieves_cove.get("floors", []).size() == 4, "Thieves' Cove must retain its entrance, den, vault and wilderness tunnel stub")
	_check(registry.get_floor_definition("thieves_cove", 0).get("rooms", []).size() == 1, "Thieves' Cove surface must retain its source cave room")
	_check(registry.get_floor_definition("thieves_cove", -1).get("rooms", [])[0].get("half_width", 0) == 3, "The Smugglers' Den must retain its source room width")
	_check(registry.get_floor_definition("thieves_cove", -2).get("rooms", [])[0].get("half_height", 0) == 3, "The Hidden Vault must retain its source room height")
	var tunnel_stub: Dictionary = registry.get_floor_definition("thieves_cove", -9)
	_check(tunnel_stub.get("rooms", [])[0].get("half_width", 0) == 1 and tunnel_stub.get("rooms", [])[0].get("half_height", 0) == 1, "The wilderness tunnel endpoint must remain a one-cell stub, not an invented large room")
	_check(thieves_cove.get("transitions", []).size() == 6, "Thieves' Cove must retain reciprocal stairs between all four source levels")

	var crypt: Dictionary = registry.get_definition("vessel_seekers_crypt")
	_check(int(crypt.get("anchor", {}).get("q", 0)) == 32 and int(crypt.get("anchor", {}).get("r", 0)) == -154, "Vessel-Seeker crypt anchor must derive from the abandoned house centre")
	_check(crypt.get("floors", []).size() == 1, "Vessel-Seeker crypt must preserve its single source floor")
	var crypt_floor := registry.get_floor_definition("vessel_seekers_crypt", 0)
	_check(crypt_floor.get("rooms", []).size() == 3, "Crypt must retain its source entrance, ossuary and ritual chambers")
	_check(crypt_floor.get("corridors", []).size() == 3, "Crypt must retain both source corridors")
	_check(crypt_floor.get("tile_objects", []).size() == 5, "Crypt must retain its three source doors and two explicit wall-ring connection repairs")
	_check(crypt_floor.get("actors", []).is_empty() and crypt_floor.get("creatures", []).is_empty(), "Crypt map port must leave actors and encounters to campaign systems")
	var barrow: Dictionary = registry.get_definition("corvin_ashgrave_barrow")
	_check(int(barrow.get("anchor", {}).get("q", 0)) == 63 and int(barrow.get("anchor", {}).get("r", 0)) == -160, "Corvin Ashgrave barrow anchor must derive from the source necromancer ritual centre")
	_check(barrow.get("floors", []).size() == 1, "Corvin Ashgrave barrow must remain a single source floor, not invented vertical levels")
	var barrow_floor := registry.get_floor_definition("corvin_ashgrave_barrow", 0)
	_check(barrow_floor.get("rooms", []).size() == 2, "Barrow must retain its source antechamber and lich sanctum")
	_check(barrow_floor.get("corridors", []).size() == 1, "Barrow must retain the straight source corridor between rooms")
	_check(_has_record(barrow_floor.get("tile_objects", []), "barrow_entrance_door") and _has_record(barrow_floor.get("tile_objects", []), "lich_sanctum_door"), "Barrow must retain both source door openings")
	_check(barrow_floor.get("actors", []).is_empty() and barrow_floor.get("creatures", []).is_empty(), "Barrow map port must not pull campaign-owned actors or encounters into map data")

	var emberlode_mine: Dictionary = registry.get_definition("emberlode_mine")
	_check(int(emberlode_mine.get("anchor", {}).get("q", 0)) == -252 and int(emberlode_mine.get("anchor", {}).get("r", 0)) == 16, "Emberlode Mine anchor must match buildEmberlode mineCenter")
	_check(emberlode_mine.get("floors", []).size() == 3, "Emberlode Mine must retain its surface entrance and two underground levels")
	var mine_surface := registry.get_floor_definition("emberlode_mine", 0)
	_check(String(mine_surface.get("rooms", [])[0].get("row_shift_mode", "")) == "source_building", "Emberlode surface mine must retain the original carveBuilding row shift")
	_check(_has_record(mine_surface.get("tile_objects", []), "emberlode_ledger"), "Emberlode surface must retain its source ledger")
	_check(_has_record(mine_surface.get("tile_objects", []), "mine_stair_down"), "Emberlode surface must retain its source stair to the Working Vein")
	var working_vein := registry.get_floor_definition("emberlode_mine", -1)
	_check(_has_record(working_vein.get("tile_objects", []), "working_vein_gold"), "Working Vein must retain the source gold ore node")
	_check(_has_record(working_vein.get("tile_objects", []), "old_seam_stair_down"), "Working Vein must retain its stair to the Old Seam")
	var old_seam := registry.get_floor_definition("emberlode_mine", -2)
	_check(_has_record(old_seam.get("tile_objects", []), "old_seam_blue_gem"), "Old Seam must retain the source blue-gem ore node")
	_check(old_seam.get("creatures", []).size() == 2, "Old Seam must preserve both source spider placements as campaign-owned spawn data")
	_check(emberlode_mine.get("transitions", []).size() == 4, "Emberlode Mine must retain reciprocal transitions between all three levels")

	_check(int(thieves_cove.get("anchor", {}).get("q", 0)) == -274 and int(thieves_cove.get("anchor", {}).get("r", 0)) == 40, "Thieves' Cove must retain the source west-road offset")
	var cove_den := registry.get_floor_definition("thieves_cove", -1)
	var cove_ledger := _find_record(cove_den.get("tile_objects", []), "sunken_cave_ledger")
	_check(String(cove_ledger.get("type", "")) == "journal", "Smugglers' Den must retain the source ledger marker type")
	_check(_position_matches(cove_ledger.get("position", {}), Vector2i(-274, 39)), "Smugglers' Den ledger must retain source position (-274, 39)")
	var cove_vault := registry.get_floor_definition("thieves_cove", -2)
	var cache_evidence := _find_record(cove_vault.get("tile_objects", []), "guild_cache_evidence")
	_check(String(cache_evidence.get("type", "")) == "evidence", "Hidden Vault must retain the source evidence marker type")
	_check(_position_matches(cache_evidence.get("position", {}), Vector2i(-273, 40)), "Hidden Vault evidence must retain source position (-273, 40)")
	var cove_junction := registry.get_floor_definition("thieves_cove", -9)
	var tunnel_junction := _find_record(cove_junction.get("tile_objects", []), "wilderness_tunnel_junction")
	_check(String(tunnel_junction.get("type", "")) == "tunnel_junction" and tunnel_junction.get("node_id", "") == "wilderness", "Wilderness stub must retain its source tunnel-junction marker")
	_check(thieves_cove.get("transitions", []).size() == 6, "Thieves' Cove must retain all three reciprocal source stair connections")
	_check(cove_den.get("actors", []).is_empty() and cove_den.get("creatures", []).is_empty(), "Thieves' Cove map data must not import Rook or bandit actors")

	var chapterhouse: Dictionary = registry.get_definition("lich_chapterhouse")
	_check(int(chapterhouse.get("anchor", {}).get("q", 0)) == -39 and int(chapterhouse.get("anchor", {}).get("r", 0)) == -346, "Silver Flame Chapterhouse anchor must match buildLichChapterhouse relative to Millbrook")
	var chapterhouse_floor := registry.get_floor_definition("lich_chapterhouse", 0)
	_check(chapterhouse_floor.get("rooms", []).size() == 1, "Chapterhouse must retain its single source-authored room")
	var chapterhouse_room: Dictionary = chapterhouse_floor.get("rooms", [])[0]
	_check(int(chapterhouse_room.get("half_width", 0)) == 4 and int(chapterhouse_room.get("half_height", 0)) == 3, "Chapterhouse room dimensions must match carveFlatRoom")
	_check(_has_record(chapterhouse_floor.get("tile_objects", []), "chapterhouse_east_door"), "Chapterhouse must retain its east entrance")
	_check(_has_record(chapterhouse_floor.get("tile_objects", []), "chapterhouse_fireplace"), "Chapterhouse must retain its central fireplace")
	_check(chapterhouse_floor.get("actors", []).is_empty() and chapterhouse_floor.get("creatures", []).is_empty(), "Chapterhouse map port must not import campaign actors or encounters")

	var abandoned_house: Dictionary = registry.get_definition("abandoned_house")
	_check(int(abandoned_house.get("anchor", {}).get("q", 0)) == 14 and int(abandoned_house.get("anchor", {}).get("r", 0)) == -176, "Abandoned House anchor must match the source 200-step north-road waypoint and +6 offset")
	var abandoned_floor := registry.get_floor_definition("abandoned_house", 0)
	_check(abandoned_floor.get("rooms", []).size() == 1, "Abandoned House must retain its single source room")
	var abandoned_room: Dictionary = abandoned_floor.get("rooms", [])[0]
	_check(int(abandoned_room.get("half_width", 0)) == 3 and int(abandoned_room.get("half_height", 0)) == 2, "Abandoned House room dimensions must match carveFlatRoom")
	_check(_has_record(abandoned_floor.get("tile_objects", []), "abandoned_house_journal"), "Abandoned House must retain its journal")
	_check(_has_record(abandoned_floor.get("tile_objects", []), "phylactery_altar"), "Abandoned House must retain the phylactery altar position")
	_check(abandoned_floor.get("actors", []).is_empty() and abandoned_floor.get("creatures", []).is_empty(), "Abandoned House map port must not import dormant skeletons")

	# The four diplomatic missions, Ironbond's city office, the Grand Cathedral
	# and the Commons inn are source-authored Silverhart rooms, not exterior-only
	# building shells. Keep each room and its real entrance in the shared floor
	# registry so later door wiring can consume them without bespoke geometry.
	var silverhart_districts := {
		"silverhart_elven_embassy": {"centre": Vector2i(0, -466), "half_width": 3, "half_height": 2, "door": Vector2i(3, -466)},
		"silverhart_dwarven_embassy": {"centre": Vector2i(16, -470), "half_width": 3, "half_height": 2, "door": Vector2i(13, -470)},
		"silverhart_aldenreach_embassy": {"centre": Vector2i(0, -460), "half_width": 3, "half_height": 2, "door": Vector2i(3, -460)},
		"silverhart_corvane_embassy": {"centre": Vector2i(16, -463), "half_width": 3, "half_height": 2, "door": Vector2i(13, -463)},
		"silverhart_ironbond_office": {"centre": Vector2i(1, -454), "half_width": 3, "half_height": 2, "door": Vector2i(4, -454)},
		"silverhart_grand_cathedral": {"centre": Vector2i(14, -451), "half_width": 4, "half_height": 4, "door": Vector2i(10, -451)},
		"silverhart_commons_inn": {"centre": Vector2i(8, -529), "half_width": 4, "half_height": 3, "door": Vector2i(8, -526)}
	}


	var silverhart_house_specs := {
		"silverhart_warrens_shack_west": {"centre": Vector2i(2, -433), "half_width": 2, "half_height": 2, "door": Vector2i(2, -431)},
		"silverhart_warrens_shack_centre": {"centre": Vector2i(5, -427), "half_width": 2, "half_height": 2, "door": Vector2i(5, -429)},
		"silverhart_warrens_shack_east": {"centre": Vector2i(11, -433), "half_width": 2, "half_height": 2, "door": Vector2i(11, -431)},
		"silverhart_north_cottage_one": {"centre": Vector2i(35, -507), "half_width": 2, "half_height": 2, "door": Vector2i(37, -507)},
		"silverhart_north_cottage_two": {"centre": Vector2i(35, -513), "half_width": 2, "half_height": 2, "door": Vector2i(37, -513)},
		"silverhart_north_cottage_three": {"centre": Vector2i(35, -519), "half_width": 2, "half_height": 2, "door": Vector2i(37, -519)},
		"silverhart_east_house_one": {"centre": Vector2i(26, -479), "half_width": 2, "half_height": 2, "door": Vector2i(28, -479)},
		"silverhart_east_house_two": {"centre": Vector2i(32, -480), "half_width": 2, "half_height": 2, "door": Vector2i(34, -480)},
		"silverhart_east_house_three": {"centre": Vector2i(23, -470), "half_width": 1, "half_height": 2, "door": Vector2i(24, -470)},
		"silverhart_east_house_four": {"centre": Vector2i(26, -471), "half_width": 1, "half_height": 1, "door": Vector2i(27, -471)},
		"silverhart_middle_ring_house_east": {"centre": Vector2i(49, -496), "half_width": 2, "half_height": 2, "door": Vector2i(51, -496)},
		"silverhart_middle_ring_house_northeast": {"centre": Vector2i(49, -536), "half_width": 2, "half_height": 2, "door": Vector2i(51, -536)},
		"silverhart_middle_ring_house_north": {"centre": Vector2i(8, -536), "half_width": 2, "half_height": 2, "door": Vector2i(8, -538)},
		"silverhart_middle_ring_house_west": {"centre": Vector2i(-32, -496), "half_width": 2, "half_height": 2, "door": Vector2i(-34, -496)},
		"silverhart_middle_ring_house_southwest": {"centre": Vector2i(-32, -455), "half_width": 2, "half_height": 2, "door": Vector2i(-34, -455)},
		"silverhart_middle_ring_house_southeast": {"centre": Vector2i(22, -452), "half_width": 2, "half_height": 2, "door": Vector2i(20, -452)}
	}
	for location_id in silverhart_house_specs:
		var house: Dictionary = silverhart_house_specs[location_id]
		var definition: Dictionary = registry.get_definition(location_id)
		_check(not definition.is_empty(), "Source-authored Silverhart house must be registered: " + location_id)
		_check(_position_matches(definition.get("anchor", {}), house["centre"]), "Silverhart house anchor must match source: " + location_id)
		var floor := registry.get_floor_definition(location_id, 0)
		var rooms: Array = floor.get("rooms", [])
		_check(rooms.size() == 1, "Silverhart house must retain one room: " + location_id)
		if rooms.is_empty():
			continue
		var room: Dictionary = rooms[0]
		_check(_position_matches(room.get("center", {}), house["centre"]), "Silverhart house room centre must match source: " + location_id)
		_check(int(room.get("half_width", 0)) == int(house["half_width"]) and int(room.get("half_height", 0)) == int(house["half_height"]), "Silverhart house dimensions must match carveFlatRoom: " + location_id)
		_check(_has_record(floor.get("tile_objects", []), location_id + ("_north_door" if location_id == "silverhart_warrens_shack_centre" or location_id == "silverhart_middle_ring_house_north" else "_west_door" if location_id == "silverhart_middle_ring_house_west" or location_id == "silverhart_middle_ring_house_southwest" or location_id == "silverhart_middle_ring_house_southeast" else "_south_door" if location_id.begins_with("silverhart_warrens") else "_east_door")), "Silverhart house must retain its source entrance: " + location_id)
	var southwest_floor := registry.get_floor_definition("silverhart_middle_ring_house_southwest", 0)
	_check(southwest_floor.get("floor_hexes", []).has({"q": -32, "r": -453}), "Southwest middle-ring house must retain the source wall-notch floor repair")


	# Source buildSilverhartPalace contains 40 ground-floor interior regions.
	# Rectangular rooms are represented as room records; the manor and Hallis
	# polygon are represented by explicit floor masks. Supplemental masks on
	# otherwise rectangular rooms do not count as additional interiors.
	var silverhart_ground_floor_regions := 0
	for location_id in registry.location_ids():
		if not location_id.begins_with("silverhart_"):
			continue
		var location_definition: Dictionary = registry.get_definition(location_id)
		var surface_floor := registry.get_floor_definition(location_id, 0)
		var surface_rooms: Array = surface_floor.get("rooms", [])
		silverhart_ground_floor_regions += surface_rooms.size()
		if surface_rooms.is_empty() and not surface_floor.get("floor_hexes", []).is_empty():
			silverhart_ground_floor_regions += 1
	_check(silverhart_ground_floor_regions == 40, "All 40 source-authored Silverhart ground-floor interior regions must be registered")
	var silverhart_noble_homes := {
		"silverhart_noble_neighbor_house": {"centre": Vector2i(45, -502), "half_width": 3, "half_height": 2, "door": Vector2i(48, -502)},
		"silverhart_outlying_house_east": {"centre": Vector2i(23, -546), "half_width": 2, "half_height": 2, "door": Vector2i(23, -544)},
		"silverhart_outlying_house_far_east": {"centre": Vector2i(48, -546), "half_width": 2, "half_height": 2, "door": Vector2i(48, -544)},
		"silverhart_outlying_house_west": {"centre": Vector2i(-32, -476), "half_width": 2, "half_height": 2, "door": Vector2i(-30, -476)}
	}
	for location_id in silverhart_noble_homes:
		var home: Dictionary = silverhart_noble_homes[location_id]
		var definition: Dictionary = registry.get_definition(location_id)
		_check(_position_matches(definition.get("anchor", {}), home["centre"]), "Noble/outlying house anchor must match source: " + location_id)
		var floor := registry.get_floor_definition(location_id, 0)
		var room: Dictionary = floor.get("rooms", [])[0]
		_check(_position_matches(room.get("center", {}), home["centre"]), "Noble/outlying room centre must match source: " + location_id)
		_check(int(room.get("half_width", 0)) == int(home["half_width"]) and int(room.get("half_height", 0)) == int(home["half_height"]), "Noble/outlying room dimensions must match carveFlatRoom: " + location_id)
	_check(_position_matches(registry.get_definition("silverhart_corstane_manor").get("anchor", {}), Vector2i(39, -502)), "Corstane manor anchor must match buildSilverhartPalace")
	var manor_floor := registry.get_floor_definition("silverhart_corstane_manor", 0)
	_check(manor_floor.get("floor_hexes", []).size() == 31, "Corstane manor must preserve the source-shrunk floor mask")
	_check(manor_floor.get("wall_hexes", []).size() == 24, "Corstane manor must preserve the source-rebuilt wall mask")
	_check(manor_floor.get("floor_hexes", []).has({"q": 36, "r": -502}), "Corstane manor's moved west door must remain floor")
	_check(manor_floor.get("wall_hexes", []).has({"q": 36, "r": -501}), "Corstane manor's shifted west wall must be restored")

	var builder_house := registry.get_floor_definition("silverhart_builder_house", 0)
	_check(_position_matches(registry.get_definition("silverhart_builder_house").get("anchor", {}), Vector2i(38, -492)), "Hallis's house anchor must match the source polygon centroid")
	_check(builder_house.get("floor_hexes", []).size() == 40, "Hallis's polygon house must retain its flood-filled interior and both door cells")
	_check(builder_house.get("wall_hexes", []).size() == 28, "Hallis's polygon house must retain its reinforced perimeter")
	_check(_has_record(builder_house.get("tile_objects", []), "silverhart_builder_house_west_door"), "Hallis's house must retain its west door")
	_check(_has_record(builder_house.get("tile_objects", []), "silverhart_builder_house_south_door"), "Hallis's house must retain its south door")

	for embassy_id in ["silverhart_elven_embassy", "silverhart_dwarven_embassy", "silverhart_aldenreach_embassy", "silverhart_corvane_embassy"]:
		_check(_has_record(registry.get_floor_definition(embassy_id, 0).get("tile_objects", []), embassy_id + "_table"), "Each Silverhart embassy must retain its source table: " + embassy_id)
	var cathedral_objects: Array = registry.get_floor_definition("silverhart_grand_cathedral", 0).get("tile_objects", [])
	_check(_has_record(cathedral_objects, "silverhart_grand_cathedral_altar"), "Grand Cathedral must retain its source altar")
	_check(_has_record(cathedral_objects, "silverhart_grand_cathedral_bench_west") and _has_record(cathedral_objects, "silverhart_grand_cathedral_bench_east"), "Grand Cathedral must retain both source benches")
	var commons_objects: Array = registry.get_floor_definition("silverhart_commons_inn", 0).get("tile_objects", [])
	_check(_has_record(commons_objects, "silverhart_commons_inn_fireplace"), "Silverhart Commons inn must retain its source fireplace")
	_check(_has_record(commons_objects, "silverhart_commons_inn_bench_west") and _has_record(commons_objects, "silverhart_commons_inn_bench_east"), "Silverhart Commons inn must retain both source benches")
	var ironbond_floor := registry.get_floor_definition("silverhart_ironbond_office", 0)
	_check(ironbond_floor.get("floor_hexes", []).has({"q": 4, "r": -457}), "Ironbond office must retain its source-opened corner")
	_check(ironbond_floor.get("wall_hexes", []).has({"q": 5, "r": -458}), "Ironbond office must retain its source-restored outer corner")
	_check(_has_record(ironbond_floor.get("tile_objects", []), "silverhart_ironbond_office_table"), "Ironbond office must retain its source table")
	_check(_has_record(ironbond_floor.get("tile_objects", []), "silverhart_ironbond_office_bench"), "Ironbond office must retain its source bench")
	for location_id in silverhart_districts:
		var district: Dictionary = silverhart_districts[location_id]
		var district_definition: Dictionary = registry.get_definition(location_id)
		_check(not district_definition.is_empty(), "Silverhart district interior must be registered: " + location_id)
		_check(_position_matches(district_definition.get("anchor", {}), district["centre"]), "Silverhart district anchor must match buildSilverhartPalace: " + location_id)
		var floor := registry.get_floor_definition(location_id, 0)
		_check(floor.get("rooms", []).size() == 1, "Silverhart district must retain its source-authored room: " + location_id)
		var room: Dictionary = floor.get("rooms", [])[0]
		_check(_position_matches(room.get("center", {}), district["centre"]), "Silverhart district room centre must match its source anchor: " + location_id)
		_check(int(room.get("half_width", 0)) == int(district["half_width"]) and int(room.get("half_height", 0)) == int(district["half_height"]), "Silverhart district room dimensions must match carveFlatRoom: " + location_id)
		_check(_has_record(floor.get("tile_objects", []), location_id + "_" + ("south" if location_id == "silverhart_commons_inn" else "west" if location_id == "silverhart_dwarven_embassy" or location_id == "silverhart_corvane_embassy" or location_id == "silverhart_grand_cathedral" else "east") + "_door"), "Silverhart district must retain its source entrance: " + location_id)
		_check(floor.get("actors", []).is_empty() and floor.get("creatures", []).is_empty(), "Silverhart district map port must not duplicate campaign-owned residents: " + location_id)

	if failures > 0:
		push_error("%d multi-story location test(s) failed." % failures)
		quit(1)
		return
	print("Kragmoor and Silverhart source-authored multi-story floor data validated.")
	quit(0)


func _record_by_id(records: Array, record_id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("id", "")) == record_id:
			return record
	return {}


func _find_record(records: Array, record_id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("id", "")) == record_id:
			return record
	return {}

func _has_record(records: Array, record_id: String) -> bool:
	for record in records:
		if record is Dictionary and String(record.get("id", "")) == record_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _position_matches(value: Variant, expected: Vector2i) -> bool:
	if value is Vector2i:
		return value == expected
	if value is Dictionary:
		return int(value.get("q", 999999)) == expected.x and int(value.get("r", 999999)) == expected.y
	return false
