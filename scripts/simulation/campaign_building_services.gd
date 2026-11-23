class_name CampaignBuildingServices
extends RefCounted
## Source-derived merchant transactions and commission state for Campaign 2.
## The owning campaign/save layer must persist this object's to_dict() payload.

const HORSE_BASE_PRICE := 150
const HORSE_COATS := ["brown", "black", "white", "chestnut", "gray"]
const HORSE_TIERS := {
	"untrained": {"price": 150, "barding": ""},
	"trained": {"price": 225, "barding": "light_barding"},
	"war_trained": {"price": 375, "barding": "medium_barding"}
}
const CLOTHING_BASE_PRICES := {
	"bra": 12, "briefs": 7, "long_tunic": 26, "trousers": 22,
	"tunic": 28, "wrapper_long": 22, "uniform_shirt": 26,
	"fatigue_pants": 22, "wrapper_knee": 18, "tattered_shirt": 26,
	"fatigue_shirt": 26, "sandals": 18, "combat_boots": 30
}
const COLOUR_PALETTE := [
	{"name": "Brown", "h": 28.0, "s": 62.0, "v": 48.0, "price": 1.0},
	{"name": "Cream", "h": 42.0, "s": 20.0, "v": 92.0, "price": 1.0},
	{"name": "Black", "h": 0.0, "s": 3.0, "v": 16.0, "price": 1.0},
	{"name": "White", "h": 0.0, "s": 0.0, "v": 98.0, "price": 1.0},
	{"name": "Charcoal", "h": 220.0, "s": 7.0, "v": 28.0, "price": 1.0},
	{"name": "Grey", "h": 210.0, "s": 8.0, "v": 58.0, "price": 1.0},
	{"name": "Navy", "h": 222.0, "s": 64.0, "v": 38.0, "price": 1.05},
	{"name": "Forest", "h": 122.0, "s": 50.0, "v": 38.0, "price": 1.05},
	{"name": "Rust", "h": 16.0, "s": 68.0, "v": 58.0, "price": 1.05},
	{"name": "Burgundy", "h": 345.0, "s": 58.0, "v": 42.0, "price": 1.08},
	{"name": "Blue", "h": 210.0, "s": 64.0, "v": 68.0, "price": 1.08},
	{"name": "Red", "h": 0.0, "s": 70.0, "v": 68.0, "price": 1.10},
	{"name": "Teal", "h": 178.0, "s": 58.0, "v": 55.0, "price": 1.10},
	{"name": "Purple", "h": 278.0, "s": 55.0, "v": 56.0, "price": 1.12},
	{"name": "Rose", "h": 338.0, "s": 46.0, "v": 76.0, "price": 1.14},
	{"name": "Gold", "h": 48.0, "s": 78.0, "v": 82.0, "price": 1.18},
	{"name": "Fuchsia", "h": 316.0, "s": 82.0, "v": 82.0, "price": 1.28}
]
const OPACITY_OPTIONS := [1.0, 0.94, 0.86, 0.74, 0.58, 0.38]
const METAL_TONES := [
	{"name": "Blackened steel", "value": 32.0, "price": 1.08},
	{"name": "Dark iron", "value": 48.0, "price": 1.0},
	{"name": "Steel", "value": 68.0, "price": 1.0},
	{"name": "Bright steel", "value": 82.0, "price": 1.06},
	{"name": "Polished steel", "value": 94.0, "price": 1.12}
]
const SERVICE_KINDS := {
	"silverhart_stables": "stable",
	"silverhart_general_goods": "general_goods",
	"silverhart_clothier": "clothier",
	"silverhart_magic_shop": "magic_shop",
	"silverhart_armourer": "armourer"
}
const GENERAL_GOODS := [
	"dagger", "sword", "axe", "club", "spear", "bow", "light_armor",
	"medium_armor", "heavy_armor", "nasal_helm", "torch", "wooden_shield",
	"pickaxe", "potion_health"
]
const MAGIC_GOODS := [
	"sword_arrow_deflection", "glowing_ring", "orcbane_pendant",
	"wolfward_charm", "undying_locket", "silvertongue_ring",
	"stormcaller_spear", "nightowl_bow", "featherweight_dagger",
	"bulwark_shield", "ashenwood_club", "travelers_cloakpin",
	"moonlit_armor", "huntsman_helm", "shadowcloak", "magic_backpack"
]
const CLOTHING_ITEMS := [
	"bra", "briefs", "long_tunic", "trousers", "tunic", "wrapper_long",
	"uniform_shirt", "fatigue_pants", "wrapper_knee", "tattered_shirt",
	"fatigue_shirt", "sandals", "combat_boots"
]
const ARMOUR_ITEMS := ["light_armor", "medium_armor", "heavy_armor"]

