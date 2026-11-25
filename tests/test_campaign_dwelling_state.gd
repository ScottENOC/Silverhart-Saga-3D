extends SceneTree

var _failures := 0


func _initialize() -> void:
	_test_cottage_routes()
	_test_abandoned_house_quest_gate()
	_test_manor_reputation_and_fortification()
	_test_dwelling_camp_lodging()
	_test_save_restore()
	if _failures > 0:
		push_error("%d dwelling assertion(s) failed." % _failures)
		quit(1)
		return
	print("Campaign dwelling tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _player() -> CharacterState:
	return CharacterState.new("player", "Player")


func _add_item(player: CharacterState, item_id: String, quantity: int) -> void:
	player.inventory.append({"instance_id": item_id + "_" + str(player.inventory.size()), "id": item_id, "quantity": quantity})


func _place_bed(state: CampaignDwellingState, player: CharacterState, dwelling_id: String, site_hex: Vector2i, local_position: Vector2, floor_index: int = 0, item_id: String = "bed_single") -> void:
	var purchase := state.buy_furniture(item_id, player, CampaignFurnitureCatalog.SHOP_ID, Vector2i(8, -496))
	_check(bool(purchase.get("ok", false)), "The furniture shop should sell the test bed.")
	var placement := state.place_furniture(dwelling_id, item_id, local_position, 0, site_hex, floor_index)
	_check(bool(placement.get("ok", false)), "A purchased bed should fit in the dwelling floor plan.")


func _test_cottage_routes() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	player.gold = 1000
	_check(bool(state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot").get("ok", false)), "The starting cottage should have no reputation or quest gate.")
	_place_bed(state, player, "crossroads_cottage", Vector2i(13, 27), Vector2(-1.0, 0.0))
	_check(int(state.camp_profile_for("crossroads_cottage").get("sleeping_capacity", 0)) == 1, "A furnished cottage should provide one indoor sleeping place.")
	_check(not bool(state.evaluate_action("upgrade_country_house", journal, player, "materials", "crossroads_plot").get("ok", false)), "The country-house upgrade should require materials or gold.")
	_add_item(player, "wood", 6)
	_add_item(player, "stone", 6)
	_check(bool(state.complete_action("upgrade_country_house", journal, player, "materials", "crossroads_plot").get("ok", false)), "The country-house upgrade should accept gathered materials.")
	_place_bed(state, player, "crossroads_cottage", Vector2i(13, 27), Vector2(2.5, -1.5))
	_place_bed(state, player, "crossroads_cottage", Vector2i(13, 27), Vector2(2.5, 1.5))
	_check(int(state.camp_profile_for("crossroads_cottage").get("sleeping_capacity", 0)) == 3, "The expanded house should shelter three occupants once furnished.")
	var gold_state := CampaignDwellingState.new()
	var gold_player := _player()
	gold_player.gold = 1000
	gold_state.complete_action("build_crossroads_cottage", journal, gold_player, "materials", "crossroads_plot")
	gold_player.gold = 90
	_check(bool(gold_state.complete_action("upgrade_country_house", journal, gold_player, "gold", "crossroads_plot").get("ok", false)), "The country-house upgrade should preserve its 90-gold alternative.")
	_check(gold_player.gold == 0, "The gold alternative should deduct its price exactly once.")


func _test_abandoned_house_quest_gate() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	_add_item(player, "wood", 8)
	_add_item(player, "stone", 8)
	journal.register_quest_definition({"id": "abandoned_house_cleared", "objectives": []})
	_check(not bool(state.evaluate_action("restore_abandoned_house", journal, player, "materials", "abandoned_house").get("ok", false)), "The abandoned house must remain locked until its clearing quest is complete.")
	journal.start_quest("abandoned_house_cleared")
	journal.complete_quest("abandoned_house_cleared")
	_check(bool(state.complete_action("restore_abandoned_house", journal, player, "materials", "abandoned_house").get("ok", false)), "The abandoned house should be restorable after its quest and material gates.")
	player.gold = 1000
	_place_bed(state, player, "abandoned_house", Vector2i(14, -176), Vector2(-1.5, -1.0))
	_place_bed(state, player, "abandoned_house", Vector2i(14, -176), Vector2(1.5, 1.0))
	_check(int(state.camp_profile_for("abandoned_house").get("sleeping_capacity", 0)) == 2, "The restored and furnished roadside house should shelter two party members.")


func _test_manor_reputation_and_fortification() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	journal.seed_faction_reputation("silverhart_kingdom", 59.0, 0.0)
	_check(not bool(state.evaluate_action("claim_silverhart_manor", journal, player, "materials", "silverhart_palace").get("ok", false)), "The manor should remain unavailable below 60 kingdom standing.")
	journal.adjust_faction_reputation("silverhart_kingdom", 1.0, 0.0, "test")
	_check(bool(state.complete_action("claim_silverhart_manor", journal, player, "materials", "silverhart_palace").get("ok", false)), "The manor should unlock at 60 kingdom standing.")
	_check(int(state.camp_profile_for("silverhart_manor").get("sleeping_capacity", 0)) == 0, "An unfortified manor must not shelter the party.")
	_add_item(player, "wood", 10)
	_add_item(player, "stone", 10)
	_check(bool(state.complete_action("fortify_silverhart_manor", journal, player, "materials", "silverhart_manor").get("ok", false)), "Manor fortification should require gathered materials.")
	player.gold = 2000
	_place_bed(state, player, "silverhart_manor", Vector2i(39, -502), Vector2(-2.5, -2.0), 0, "bed_double")
	_place_bed(state, player, "silverhart_manor", Vector2i(39, -502), Vector2(2.5, -2.0), 0, "bed_double")
	_place_bed(state, player, "silverhart_manor", Vector2i(39, -502), Vector2(-2.5, 2.0), 1, "bed_double")
	_place_bed(state, player, "silverhart_manor", Vector2i(39, -502), Vector2(2.5, 2.0), 1, "bed_double")
	_check(int(state.camp_profile_for("silverhart_manor").get("sleeping_capacity", 0)) == 8, "The furnished livable manor should provide eight indoor sleeping places.")


func _test_save_restore() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot")
	var restored := CampaignDwellingState.new()
	_check(restored.from_dict(state.to_dict()), "Dwelling ownership should restore from a save.")
	_check(restored.to_dict() == state.to_dict(), "Dwelling ownership and improvements should round-trip.")


func _test_dwelling_camp_lodging() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot")
	player.gold = 1000
	_place_bed(state, player, "crossroads_cottage", Vector2i(13, 27), Vector2(-1.0, 0.0))
	var profile := state.camp_profile_for("crossroads_cottage")
	var camp := CampSimulation.new()
	camp.begin_camp({"walkable": true, "dwelling_profile": profile}, ["player", "companion"], {}, {"tents": 0})
	_check(camp.sleeping_arrangements.size() == 2, "The party should receive one arrangement per member.")
	_check(String(camp.sleeping_arrangements[0].get("shelter_type", "")) == "dwelling", "The cottage bed should be assigned before open-air sleeping.")
	_check(String(camp.sleeping_arrangements[1].get("shelter_type", "")) == "dwelling" and String(camp.sleeping_arrangements[1].get("sleeping_surface", "")) == "floor", "Party members without a bed should use indoor floor capacity before outdoor sleeping.")
	var result := camp.skip_to_morning()
	_check(bool(result.get("ok", false)), "A mixed indoor/outdoor night should resolve.")
	var indoor: Dictionary = result.summary.characters.player
	var outdoor: Dictionary = result.summary.characters.companion
	_check(float(indoor.warmth) > float(outdoor.warmth), "Dwelling shelter should improve warmth for its occupant.")
	_check(float(indoor.comfort) > float(outdoor.comfort), "Dwelling shelter should improve overall overnight comfort for its occupant.")
