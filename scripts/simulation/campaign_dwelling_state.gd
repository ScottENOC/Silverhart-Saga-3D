class_name CampaignDwellingState
extends RefCounted
## Persistent ownership, restoration and improvement state for player dwellings.

const SITE_HEXES := {
	"crossroads_plot": Vector2i(13, 27),
	"abandoned_house": Vector2i(14, -176),
	"silverhart_palace": Vector2i(8, -496),
	"silverhart_manor": Vector2i(39, -502)
}
const SITE_RADII := {
	"crossroads_plot": 2,
	"abandoned_house": 2,
	"silverhart_palace": 3,
	"silverhart_manor": 2
}

const ACTIONS := {
	"build_crossroads_cottage": {
		"dwelling_id": "crossroads_cottage", "kind": "claim", "label": "Build the crossroads cottage", "required_site": "crossroads_plot",
		"layout_id": "cottage_one_room",
		"camp_profile": {"sleeping_capacity": 1, "warmth_bonus": 14.0, "security_bonus": 8.0, "comfort_bonus": 5.0}
	},
	"upgrade_country_house": {
		"dwelling_id": "crossroads_cottage", "kind": "upgrade", "label": "Expand the cottage into a country house",
		"requires_owned": "crossroads_cottage", "required_site": "crossroads_plot", "materials": {"wood": 6, "stone": 6}, "gold_alternative": 90,
		"layout_id": "country_house_three_room",
		"camp_profile": {"sleeping_capacity": 3, "warmth_bonus": 18.0, "security_bonus": 12.0, "comfort_bonus": 12.0}
	},
	"restore_abandoned_house": {
		"dwelling_id": "abandoned_house", "kind": "claim", "label": "Restore the abandoned house",
		"required_quest": "abandoned_house_cleared", "required_site": "abandoned_house", "materials": {"wood": 8, "stone": 8},
		"layout_id": "restored_roadside_house",
		"camp_profile": {"sleeping_capacity": 2, "warmth_bonus": 10.0, "security_bonus": 6.0, "comfort_bonus": 5.0}
	},
	"claim_silverhart_manor": {
		"dwelling_id": "silverhart_manor", "kind": "claim", "label": "Accept the Silverhart manor",
		"required_faction": "silverhart_kingdom", "minimum_standing": 60.0, "required_site": "silverhart_palace",
		"layout_id": "silverhart_manor_ruined",
		"camp_profile": {"sleeping_capacity": 0, "warmth_bonus": 0.0, "security_bonus": 0.0, "comfort_bonus": 0.0}
	},
	"fortify_silverhart_manor": {
		"dwelling_id": "silverhart_manor", "kind": "upgrade", "label": "Fortify the Silverhart manor",
		"requires_owned": "silverhart_manor", "required_site": "silverhart_manor", "materials": {"wood": 10, "stone": 10},
		"layout_id": "silverhart_manor_livable",
		"camp_profile": {"sleeping_capacity": 8, "warmth_bonus": 20.0, "security_bonus": 18.0, "comfort_bonus": 18.0}
	}
}

var owned: Dictionary = {}
var upgrades: Dictionary = {}


func is_at_site(site_id: String, player_hex: Vector2i) -> bool:
	if not SITE_HEXES.has(site_id):
		return false
	var target: Vector2i = SITE_HEXES[site_id]
	var distance := (absi(player_hex.x - target.x) + absi(player_hex.y - target.y) + absi(player_hex.x + player_hex.y - target.x - target.y)) / 2
	return distance <= int(SITE_RADII.get(site_id, 2))


func action_definition(action_id: String) -> Dictionary:
	return (ACTIONS.get(action_id, {}) as Dictionary).duplicate(true)