var daily_stock: Dictionary = {}
var commissions: Array[Dictionary] = []
var next_commission_id: int = 1
var next_item_instance_id: int = 1
var next_horse_id: int = 1


static func service_kind_for_building(building_id: String) -> String:
	return String(SERVICE_KINDS.get(building_id, ""))


func get_daily_stock(building_id: String, world_seconds: float) -> Array[Dictionary]:
	var kind := service_kind_for_building(building_id)
	if kind.is_empty() or kind == "stable":
		return []
	var day_index := maxi(0, int(floor(world_seconds / 86400.0)))
	var saved: Dictionary = daily_stock.get(building_id, {})
	if int(saved.get("day", -1)) == day_index:
		return _copy_stock(saved.get("entries", []))
	var entries: Array[Dictionary] = []
	var item_ids: Array = []
	match kind:
		"general_goods":
			item_ids = GENERAL_GOODS
		"magic_shop":
			item_ids = MAGIC_GOODS
		"clothier":
			item_ids = CLOTHING_ITEMS
		"armourer":
			item_ids = ARMOUR_ITEMS
	for item_id_value in item_ids:
		var item_id := String(item_id_value)
		var definition := ItemCatalog.get_definition(item_id)
		if definition.is_empty() or _base_item_price(item_id, definition) <= 0:
			continue
		var variant_count := 1
		if kind == "clothier":
			variant_count = 2
		elif kind == "armourer":
			variant_count = 3
		for variant_index in range(variant_count):
			var entry := _make_stock_entry(building_id, day_index, item_id, variant_index, kind)
			if not entry.is_empty():
				entries.append(entry)
	daily_stock[building_id] = {"day": day_index, "entries": entries.duplicate(true)}
	return _copy_stock(entries)


func purchase_stock(
	buyer: CharacterState,
	building_id: String,
	stock_id: String,
	world_seconds: float
) -> Dictionary:
	if buyer == null:
		return _failure("missing_buyer")
	get_daily_stock(building_id, world_seconds)
	var saved: Dictionary = daily_stock.get(building_id, {})
	var stored_entries: Array = saved.get("entries", [])
	for index in range(stored_entries.size()):
		var entry: Dictionary = stored_entries[index]
		if String(entry.get("stock_id", "")) != stock_id:
			continue
		var price := int(entry.get("price", 0))
		if price < 1:
			return _failure("invalid_price")
		if buyer.gold < price:
			return _failure("insufficient_gold", {"price": price})
		var instance := _create_styled_instance(
			String(entry.get("item_id", "")),
			String(entry.get("design_name", "")),
			entry.get("appearance", {}),
			"merchant_stock"
		)
		if instance.is_empty() or not buyer.add_inventory_item(instance):
			return _failure("inventory_rejected")
		buyer.gold -= price
		stored_entries.remove_at(index)
		daily_stock[building_id]["entries"] = stored_entries
		return {"ok": true, "item": instance.duplicate(true), "price": price}
	return _failure("stock_item_unavailable")


func place_commission(
	buyer: CharacterState,
	building_id: String,
	item_id: String,
	appearance: Dictionary,
	design_name: String,
	world_seconds: float
) -> Dictionary:
	if buyer == null:
		return _failure("missing_buyer")
	var kind := service_kind_for_building(building_id)
	var item := ItemCatalog.get_definition(item_id)
	if kind == "clothier" and String(item.get("type", "")) != "clothing":
		return _failure("clothier_requires_clothing")
	if kind == "armourer" and (String(item.get("type", "")) != "armor" or not (item_id in ARMOUR_ITEMS)):
		return _failure("armourer_requires_standard_armour")
	if kind != "clothier" and kind != "armourer":
		return _failure("commissions_unavailable")
	if item.is_empty():
		return _failure("unknown_item")
	var appearance_result := _validate_commission_appearance(kind, appearance)
	if not bool(appearance_result.get("ok", false)):
		return appearance_result
	var price := _commission_price(kind, item, appearance)
	if buyer.gold < price:
		return _failure("insufficient_gold", {"price": price})
	var lead_seconds := _commission_lead_seconds(kind, item)
	var order := {
		"commission_id": next_commission_id,
		"buyer_id": buyer.id,
		"building_id": building_id,
		"kind": kind,
		"item_id": item_id,
		"appearance": appearance.duplicate(true),
		"design_name": design_name.strip_edges().left(32) if not design_name.strip_edges().is_empty() else "Bespoke",
		"price": price,
		"placed_at": maxf(0.0, world_seconds),
		"ready_at": maxf(0.0, world_seconds) + lead_seconds,
		"collected": false
	}
	buyer.gold -= price
	next_commission_id += 1
	commissions.append(order)
	return {"ok": true, "commission": order.duplicate(true), "price": price, "lead_seconds": lead_seconds}


