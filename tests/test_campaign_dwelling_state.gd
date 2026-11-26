extends SceneTree

var _failures := 0


func _initialize() -> void:
	_test_cottage_routes()
	_test_abandoned_house_quest_gate()
	_test_manor_reputation_and_fortification()
	_test_dwelling_camp_lodging()
	_test_household_residents_and_halvard_steward()
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


func _place_beds(state: CampaignDwellingState, dwelling_id: String, item_id: String, actor_hex: Vector2i, positions: Array[Vector2]) -> void:
	state.furniture_inventory[item_id] = positions.size()
	for position in positions:
		var placed := state.place_furniture(dwelling_id, item_id, position, 0, actor_hex)
		_check(bool(placed.get("ok", false)), "Furniture should be placeable within the dwelling.")


func _test_cottage_routes() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	_check(bool(state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot").get("ok", false)), "The starting cottage should have no reputation or quest gate.")
	_check(int(state.camp_profile_for("crossroads_cottage").get("sleeping_capacity", 0)) == 0, "An unfurnished cottage should not invent a bed.")
	_place_beds(state, "crossroads_cottage", "bed_single", Vector2i(13, 27), [Vector2(-1.5, 0.0)])
	_check(int(state.camp_profile_for("crossroads_cottage").get("sleeping_capacity", 0)) == 1, "A placed single bed should provide one indoor sleeping place.")
	_check(not bool(state.evaluate_action("upgrade_country_house", journal, player, "materials", "crossroads_plot").get("ok", false)), "The country-house upgrade should require materials or gold.")
	_add_item(player, "wood", 6)
	_add_item(player, "stone", 6)
	_check(bool(state.complete_action("upgrade_country_house", journal, player, "materials", "crossroads_plot").get("ok", false)), "The country-house upgrade should accept gathered materials.")
	_place_beds(state, "crossroads_cottage", "bed_double", Vector2i(13, 27), [Vector2(2.2, 0.0)])
	_check(int(state.camp_profile_for("crossroads_cottage").get("sleeping_capacity", 0)) == 3, "A single and double bed should provide three indoor sleeping places.")
	var gold_state := CampaignDwellingState.new()
	var gold_player := _player()
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
	_check(int(state.camp_profile_for("abandoned_house").get("sleeping_capacity", 0)) == 0, "A restored but unfurnished house should not invent beds.")
	_place_beds(state, "abandoned_house", "bed_double", Vector2i(14, -176), [Vector2.ZERO])
	_check(int(state.camp_profile_for("abandoned_house").get("sleeping_capacity", 0)) == 2, "A placed double bed should shelter two party members.")


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
	_check(int(state.camp_profile_for("silverhart_manor").get("sleeping_capacity", 0)) == 0, "An unfurnished manor should not invent beds.")
	_place_beds(state, "silverhart_manor", "bed_double", Vector2i(39, -502), [Vector2(-3.0, -2.0), Vector2(0.0, -2.0), Vector2(3.0, -2.0), Vector2(0.0, 2.0)])
	_check(int(state.camp_profile_for("silverhart_manor").get("sleeping_capacity", 0)) == 8, "Four placed double beds should provide eight indoor sleeping places.")



func _test_household_residents_and_halvard_steward() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	_check(bool(state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot").get("ok", false)), "The cottage should be claimable before assigning a household resident.")
	_check(state.resident_capacity_for("crossroads_cottage") == 3, "The cottage should use its existing indoor capacity for household residents.")
	var assigned := state.assign_resident("crossroads_cottage", "rowan_fletcher", {"preferred_activity": "watch"})
	_check(bool(assigned.get("ok", false)), "An independent NPC should be assignable to an owned home.")
	_check(String(state.resident_schedule_for("rowan_fletcher", 10.0).get("activity", "")) == "watch", "A resident should use their authored daytime routine.")
	_check(String(state.resident_schedule_for("rowan_fletcher", 22.0).get("activity", "")) == "sleep", "Household residents should sleep overnight.")
	var companion := state.assign_resident("crossroads_cottage", "ser_aldric_thorne")
	_check(not bool(companion.get("ok", false)) and String(companion.get("reason", "")) == "companions_belong_to_camp_roster", "Companions must remain in the companion/camp system, not household resident assignments.")
	var wren_assignment := state.assign_resident("crossroads_cottage", "wren_talbot")
	_check(not bool(wren_assignment.get("ok", false)), "The original Wren companion must also remain outside the household resident roster.")
	_check(state.resident_schedule_for("ser_aldric_thorne", 22.0).is_empty(), "Rejected companions must not acquire a household schedule.")

	var manor_state := CampaignDwellingState.new()
	var manor_journal := CampaignJournal.new()
	var manor_player := _player()
	manor_journal.seed_faction_reputation("silverhart_kingdom", 60.0, 0.0)
	_check(bool(manor_state.complete_action("claim_silverhart_manor", manor_journal, manor_player, "materials", "silverhart_palace").get("ok", false)), "The manor should be claimable at the required kingdom standing.")
	_add_item(manor_player, "wood", 10)
	_add_item(manor_player, "stone", 10)
	_check(bool(manor_state.complete_action("fortify_silverhart_manor", manor_journal, manor_player, "materials", "silverhart_manor").get("ok", false)), "The manor should be made livable before appointing a steward.")
	_check(bool(manor_state.appoint_halvard_as_steward().get("ok", false)), "Halvard should be appointable as the permanent manor steward.")
	var breakfast := manor_state.resident_schedule_for("steward_halvard_greer", 8.0)
	_check(String(breakfast.get("activity", "")) == "cook" and String(breakfast.get("station_role", "")) == "hearth", "Halvard should prepare breakfast at the manor hearth.")
	_check(String(manor_state.resident_schedule_for("steward_halvard_greer", 10.0).get("activity", "")) == "housekeeping", "Halvard should maintain the manor during the morning.")
	_check(String(manor_state.resident_schedule_for("steward_halvard_greer", 13.0).get("activity", "")) == "manage_stores", "Halvard should manage household stores after midday.")
	_check(String(manor_state.resident_schedule_for("steward_halvard_greer", 15.0).get("activity", "")) == "welcome_guests", "Halvard should receive visitors in the afternoon.")
	_check(String(manor_state.resident_schedule_for("steward_halvard_greer", 18.0).get("activity", "")) == "cook", "Halvard should prepare the evening meal.")
	_check(manor_state.resident_ids_for_dwelling("silverhart_manor").has("steward_halvard_greer"), "Halvard should remain permanently assigned to the manor.")

func _test_save_restore() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot")
	state.assign_resident("crossroads_cottage", "rowan_fletcher", {"preferred_activity": "watch"})
	state.assign_resident("crossroads_cottage", "oskar_vinn", {"preferred_activity": "socialise"})
	var restored := CampaignDwellingState.new()
	_check(restored.from_dict(state.to_dict()), "Dwelling ownership and resident assignments should restore from a save.")
	_check(restored.to_dict() == state.to_dict(), "Dwelling ownership, improvements and resident schedules should round-trip.")
	_check(restored.resident_ids_for_dwelling("crossroads_cottage").size() == 2, "Both residents should remain assigned after loading.")


func _test_dwelling_camp_lodging() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot")
	_place_beds(state, "crossroads_cottage", "bed_single", Vector2i(13, 27), [Vector2.ZERO])
	var profile := state.camp_profile_for("crossroads_cottage")
	var camp := CampSimulation.new()
	camp.begin_camp({"walkable": true, "dwelling_profile": profile}, ["player", "companion"], {}, {"tents": 0})
	_check(camp.sleeping_arrangements.size() == 2, "The party should receive one arrangement per member.")
	_check(String(camp.sleeping_arrangements[0].get("shelter_type", "")) == "dwelling", "The cottage bed should be assigned before open-air sleeping.")
	_check(String(camp.sleeping_arrangements[1].get("shelter_type", "")) == "dwelling", "A party member should use available indoor floor space after the bed is assigned.")
	_check(String(camp.sleeping_arrangements[1].get("sleeping_surface", "")) == "floor", "The second occupant should sleep on the indoor floor when no second bed exists.")
	var result := camp.skip_to_morning()
	_check(bool(result.get("ok", false)), "An indoor bed-and-floor night should resolve.")
	var bed_user: Dictionary = result.summary.characters.player
	var floor_user: Dictionary = result.summary.characters.companion
	_check(is_equal_approx(float(bed_user.warmth), float(floor_user.warmth)), "A bed and indoor floor should receive the same dwelling warmth bonus.")
	_check(float(bed_user.comfort) > float(floor_user.comfort), "A bed should provide greater overnight comfort than the indoor floor.")
