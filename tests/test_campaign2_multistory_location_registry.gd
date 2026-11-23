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
	_check(registry.location_ids() == ["corvin_ashgrave_barrow", "emberlode_mine", "kragmoor", "silthandriel", "silverhart_clothier", "silverhart_general_goods", "silverhart_magic_shop", "silverhart_palace", "silverhart_palace_barracks", "silverhart_palace_council_chamber", "silverhart_palace_wizard_tower", "silverhart_stables", "silverhart_thieves_guild", "thieves_cove"], "Kragmoor and all source-authored Silverhart interiors must be registered")
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