func collect_ready_commissions(buyer: CharacterState, world_seconds: float) -> Array[Dictionary]:
	var collected: Array[Dictionary] = []
	if buyer == null:
		return collected
	for index in range(commissions.size()):
		var order: Dictionary = commissions[index]
		if bool(order.get("collected", false)):
			continue
		if String(order.get("buyer_id", "")) != buyer.id or float(order.get("ready_at", INF)) > world_seconds:
			continue
		var instance := _create_styled_instance(
			String(order.get("item_id", "")),
			String(order.get("design_name", "")),
			order.get("appearance", {}),
			"bespoke_commission"
		)
		if instance.is_empty() or not buyer.add_inventory_item(instance):
			continue
		commissions[index]["collected"] = true
		collected.append(instance.duplicate(true))
	return collected


func purchase_horse(
	simulation: WorldSimulation,
	buyer_id: String,
	coat: String,
	training_tier: String
) -> Dictionary:
	if simulation == null:
		return _failure("missing_simulation")
	var buyer := simulation.get_character(buyer_id)
	if buyer == null:
		return _failure("unknown_buyer")
	if not (coat in HORSE_COATS):
		return _failure("invalid_horse_coat")
	if not HORSE_TIERS.has(training_tier):
		return _failure("invalid_training_tier")
	var party_can_ride := false
	var party_ids: Array = simulation.party_member_ids.duplicate()
	if buyer_id not in party_ids:
		party_ids.append(buyer_id)
	for member_id_value in party_ids:
		var member := simulation.get_character(String(member_id_value))
		if member == null:
			continue
		if int(member.skills.get("riding", 0)) > 0 or int(member.skills.get("riding_druid", 0)) > 0 or int(member.skills.get("riding_paladin", 0)) > 0:
			party_can_ride = true
			break
	if not party_can_ride:
		return _failure("riding_skill_required")
	var tier: Dictionary = HORSE_TIERS[training_tier]
	var price := int(tier.get("price", HORSE_BASE_PRICE))
	if buyer.gold < price:
		return _failure("insufficient_gold", {"price": price})
	var spawn_hex: Variant = _find_clear_neighbour(simulation, buyer.axial)
	if spawn_hex == null:
		return _failure("no_clear_spawn_hex")
	var horse_id := "owned_horse_%04d" % next_horse_id
	while simulation.characters.has(horse_id):
		next_horse_id += 1
		horse_id = "owned_horse_%04d" % next_horse_id
	var horse := AnimalCatalog.create_state("horse", horse_id, "Horse", spawn_hex, next_horse_id)
	if horse == null:
		return _failure("horse_profile_unavailable")
	horse.side = buyer.side
	horse.combat_dormant = true
	horse.tags.append("owned_mount")
	horse.animal_attributes["owner_character_id"] = buyer_id
	horse.animal_attributes["coat_preset"] = coat
	horse.animal_attributes["training_tier"] = training_tier
	var training_skills: Dictionary = {}
	match training_tier:
		"trained":
			training_skills = {"light_armor_training": 1, "health": 1}
		"war_trained":
			training_skills = {"light_armor_training": 1, "medium_armor_training": 1, "health": 2, "meleeDamage": 1}
	for skill_id_value in training_skills.keys():
		var skill_id := String(skill_id_value)
		horse.skills[skill_id] = int(horse.skills.get(skill_id, 0)) + int(training_skills[skill_id_value])
	horse.sync_skill_effects()
	var barding_id := String(tier.get("barding", ""))
	if not barding_id.is_empty():
		var barding := ItemCatalog.create_instance(barding_id, "%s_barding" % horse_id)
		barding["equipment_slot"] = "armour"
		if not horse.add_inventory_item(barding) or not horse.equip_inventory_item(String(barding.get("instance_id", ""))):
			return _failure("barding_setup_failed")
	var registration := simulation.register_animal(horse)
	if not bool(registration.get("ok", false)):
		return _failure(String(registration.get("reason", "horse_registration_failed")))
	buyer.gold -= price
	next_horse_id += 1
	return {
		"ok": true,
		"horse_id": horse_id,
		"coat": coat,
		"training_tier": training_tier,
		"price": price,
		"barding": barding_id,
		"spawn_hex": spawn_hex
	}


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"daily_stock": daily_stock.duplicate(true),
		"commissions": commissions.duplicate(true),
		"next_commission_id": next_commission_id,
		"next_item_instance_id": next_item_instance_id,
		"next_horse_id": next_horse_id
	}