func requirements_for_action(action_id: String, journal: CampaignJournal, player: CharacterState, payment: String = "materials", site_id: String = "") -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	var definition := action_definition(action_id)
	if definition.is_empty():
		requirements.append({"id": "known_action", "label": "Known construction option", "met": false, "reason": "unknown_action"})
		return requirements
	if player == null:
		requirements.append({"id": "player_available", "label": "Active player inventory", "met": false, "reason": "missing_player"})
	if journal == null:
		requirements.append({"id": "journal_available", "label": "Campaign journal", "met": false, "reason": "missing_journal"})
	var dwelling_id := String(definition.get("dwelling_id", ""))
	var kind := String(definition.get("kind", ""))
	if kind == "claim" and bool(owned.get(dwelling_id, false)):
		requirements.append({"id": "not_owned", "label": "Not already owned", "met": false, "reason": "already_owned"})
	if kind == "upgrade" and String(upgrades.get(dwelling_id, "")) == action_id:
		requirements.append({"id": "not_upgraded", "label": "Not already improved", "met": false, "reason": "already_upgraded"})
	var required_site := String(definition.get("required_site", ""))
	if not required_site.is_empty():
		requirements.append({"id": "site:" + required_site, "label": "Be at " + required_site.replace("_", " "), "met": site_id == required_site, "reason": "wrong_dwelling_site", "required_site": required_site, "current": site_id})
	var required_owned := String(definition.get("requires_owned", ""))
	if not required_owned.is_empty():
		var has_prerequisite := bool(owned.get(required_owned, false))
		requirements.append({"id": "owned:" + required_owned, "label": "Own " + required_owned.replace("_", " "), "met": has_prerequisite, "reason": "prerequisite_dwelling_not_owned", "required_dwelling": required_owned})
	var required_quest := String(definition.get("required_quest", ""))
	if not required_quest.is_empty():
		var quest_status := String(journal.quest_state(required_quest).get("status", "")) if journal != null else ""
		var quest_complete := quest_status == "completed"
		requirements.append({"id": "quest:" + required_quest, "label": "Complete " + required_quest.replace("_", " "), "met": quest_complete, "reason": "required_quest_incomplete", "required_quest": required_quest, "current": quest_status, "required": "completed"})
	var required_faction := String(definition.get("required_faction", ""))
	if not required_faction.is_empty():
		var required_standing := float(definition.get("minimum_standing", 0.0))
		var current_standing := journal.faction_standing(required_faction) if journal != null else 0.0
		requirements.append({"id": "reputation:" + required_faction, "label": required_faction.replace("_", " ").capitalize() + " reputation", "met": current_standing >= required_standing, "reason": "insufficient_reputation", "required_faction": required_faction, "current": current_standing, "required": required_standing})
	var materials: Dictionary = definition.get("materials", {})
	if not materials.is_empty():
		if payment == "materials":
			var missing := _missing_materials(player, materials)
			requirements.append({"id": "payment:materials", "label": "Gathered materials", "met": missing.is_empty(), "reason": "insufficient_materials", "required": materials.duplicate(true), "missing": missing})
		elif payment == "gold":
			var gold_cost := int(definition.get("gold_alternative", -1))
			var gold_valid := gold_cost >= 0
			var current_gold := player.gold if player != null else 0
			requirements.append({"id": "payment:gold", "label": "Gold payment", "met": gold_valid and current_gold >= gold_cost, "reason": "gold_not_accepted" if not gold_valid else "insufficient_gold", "current": current_gold, "required": gold_cost})
		else:
			requirements.append({"id": "payment:method", "label": "Valid payment method", "met": false, "reason": "unknown_payment_method"})
	return requirements


func evaluate_action(action_id: String, journal: CampaignJournal, player: CharacterState, payment: String = "materials", site_id: String = "") -> Dictionary:
	var definition := action_definition(action_id)
	var requirements := requirements_for_action(action_id, journal, player, payment, site_id)
	for requirement in requirements:
		if not bool(requirement.get("met", false)):
			return {"ok": false, "reason": String(requirement.get("reason", "requirements_not_met")), "requirements": requirements, "failed_requirement": requirement.duplicate(true)}
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_action", "requirements": requirements}
	return {
		"ok": true,
		"action_id": action_id,
		"dwelling_id": String(definition.get("dwelling_id", "")),
		"kind": String(definition.get("kind", "")),
		"materials": (definition.get("materials", {}) as Dictionary).duplicate(true),
		"gold_alternative": int(definition.get("gold_alternative", -1)),
		"payment": payment,
		"requirements": requirements,
		"layout_id": String(definition.get("layout_id", ""))
	}

