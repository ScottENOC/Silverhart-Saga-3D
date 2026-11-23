extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	_test_campaign_building_services()
	if _failures > 0:
		push_error("%d test assertion(s) failed." % _failures)
		quit(1)
		return
	print("Campaign building services tests passed.")
	quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _test_campaign_building_services() -> void:
	var services := CampaignBuildingServices.new()
	var buyer := CharacterState.new("commerce_buyer", "Commerce Buyer", Vector2i.ZERO)
	buyer.gold = 1000

	_check(CampaignBuildingServices.service_kind_for_building("silverhart_magic_shop") == "magic_shop", "Silverhart magic shop should resolve to the magic merchant service")
	var magic_stock := services.get_daily_stock("silverhart_magic_shop", 0.0)
	var ring_stock_id := ""
	for entry in magic_stock:
		if String(entry.get("item_id", "")) == "glowing_ring":
			ring_stock_id = String(entry.get("stock_id", ""))
	_check(not ring_stock_id.is_empty(), "Magic shop daily stock should include the source-defined Glowing Ring")
	var magic_purchase := services.purchase_stock(buyer, "silverhart_magic_shop", ring_stock_id, 0.0)
	_check(bool(magic_purchase.get("ok", false)), "A buyer with sufficient gold should be able to buy a stocked magic item")
	_check(buyer.gold == 800, "Magic item purchase should debit its catalogue price exactly once")
	if not buyer.inventory.is_empty():
		_check(String(buyer.inventory.back().get("id", "")) == "glowing_ring", "Purchased magic item should enter the normal character inventory")
		_check(String(buyer.inventory.back().get("provenance", "")) == "merchant_stock", "Purchased item should retain its source provenance")

	var cloth_stock := services.get_daily_stock("silverhart_clothier", 0.0)
	var bra_stock_found := false
	for entry in cloth_stock:
		if String(entry.get("item_id", "")) == "bra":
			bra_stock_found = true
			_check(entry.get("appearance", {}).get("clothing", {}).has("main"), "Ready-made clothing should carry per-layer appearance data")
			_check(float(entry.get("appearance", {}).get("clothing", {}).get("main", {}).get("opacity", 0.0)) >= 0.38, "Clothing stock opacity should stay inside the source transparency range")
	_check(bra_stock_found, "Clothier should stock current 3D bra assets even though their catalogue definitions have no buyPrice")

	var bespoke_appearance := {
		"clothing": {
			"outer": {"hue": 210.0, "saturation": 64.0, "value": 68.0, "opacity": 0.58},
			"trim": {"hue": 345.0, "saturation": 58.0, "value": 42.0, "opacity": 1.0}
		}
	}
	var commission := services.place_commission(
		buyer, "silverhart_clothier", "bra", bespoke_appearance, "Blue evening lace", 1000.0
	)
	_check(bool(commission.get("ok", false)), "Clothier should accept a valid bespoke clothing design")
	_check(float(commission.get("lead_seconds", 0.0)) == 14400.0, "Bra commissions should retain the source four-hour lead time")
	var bra_in_inventory := false
	for carried_item in buyer.inventory:
		if String(carried_item.get("id", "")) == "bra":
			bra_in_inventory = true
	_check(not bra_in_inventory, "A commission must not grant the garment before it is ready")
	var saved_services := services.to_dict()
	var restored_services := CampaignBuildingServices.new()
	restored_services.load_dict(saved_services)
	var early_collection := restored_services.collect_ready_commissions(buyer, 15399.0)
	_check(early_collection.is_empty(), "A commission must not be collectable before its ready time")
	var collected := restored_services.collect_ready_commissions(buyer, 15400.0)
	_check(collected.size() == 1, "A saved commission should be collectable once its in-game completion time has elapsed")
	_check(String(collected[0].get("design_name", "")) == "Blue evening lace", "Commission design name should survive save/load")
	_check(collected[0].get("appearance", {}) == bespoke_appearance, "Per-layer custom appearance should survive the commission queue and item grant")
	if not buyer.inventory.is_empty():
		_check(String(buyer.inventory.back().get("provenance", "")) == "bespoke_commission", "Collected commission should enter normal inventory as a real item instance")

	var armour_appearance := {
		"armour": {
			"metal": {"hue": 210.0, "saturation": 8.0, "value": 82.0, "opacity": 1.0, "unlocked": false},
			"leather": {"hue": 28.0, "saturation": 62.0, "value": 48.0, "opacity": 1.0, "unlocked": true}
		}
	}
	var armour_commission := restored_services.place_commission(
		buyer, "silverhart_armourer", "light_armor", armour_appearance, "Bright steel and brown leather", 20000.0
	)
	_check(bool(armour_commission.get("ok", false)), "Armourer should accept a standard steel/leather finish")
	_check(float(armour_commission.get("lead_seconds", 0.0)) == 86400.0, "Light armour commission should retain the source 24-hour lead time")
	var invalid_metal := armour_appearance.duplicate(true)
	invalid_metal["armour"]["metal"]["value"] = 70.0
	_check(String(restored_services.place_commission(
		buyer, "silverhart_armourer", "light_armor", invalid_metal, "Invalid steel tone", 20000.0
	).get("reason", "")) == "metal_finish_not_in_steel_palette", "Standard armour should reject values outside the curated steel finishes")
	invalid_metal["armour"]["metal"]["value"] = 10.0
	_check(String(restored_services.place_commission(
		buyer, "silverhart_armourer", "light_armor", invalid_metal, "Custom dark metal", 20000.0
	).get("reason", "")) == "metal_finish_not_in_steel_palette", "Custom metal must be explicitly marked as a premium finish")

	var simulation := WorldSimulation.new()
	var rider := CharacterState.new("stable_buyer", "Stable Buyer", Vector2i.ZERO)
	rider.side = "player"
	rider.skills["riding"] = 1
	rider.gold = 1000
	simulation.register_character(rider)
	for neighbour in HexGrid.neighbors(rider.axial):
		simulation.map_data.add_cell(neighbour, 0.0, true, "grass")
	var horse_purchase := restored_services.purchase_horse(simulation, rider.id, "chestnut", "war_trained")
	_check(bool(horse_purchase.get("ok", false)), "A qualified rider should be able to buy a war-trained horse at the stable")
	_check(rider.gold == 625, "War-trained horse should cost the source-derived 375 gold")
	var horse := simulation.get_character(String(horse_purchase.get("horse_id", "")))
	_check(horse != null and horse.mountable and horse.side == "neutral", "Purchased horse should register as a neutral owned mount")
	if horse != null:
		_check(not simulation.is_party_member(horse.id), "Purchased horse must not be added to the player character party roster")
	if horse != null:
		_check(horse.animal_attributes.get("coat_preset", "") == "chestnut", "Horse coat choice should persist in animal state")
		_check(horse.animal_attributes.get("training_tier", "") == "war_trained", "Horse training tier should persist in animal state")
		_check(String(horse.equipment.get("armour", "")) == "medium_barding", "War-trained horse should receive the source medium-barding fitting")
		_check(int(horse.skills.get("light_armor_training", 0)) == 1 and int(horse.skills.get("medium_armor_training", 0)) == 1, "War-trained horse should receive both source armour-training skills")
		_check(int(horse.skills.get("health", 0)) == 6 and horse.max_health == 70, "War-trained horse should receive two additional Health ranks")
		_check(int(horse.skills.get("meleeDamage", 0)) == 1, "War-trained horse should receive the source melee-damage training rank")
	var saved_simulation := simulation.to_dict()
	var restored_simulation := WorldSimulation.new()
	restored_simulation.load_dict(saved_simulation)
	var restored_horse := restored_simulation.get_character(String(horse_purchase.get("horse_id", "")))
	_check(restored_horse != null and restored_horse.animal_attributes.get("coat_preset", "") == "chestnut", "Purchased horse identity and coat should survive world save/load")
	if restored_horse != null:
		_check(String(restored_horse.equipment.get("armour", "")) == "medium_barding", "Purchased horse barding should survive world save/load")

	var untrained_buyer := CharacterState.new("untrained_buyer", "Untrained Buyer", Vector2i.ZERO)
	untrained_buyer.gold = 1000
	var untrained_simulation := WorldSimulation.new()
	untrained_simulation.register_character(untrained_buyer)
	_check(String(restored_services.purchase_horse(untrained_simulation, untrained_buyer.id, "brown", "untrained").get("reason", "")) == "riding_skill_required", "Stable must enforce the source Riding skill requirement")
	_check(untrained_buyer.gold == 1000, "Failed stable purchases must not debit gold")

	simulation.free()
	restored_simulation.free()
	untrained_simulation.free()