func load_dict(data: Dictionary) -> void:
	daily_stock = data.get("daily_stock", {}).duplicate(true)
	commissions.clear()
	var saved_commissions: Variant = data.get("commissions", [])
	if saved_commissions is Array:
		for order in saved_commissions:
			if order is Dictionary and not bool(order.get("collected", false)):
				commissions.append(order.duplicate(true))
	next_commission_id = maxi(1, int(data.get("next_commission_id", 1)))
	next_item_instance_id = maxi(1, int(data.get("next_item_instance_id", 1)))
	next_horse_id = maxi(1, int(data.get("next_horse_id", 1)))


func _make_stock_entry(
	building_id: String,
	day_index: int,
	item_id: String,
	variant_index: int,
	service_kind: String
) -> Dictionary:
	var item := ItemCatalog.get_definition(item_id)
	var appearance: Dictionary = {}
	var design_name := "Standard"
	var price := _base_item_price(item_id, item)
	if service_kind == "clothier":
		appearance = _random_clothing_appearance(building_id, day_index, item_id, variant_index)
		design_name = _appearance_name(appearance, "clothing")
		price = maxi(1, int(round(float(price) * _appearance_price_multiplier(appearance))))
	elif service_kind == "armourer":
		appearance = _random_armour_appearance(building_id, day_index, item_id, variant_index)
		design_name = _appearance_name(appearance, "armour")
		price = maxi(1, int(round(float(price) * _appearance_price_multiplier(appearance))))
	return {
		"stock_id": "%s-%d-%s-%d" % [building_id, day_index, item_id, variant_index],
		"item_id": item_id,
		"design_name": design_name,
		"appearance": appearance,
		"price": price
	}


func _random_clothing_appearance(building_id: String, day_index: int, item_id: String, variant_index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash("%s|%d|%s|%d" % [building_id, day_index, item_id, variant_index]))
	var colour: Dictionary = COLOUR_PALETTE[rng.randi_range(0, COLOUR_PALETTE.size() - 1)].duplicate(true)
	var opacity := float(OPACITY_OPTIONS[rng.randi_range(0, OPACITY_OPTIONS.size() - 1)])
	return {"clothing": {"main": {"hue": colour.h, "saturation": colour.s, "value": colour.v, "opacity": opacity}}}


func _random_armour_appearance(building_id: String, day_index: int, item_id: String, variant_index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash("%s|%d|%s|%d" % [building_id, day_index, item_id, variant_index]))
	var metal: Dictionary = METAL_TONES[rng.randi_range(0, METAL_TONES.size() - 1)]
	var leather: Dictionary = COLOUR_PALETTE[rng.randi_range(0, COLOUR_PALETTE.size() - 1)]
	return {
		"armour": {
			"metal": {"hue": 210.0, "saturation": 8.0, "value": metal.value, "opacity": 1.0, "unlocked": false},
			"leather": {"hue": leather.h, "saturation": leather.s, "value": leather.v, "opacity": 1.0, "unlocked": true}
		}
	}


func _validate_commission_appearance(kind: String, appearance: Dictionary) -> Dictionary:
	var section_name := "clothing" if kind == "clothier" else "armour"
	var section: Variant = appearance.get(section_name, {})
	if not section is Dictionary or section.is_empty():
		return _failure("missing_appearance_layers")
	for layer_value in section.keys():
		var layer: Variant = section[layer_value]
		if not layer is Dictionary:
			return _failure("invalid_appearance_layer")
		var hue := float(layer.get("hue", -1.0))
		var saturation := float(layer.get("saturation", -1.0))
		var value := float(layer.get("value", -1.0))
		var opacity := float(layer.get("opacity", 1.0))
		if hue < 0.0 or hue > 360.0 or saturation < 0.0 or saturation > 100.0 or value < 0.0 or value > 100.0 or opacity < 0.38 or opacity > 1.0:
			return _failure("appearance_value_out_of_range")
		if kind == "armour" and String(layer_value) == "metal":
			var is_custom_metal := bool(layer.get("unlocked", false))
			if not is_custom_metal and (absf(hue - 210.0) > 0.1 or saturation > 12.0 or value < 20.0 or value > 100.0):
				return _failure("metal_finish_not_in_steel_palette")
	return {"ok": true}