func complete_action(action_id: String, journal: CampaignJournal, player: CharacterState, payment: String = "materials", site_id: String = "") -> Dictionary:
	var availability := evaluate_action(action_id, journal, player, payment, site_id)
	if not bool(availability.get("ok", false)):
		return availability
	var definition := action_definition(action_id)
	var materials: Dictionary = definition.get("materials", {})
	if not materials.is_empty():
		if payment == "gold":
			var gold_cost := int(definition.get("gold_alternative", -1))
			if gold_cost < 0:
				return {"ok": false, "reason": "gold_not_accepted"}
			if player == null or player.gold < gold_cost:
				return {"ok": false, "reason": "insufficient_gold", "gold_required": gold_cost}
			player.gold -= gold_cost
		elif payment == "materials":
			var missing := _missing_materials(player, materials)
			if not missing.is_empty():
				return {"ok": false, "reason": "insufficient_materials", "missing_materials": missing}
			_consume_materials(player, materials)
		else:
			return {"ok": false, "reason": "unknown_payment_method"}
	var dwelling_id := String(definition.get("dwelling_id", ""))
	if String(definition.get("kind", "")) == "claim":
		owned[dwelling_id] = true
	else:
		upgrades[dwelling_id] = action_id
	return {"ok": true, "action_id": action_id, "dwelling_id": dwelling_id, "layout_id": String(definition.get("layout_id", "")), "payment": payment}


func camp_profile_for(dwelling_id: String) -> Dictionary:
	if not bool(owned.get(dwelling_id, false)):
		return {}
	var action_id := ""
	match dwelling_id:
		"crossroads_cottage":
			action_id = "upgrade_country_house" if String(upgrades.get(dwelling_id, "")) == "upgrade_country_house" else "build_crossroads_cottage"
		"abandoned_house":
			action_id = "restore_abandoned_house"
		"silverhart_manor":
			action_id = "fortify_silverhart_manor" if String(upgrades.get(dwelling_id, "")) == "fortify_silverhart_manor" else "claim_silverhart_manor"
		_:
			return {}
	var definition := action_definition(action_id)
	var profile: Dictionary = definition.get("camp_profile", {}).duplicate(true)
	profile["dwelling_id"] = dwelling_id
	profile["layout_id"] = String(definition.get("layout_id", ""))
	profile["is_sheltered"] = int(profile.get("sleeping_capacity", 0)) > 0
	return profile


