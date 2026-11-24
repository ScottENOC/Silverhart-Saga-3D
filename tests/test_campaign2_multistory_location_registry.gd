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
	_check(registry.location_ids() == ["abandoned_house", "corvin_ashgrave_barrow", "emberlode_bunkhouse", "emberlode_foremans_hall", "emberlode_mine", "hollowmere_chapel", "hollowmere_general_store", "hollowmere_guild_den", "hollowmere_house", "hollowmere_store", "hollowmere_tavern", "kragmoor", "lich_chapterhouse", "millbrook_house", "mira_house", "northwatch_keep", "old_mac_farmhouse", "oskar_house", "reddale_guardhouse", "reddale_guildhouse", "reddale_inn", "reddale_manor", "reddale_reeve_house", "reddale_smithy", "ridgehold_keep", "silthandriel", "silverhart_clothier", "silverhart_general_goods", "silverhart_magic_shop", "silverhart_palace", "silverhart_palace_barracks", "silverhart_palace_council_chamber", "silverhart_palace_wizard_tower", "silverhart_stables", "silverhart_thieves_guild", "thieves_cove", "vessel_seekers_crypt"], "Kragmoor and all source-authored interiors must be registered")
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