func _base_item_price(item_id: String, item: Dictionary) -> int:
	var catalogue_price := int(item.get("buyPrice", 0))
	if catalogue_price > 0:
		return catalogue_price
	return int(CLOTHING_BASE_PRICES.get(item_id, 0))


func _commission_price(kind: String, item: Dictionary, appearance: Dictionary) -> int:
	var item_id := String(item.get("id", ""))
	var base_price := int(item.get("buyPrice", CLOTHING_BASE_PRICES.get(item_id, 20)))
	var price := int(round(float(base_price) * 1.55)) + (35 if kind == "armourer" else 15)
	var section_name := "clothing" if kind == "clothier" else "armour"
	var section: Dictionary = appearance.get(section_name, {})
	if kind == "clothier":
		for layer_value in section.values():
			var layer: Dictionary = layer_value
			var opacity := float(layer.get("opacity", 1.0))
			if opacity < 0.8:
				price += int(round((0.8 - opacity) * 50.0))
	else:
		var metal: Dictionary = section.get("metal", {})
		if bool(metal.get("unlocked", false)):
			price += maxi(300, int(round(float(base_price) * 3.5)))
	return price


func _commission_lead_seconds(kind: String, item: Dictionary) -> float:
	if kind == "armourer":
		var reduction := int(item.get("reduction", 0))
		return float(48 if reduction >= 3 else (36 if reduction >= 2 else 24)) * 3600.0
	var item_id := String(item.get("id", ""))
	if item_id in ["bra", "briefs"]:
		return 4.0 * 3600.0
	return 10.0 * 3600.0


func _create_styled_instance(item_id: String, design_name: String, appearance: Dictionary, provenance: String) -> Dictionary:
	var instance_id := "commerce_item_%06d" % next_item_instance_id
	var item := ItemCatalog.create_instance(item_id, instance_id)
	if item.is_empty():
		return {}
	item["appearance"] = appearance.duplicate(true)
	item["design_name"] = design_name
	item["provenance"] = provenance
	next_item_instance_id += 1
	return item


func _appearance_name(appearance: Dictionary, section_name: String) -> String:
	var section: Dictionary = appearance.get(section_name, {})
	var names: Array[String] = []
	for layer_key in section.keys():
		var layer: Dictionary = section[layer_key]
		if section_name == "armour" and String(layer_key) == "metal":
			continue
		var nearest := "Custom"
		var best_distance := INF
		for palette_value in COLOUR_PALETTE:
			var palette: Dictionary = palette_value
			var distance := absf(float(layer.get("hue", 0.0)) - float(palette.h)) + absf(float(layer.get("saturation", 0.0)) - float(palette.s)) + absf(float(layer.get("value", 0.0)) - float(palette.v))
			if distance < best_distance:
				best_distance = distance
				nearest = String(palette.name)
		names.append(nearest)
	var result := ""
	for name in names:
		if not result.is_empty():
			result += " / "
		result += name
	return result if not result.is_empty() else "Standard"


func _appearance_price_multiplier(appearance: Dictionary) -> float:
	var multiplier := 1.0
	for section_name in ["clothing", "armour"]:
		var section: Dictionary = appearance.get(section_name, {})
		for layer_value in section.values():
			var layer: Dictionary = layer_value
			for palette_value in COLOUR_PALETTE:
				var palette: Dictionary = palette_value
				if is_equal_approx(float(layer.get("hue", -1.0)), float(palette.h)) and is_equal_approx(float(layer.get("saturation", -1.0)), float(palette.s)) and is_equal_approx(float(layer.get("value", -1.0)), float(palette.v)):
					multiplier *= float(palette.price)
					break
			if float(layer.get("opacity", 1.0)) < 0.95:
				multiplier *= 1.0 + (1.0 - float(layer.get("opacity", 1.0))) * 0.28
	return multiplier


func _find_clear_neighbour(simulation: WorldSimulation, origin: Vector2i) -> Variant:
	for candidate in HexGrid.neighbors(origin):
		if not simulation.map_data.is_walkable(candidate):
			continue
		if simulation.occupied_hexes.has(candidate):
			continue
		return candidate
	return null


func _copy_stock(entries_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if entries_value is Array:
		for entry in entries_value:
			if entry is Dictionary:
				result.append(entry.duplicate(true))
	return result


func _failure(reason: String, details: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "reason": reason}
	result.merge(details, true)
	return result
