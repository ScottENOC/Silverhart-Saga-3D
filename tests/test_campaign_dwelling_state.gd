extends SceneTree

var _failures := 0


func _initialize() -> void:
	_test_cottage_routes()
	_test_furniture_purchase_crafting_and_placement()
	_test_abandoned_house_quest_gate()
	_test_manor_reputation_and_fortification()
	_test_dwelling_camp_lodging()
	_test_world_integration_and_persistence()
	_test_save_restore()
	_test_requirement_reports_and_atomic_payments()
	_test_abandoned_house_clearing_quest()
	_test_dwelling_world_sites_and_inspection()
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



func _test_furniture_purchase_crafting_and_placement() -> void:
	var state := CampaignDwellingState.new()
	_check(state.floor_count_for("crossroads_cottage") == 1, "The starter cottage should have one floor.")
	_check(state.floor_count_for("silverhart_manor") == 2, "The manor should support furniture on two separate floors.")
	_check(state.floor_size_for("silverhart_manor", 1) == Vector2(10.0, 8.0), "The manor's upper floor should have its own usable floor area.")
	var journal := CampaignJournal.new()
	var player := _player()
	player.gold = 100
	player.axial = Vector2i(8, -496)
	var wrong_shop := state.buy_furniture("bed_double", player, "general_store", player.axial)
	_check(not bool(wrong_shop.get("ok", false)), "Furniture purchases must use the dedicated capital furniture shop.")
	var purchase := state.buy_furniture("bed_double", player, CampaignFurnitureCatalog.SHOP_ID, player.axial)
	_check(bool(purchase.get("ok", false)), "The capital furniture shop should sell a double bed.")
	_check(player.gold == 52, "The furniture shop should deduct the listed price exactly once.")
	_check(state.furniture_inventory_count("bed_double") == 1, "Purchased furniture should enter the dwelling furniture inventory.")
	player.axial = Vector2i(13, 27)
	_check(bool(state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot").get("ok", false)), "The cottage should be available for furnishing.")
	var placed := state.place_furniture("crossroads_cottage", "bed_double", Vector2.ZERO, 0, player.axial)
	_check(bool(placed.get("ok", false)), "A purchased double bed should fit inside the cottage.")
	_check(state.sleeping_capacity_for("crossroads_cottage") == 2, "A double bed should provide two indoor sleeping places.")
	var overlap := state.place_furniture("crossroads_cottage", "bed_double", Vector2.ZERO, 0, player.axial)
	_check(not bool(overlap.get("ok", false)), "Furniture placement must reject overlapping objects.")
	var instance_id := String(placed.get("furniture", {}).get("instance_id", ""))
	_check(bool(state.remove_furniture("crossroads_cottage", instance_id, player.axial).get("ok", false)), "Placed furniture should be movable back into the furniture inventory.")
	_check(state.sleeping_capacity_for("crossroads_cottage") == 0, "Removing the only bed should remove its sleeping capacity.")
	_check(state.furniture_inventory_count("bed_double") == 1, "Removing furniture should return it to storage without destroying it.")
	_add_item(player, "wood", 8)
	_add_item(player, "hide", 2)
	var crafted := state.craft_furniture("bed_single", player, "crossroads_cottage", player.axial)
	_check(bool(crafted.get("ok", false)), "A single bed should be craftable from existing campaign materials.")
	_check(state.furniture_inventory_count("bed_single") == 1, "Crafted furniture should enter the same furniture inventory as purchased goods.")
	_check(state.to_dict().has("placed_furniture") and state.to_dict().has("furniture_inventory"), "Furniture inventory and placement should be included in dwelling saves.")
	var restored := CampaignDwellingState.new()
	_check(restored.from_dict(state.to_dict()), "Furniture state should validate and restore from a save.")
	_check(restored.to_dict() == state.to_dict(), "Furniture inventory and placement should round-trip exactly.")


func _test_cottage_routes() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	var wrong_site_state := CampaignDwellingState.new()
	var wrong_site := wrong_site_state.complete_action("build_crossroads_cottage", journal, player, "materials", "abandoned_house")
	_check(not bool(wrong_site.get("ok", false)), "A dwelling must not be claimed from another property site.")
	_check(not bool(wrong_site_state.owned.get("crossroads_cottage", false)), "A wrong-site claim must not set ownership.")
	_check(bool(state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot").get("ok", false)), "The starting cottage should have no reputation or quest gate.")
	_check(int(state.camp_profile_for("crossroads_cottage").get("sleeping_capacity", 0)) == 0, "A newly built cottage should start unfurnished with no beds.")
	_check(not bool(state.evaluate_action("upgrade_country_house", journal, player, "materials", "crossroads_plot").get("ok", false)), "The country-house upgrade should require materials or gold.")
	_add_item(player, "wood", 6)
	_add_item(player, "stone", 6)
	_check(bool(state.complete_action("upgrade_country_house", journal, player, "materials", "crossroads_plot").get("ok", false)), "The country-house upgrade should accept gathered materials.")
	_check(int(state.camp_profile_for("crossroads_cottage").get("sleeping_capacity", 0)) == 0, "Expanding the house should not grant free beds.")
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
	_check(int(state.camp_profile_for("abandoned_house").get("sleeping_capacity", 0)) == 0, "The restored roadside house should start without furniture.")


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
	_check(int(state.camp_profile_for("silverhart_manor").get("sleeping_capacity", 0)) == 0, "The fortified manor should start unfurnished rather than granting eight free beds.")


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
	player.axial = Vector2i(13, 27)
	_add_item(player, "wood", 8)
	_add_item(player, "hide", 2)
	_check(bool(state.craft_furniture("bed_single", player, "crossroads_cottage", player.axial).get("ok", false)), "The owner should be able to craft a single bed from timber and hide.")
	_check(bool(state.place_furniture("crossroads_cottage", "bed_single", Vector2(-1.0, 0.0), 0, player.axial).get("ok", false)), "The crafted bed should be placeable inside the cottage.")
	var profile := state.camp_profile_for("crossroads_cottage")
	var camp := CampSimulation.new()
	camp.begin_camp({"walkable": true, "dwelling_profile": profile}, ["player", "companion"], {}, {"tents": 0})
	_check(camp.sleeping_arrangements.size() == 2, "The party should receive one arrangement per member.")
	_check(String(camp.sleeping_arrangements[0].get("shelter_type", "")) == "dwelling", "The cottage bed should be assigned before open-air sleeping.")
	_check(String(camp.sleeping_arrangements[1].get("shelter_type", "")) == "open_air", "Party members beyond dwelling capacity should retain ordinary outdoor sleeping.")
	var result := camp.skip_to_morning()
	_check(bool(result.get("ok", false)), "A mixed indoor/outdoor night should resolve.")
	var indoor := result.summary.characters.player
	var outdoor := result.summary.characters.companion
	_check(float(indoor.warmth) > float(outdoor.warmth), "Dwelling shelter should improve warmth for its occupant.")
	_check(float(indoor.comfort) > float(outdoor.comfort), "Dwelling shelter should improve overall overnight comfort for its occupant.")


func _test_world_integration_and_persistence() -> void:
	var world := WorldSimulation.new()
	var player := CharacterState.new("player", "Player")
	var companion := CharacterState.new("companion", "Companion", Vector2i(1, 0))
	player.axial = Vector2i.ZERO
	player.side = "player"
	companion.side = "player"
	world.register_character(player)
	world.register_character(companion)
	world.restore_party_members(["player", "companion"])
	var blocked := world.begin_camp({"walkable": true, "dwelling_id": "crossroads_cottage"}, {}, {"tents": 0})
	_check(not bool(blocked.get("ok", false)), "An unowned dwelling must not be used as a sheltered camp.")
	var wrong_location := world.claim_dwelling("build_crossroads_cottage", "materials", "crossroads_plot")
	_check(not bool(wrong_location.get("ok", false)), "World simulation must reject a dwelling claim from the wrong location.")
	companion.axial = Vector2i(13, 27)
	var wrong_site := world.claim_dwelling("build_crossroads_cottage", "materials", "abandoned_house", "companion")
	_check(not bool(wrong_site.get("ok", false)), "World simulation must reject a site ID that does not match the interacting character's location.")
	_check(bool(world.claim_dwelling("build_crossroads_cottage", "materials", "crossroads_plot", "companion").get("ok", false)), "An active companion at the surveyed plot should be able to claim it.")
	player.axial = Vector2i(13, 27)
	var started_without_location := world.begin_camp({"walkable": true, "dwelling_id": "crossroads_cottage"}, {}, {"tents": 0})
	_check(not bool(started_without_location.get("ok", false)), "A dwelling must not provide shelter when the camp is not at its site.")
	var started := world.begin_camp({"walkable": true, "hex": Vector2i(13, 27), "dwelling_id": "crossroads_cottage"}, {}, {"tents": 0})
	_check(bool(started.get("ok", false)), "An owned cottage should be accepted as a camp site.")
	_check(String(world.camp_simulation.sleeping_arrangements[0].get("shelter_type", "")) == "open_air", "An unfurnished dwelling should not provide an indoor sleeping place.")
	var saved := world.to_dict()
	var restored := WorldSimulation.new()
	restored.load_dict(saved)
	_check(bool(restored.campaign_dwellings.owned.get("crossroads_cottage", false)), "World save/load should preserve dwelling ownership.")
	_check(String(restored.camp_simulation.lodging_profile.get("layout_id", "")) == "cottage_one_room", "World save/load should preserve the active dwelling camp layout.")

func _test_requirement_reports_and_atomic_payments() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	_check(bool(state.complete_action("build_crossroads_cottage", journal, player, "materials", "crossroads_plot").get("ok", false)), "The cottage should be available before testing its upgrade payment.")
	_add_item(player, "wood", 4)
	_add_item(player, "wood", 2)
	_add_item(player, "stone", 3)
	_add_item(player, "stone", 2)
	var before_inventory := player.inventory.duplicate(true)
	var missing_report := state.evaluate_action("upgrade_country_house", journal, player, "materials", "crossroads_plot")
	_check(not bool(missing_report.get("ok", false)), "A one-stone shortfall should keep the country-house upgrade locked.")
	var material_requirement: Dictionary = {}
	for requirement in missing_report.get("requirements", []):
		if String(requirement.get("id", "")) == "payment:materials":
			material_requirement = requirement
	_check(int(material_requirement.get("missing", {}).get("stone", 0)) == 1, "The requirement report should identify the exact missing stone quantity.")
	var failed_material_payment := state.complete_action("upgrade_country_house", journal, player, "materials", "crossroads_plot")
	_check(not bool(failed_material_payment.get("ok", false)), "An incomplete material payment must fail.")
	_check(player.inventory == before_inventory, "A failed payment must not consume any inventory items.")
	var invalid_payment := state.complete_action("upgrade_country_house", journal, player, "gems", "crossroads_plot")
	_check(not bool(invalid_payment.get("ok", false)), "An unsupported payment type must fail.")
	_check(player.inventory == before_inventory, "An unsupported payment type must not consume materials.")
	_add_item(player, "stone", 1)
	_check(bool(state.complete_action("upgrade_country_house", journal, player, "materials", "crossroads_plot").get("ok", false)), "Stacked inventory quantities should combine to pay the exact material cost.")
	_check(player.inventory.is_empty(), "A successful upgrade should deduct exactly six wood and six stone across inventory stacks.")
	var repeated := state.complete_action("upgrade_country_house", journal, player, "materials", "crossroads_plot")
	_check(not bool(repeated.get("ok", false)), "Repeating an upgrade must not grant it twice.")
	_check(player.inventory.is_empty(), "A repeated upgrade must not consume any additional resources.")
	var properties := state.property_snapshot(journal, player)
	_check(properties.size() == 3, "The management snapshot should describe the three distinct legacy properties.")
	_check(String(properties[0].get("id", "")) == "crossroads_cottage", "Property snapshots should use stable property IDs.")

func _test_abandoned_house_clearing_quest() -> void:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Player", AbandonedHouseClearingQuest.HOUSE_CENTRE)
	var companion := CharacterState.new("companion", "Companion", AbandonedHouseClearingQuest.HOUSE_CENTRE + Vector2i(1, 0))
	player.side = "player"
	companion.side = "player"
	simulation.register_character(player)
	simulation.register_character(companion)
	simulation.restore_party_members(["player", "companion"])
	var journal := simulation.campaign_journal
	var dwelling_state := CampaignDwellingState.new()
	_add_item(player, "wood", 8)
	_add_item(player, "stone", 8)
	var started := AbandonedHouseClearingQuest.ensure_started(journal)
	_check(bool(started.get("ok", false)), "Approaching the house should start its clearing quest.")
	var created := AbandonedHouseClearingQuest.ensure_guardians(simulation)
	_check(created.get("created_ids", []).size() == 3, "The abandoned house should spawn exactly three guardians.")
	for guardian_id in AbandonedHouseClearingQuest.GUARDIAN_IDS:
		var guardian := simulation.get_character(guardian_id)
		_check(guardian != null, "Every authored house guardian should exist in simulation state.")
		_check(guardian.tags.has("necromancerMinion"), "House guardians must carry the legacy necromancerMinion tag.")
		_check(not guardian.tags.has("cryptMinion"), "House guardians must not use the separate cryptMinion tag.")
	var crypt_minion := CharacterState.new("crypt_minion_test", "Crypt minion", AbandonedHouseClearingQuest.HOUSE_CENTRE + Vector2i(0, 2))
	crypt_minion.side = "enemy"
	crypt_minion.tags.append("cryptMinion")
	simulation.register_character(crypt_minion)
	var other_house_minion := CharacterState.new("other_necromancer_minion_test", "Other necromancer minion", AbandonedHouseClearingQuest.HOUSE_CENTRE + Vector2i(2, 0))
	other_house_minion.side = "enemy"
	other_house_minion.tags.append("necromancerMinion")
	simulation.register_character(other_house_minion)
	_check(not bool(dwelling_state.evaluate_action("restore_abandoned_house", journal, player, "materials", "abandoned_house").get("ok", false)), "Restoration must remain locked before the actual clearing encounter resolves.")
	var encounter := AbandonedHouseClearingQuest.start_encounter(simulation, ["player", "companion"])
	_check(bool(encounter.get("ok", false)) and simulation.is_in_combat, "The house interaction should start a real combat encounter.")
	var first_guardian := simulation.get_character(AbandonedHouseClearingQuest.GUARDIAN_IDS[0])
	first_guardian.health = 0
	first_guardian.alive = false
	var reputation_before := journal.faction_standing("necromancer_cult")
	_check(AbandonedHouseClearingQuest.apply_defeat_consequences(journal, simulation) == 1, "Killing a guardian should apply its reputation consequence once.")
	var reputation_after := journal.faction_standing("necromancer_cult")
	_check(reputation_after < reputation_before, "Killing a guardian should reduce necromancer-cult standing.")
	_check(AbandonedHouseClearingQuest.apply_defeat_consequences(journal, simulation) == 0, "Repeated resolution checks must not apply the same reputation penalty twice.")
	for index in range(1, AbandonedHouseClearingQuest.GUARDIAN_IDS.size()):
		var guardian := simulation.get_character(AbandonedHouseClearingQuest.GUARDIAN_IDS[index])
		guardian.health = 0
		guardian.alive = false
	AbandonedHouseClearingQuest.apply_defeat_consequences(journal, simulation)
	simulation.end_combat()
	AbandonedHouseClearingQuest.finish_encounter(simulation, encounter.get("previous_states", {}))
	var blocked_resolution := AbandonedHouseClearingQuest.resolve_clearing(journal, simulation)
	_check(bool(blocked_resolution.get("ok", false)) and not bool(blocked_resolution.get("completed", false)), "A living necromancerMinion elsewhere should preserve the legacy global clearing gate.")
	other_house_minion.health = 0
	other_house_minion.alive = false
	var resolved := AbandonedHouseClearingQuest.resolve_clearing(journal, simulation)
	_check(bool(resolved.get("ok", false)) and bool(resolved.get("completed", false)), "The clearing quest should resolve when all necromancerMinion enemies are dead.")
	_check(crypt_minion.can_act(), "A living cryptMinion must not block abandoned-house restoration.")
	_check(String(journal.quest_state(AbandonedHouseClearingQuest.QUEST_ID).get("status", "")) == "completed", "Quest completion should persist as an explicit campaign state.")
	_check(bool(dwelling_state.evaluate_action("restore_abandoned_house", journal, player, "materials", "abandoned_house").get("ok", false)), "Restoration should unlock from the actual resolved encounter, with the required materials.")
	var saved_characters := simulation.to_dict()
	var saved_journal := journal.to_dict()
	var restored_simulation := WorldSimulation.new()
	restored_simulation.load_dict(saved_characters)
	restored_simulation.campaign_journal.register_quest_definition(AbandonedHouseClearingQuest.definition())
	restored_simulation.campaign_journal.load_dict(saved_journal)
	_check(String(restored_simulation.campaign_journal.quest_state(AbandonedHouseClearingQuest.QUEST_ID).get("status", "")) == "completed", "The clearing quest should survive journal save/load.")
	_check(restored_simulation.get_character(AbandonedHouseClearingQuest.GUARDIAN_IDS[0]) != null, "Guardian encounter states should survive world save/load.")
	_check(not restored_simulation.get_character(AbandonedHouseClearingQuest.GUARDIAN_IDS[0]).can_act(), "Defeated guardians must not respawn from a save.")


func _test_dwelling_world_sites_and_inspection() -> void:
	var state := CampaignDwellingState.new()
	var journal := CampaignJournal.new()
	var player := _player()
	_check(state.is_at_site("crossroads_plot", Vector2i(13, 27)), "The cottage site should use the source crossroads-relative location.")
	_check(not state.is_at_site("crossroads_plot", Vector2i.ZERO), "A distant player must not pass the cottage location gate.")
	_check(state.is_at_site("silverhart_palace", Vector2i(8, -496)), "The manor grant should be tied to the royal palace.")
	var house_site := CampaignDwellingWorldService.site_definition("abandoned_house")
	_check(house_site.get("hex", Vector2i.ZERO) == Vector2i(14, -176), "The abandoned house should retain its source north-road location.")
	var nearby := CampaignDwellingWorldService.nearby_sites(Vector2i(14, -176), 2)
	_check(nearby.size() == 1 and String(nearby[0].get("id", "")) == "abandoned_house", "Only the nearby abandoned-house property should be offered at its site.")
	var inspection := CampaignDwellingWorldService.inspection_for_site(state, journal, player, "abandoned_house")
	_check(bool(inspection.get("ok", false)), "The abandoned house should have a player-facing inspection.")
	var body := String(inspection.get("text", ""))
	_check(body.contains("complete the abandoned-house clearing encounter"), "The inspection should explain the unmet clearing-quest requirement.")
	_check(body.contains("missing 8 wood") and body.contains("8 stone"), "The inspection should show the exact missing construction materials.")
	var parent := Node3D.new()
	var presentation := CampaignDwellingWorldPresentation.present_all(parent, state, 1.0)
	_check(bool(presentation.get("ok", false)) and int(presentation.get("site_count", 0)) == 3, "The three property sites should receive world presentations.")
	_check(parent.get_node_or_null("CampaignDwellingPresentation") != null, "Dwelling exteriors should be attached to the world scene.")
	parent.free()