func property_snapshot(journal: CampaignJournal, player: CharacterState) -> Array[Dictionary]:
	var properties: Array[Dictionary] = [
		{"id": "crossroads_cottage", "name": "Crossroads cottage", "location": "Surveyed starting plot at (13, 27), five q-steps and three r-steps from the crossroads", "site_id": "crossroads_plot", "site_hex": Vector2i(13, 27), "layout_id": String(camp_profile_for("crossroads_cottage").get("layout_id", "cottage_one_room")), "owned": bool(owned.get("crossroads_cottage", false)), "actions": ["build_crossroads_cottage", "upgrade_country_house"]},
		{"id": "abandoned_house", "name": "Abandoned roadside house", "location": "North road, at (14, -176)", "site_id": "abandoned_house", "site_hex": Vector2i(14, -176), "layout_id": String(camp_profile_for("abandoned_house").get("layout_id", "")), "owned": bool(owned.get("abandoned_house", false)), "actions": ["restore_abandoned_house"]},
		{"id": "silverhart_manor", "name": "Silverhart manor", "location": "Corstane townhouse in the Silverhart Noble Quarter at (39, -502)", "site_id": "silverhart_manor", "site_hex": Vector2i(39, -502), "grant_site_id": "silverhart_palace", "grant_site_hex": Vector2i(8, -496), "layout_id": String(camp_profile_for("silverhart_manor").get("layout_id", "")), "owned": bool(owned.get("silverhart_manor", false)), "actions": ["claim_silverhart_manor", "fortify_silverhart_manor"]}
	]
	for property in properties:
		property["camp_profile"] = camp_profile_for(String(property.id))
		var action_statuses: Array[Dictionary] = []
		for action_id_value in property.actions:
			var action_id := String(action_id_value)
			var definition := action_definition(action_id)
			var payment_options: Array[Dictionary] = []
			var payment_methods: Array[String] = ["materials"]
			if int(definition.get("gold_alternative", -1)) >= 0:
				payment_methods.append("gold")
			var preferred_payment := "materials"
			var action_ready := false
			var required_site := String(definition.get("required_site", ""))
			var interaction_site := required_site if player != null and is_at_site(required_site, player.axial) else ""
			for payment_method in payment_methods:
				var payment_status := evaluate_action(action_id, journal, player, payment_method, interaction_site)
				payment_status["payment"] = payment_method
				payment_options.append(payment_status)
				if bool(payment_status.get("ok", false)) and not action_ready:
					preferred_payment = payment_method
					action_ready = true
			var action_status := evaluate_action(action_id, journal, player, preferred_payment, interaction_site)
			action_status["label"] = String(definition.get("label", action_id))
			action_status["preferred_payment"] = preferred_payment
			action_status["payment_options"] = payment_options
			action_statuses.append(action_status)
		property["action_statuses"] = action_statuses
	return properties

func _missing_materials(player: CharacterState, costs: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	if player == null:
		return costs.duplicate(true)
	for item_id_value in costs.keys():
		var item_id := String(item_id_value)
		var required := int(costs[item_id_value])
		var available := 0
		for item in player.inventory:
			if String(item.get("id", "")) == item_id:
				available += int(item.get("quantity", 1))
		if available < required:
			missing[item_id] = required - available
	return missing


func _consume_materials(player: CharacterState, costs: Dictionary) -> void:
	for item_id_value in costs.keys():
		var item_id := String(item_id_value)
		var remaining := int(costs[item_id_value])
		for index in range(player.inventory.size() - 1, -1, -1):
			if remaining <= 0:
				break
			var item: Dictionary = player.inventory[index]
			if String(item.get("id", "")) != item_id:
				continue
			var quantity := int(item.get("quantity", 1))
			var consumed := mini(quantity, remaining)
			if consumed == quantity:
				player.inventory.remove_at(index)
			else:
				player.inventory[index]["quantity"] = quantity - consumed
			remaining -= consumed


func to_dict() -> Dictionary:
	return {"owned": owned.duplicate(true), "upgrades": upgrades.duplicate(true)}


func from_dict(data: Dictionary) -> bool:
	var saved_owned: Variant = data.get("owned", {})
	var saved_upgrades: Variant = data.get("upgrades", {})
	if not saved_owned is Dictionary or not saved_upgrades is Dictionary:
		return false
	for dwelling_id_value in saved_owned.keys():
		var known_dwelling := false
		for definition_value in ACTIONS.values():
			if String((definition_value as Dictionary).get("dwelling_id", "")) == String(dwelling_id_value):
				known_dwelling = true
				break
		if not known_dwelling or not bool(saved_owned[dwelling_id_value]):
			return false
	for dwelling_id_value in saved_upgrades.keys():
		var dwelling_id := String(dwelling_id_value)
		var action_id := String(saved_upgrades[dwelling_id_value])
		var definition := action_definition(action_id)
		if definition.is_empty() or String(definition.get("dwelling_id", "")) != dwelling_id or String(definition.get("kind", "")) != "upgrade" or not bool(saved_owned.get(dwelling_id, false)):
			return false
	owned = saved_owned.duplicate(true)
	upgrades = saved_upgrades.duplicate(true)
	return true
