class_name CampaignDwellingState
extends RefCounted
## Persistent ownership, restoration and improvement state for player dwellings.

const ACTIONS := {
	"build_crossroads_cottage": {
		"dwelling_id": "crossroads_cottage", "kind": "claim", "label": "Build the crossroads cottage",
		"layout_id": "cottage_one_room",
		"camp_profile": {"sleeping_capacity": 1, "warmth_bonus": 14.0, "security_bonus": 8.0, "comfort_bonus": 5.0}
	},
	"upgrade_country_house": {
		"dwelling_id": "crossroads_cottage", "kind": "upgrade", "label": "Expand the cottage into a country house",
		"requires_owned": "crossroads_cottage", "materials": {"wood": 6, "stone": 6}, "gold_alternative": 90,
		"layout_id": "country_house_three_room",
		"camp_profile": {"sleeping_capacity": 3, "warmth_bonus": 18.0, "security_bonus": 12.0, "comfort_bonus": 12.0}
	},
	"restore_abandoned_house": {
		"dwelling_id": "abandoned_house", "kind": "claim", "label": "Restore the abandoned house",
		"required_quest": "abandoned_house_cleared", "materials": {"wood": 8, "stone": 8},
		"layout_id": "restored_roadside_house",
		"camp_profile": {"sleeping_capacity": 2, "warmth_bonus": 10.0, "security_bonus": 6.0, "comfort_bonus": 5.0}
	},
	"claim_silverhart_manor": {
		"dwelling_id": "silverhart_manor", "kind": "claim", "label": "Accept the Silverhart manor",
		"required_faction": "silverhart_kingdom", "minimum_standing": 60.0,
		"layout_id": "silverhart_manor_ruined",
		"camp_profile": {"sleeping_capacity": 0, "warmth_bonus": 0.0, "security_bonus": 0.0, "comfort_bonus": 0.0}
	},
	"fortify_silverhart_manor": {
		"dwelling_id": "silverhart_manor", "kind": "upgrade", "label": "Fortify the Silverhart manor",
		"requires_owned": "silverhart_manor", "materials": {"wood": 10, "stone": 10},
		"layout_id": "silverhart_manor_livable",
		"camp_profile": {"sleeping_capacity": 8, "warmth_bonus": 20.0, "security_bonus": 18.0, "comfort_bonus": 18.0}
	}
}

var owned: Dictionary = {}
var upgrades: Dictionary = {}


func action_definition(action_id: String) -> Dictionary:
	return (ACTIONS.get(action_id, {}) as Dictionary).duplicate(true)


func evaluate_action(action_id: String, journal: CampaignJournal, player: CharacterState) -> Dictionary:
	var definition := action_definition(action_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_action"}
	var dwelling_id := String(definition.get("dwelling_id", ""))
	if String(definition.get("kind", "")) == "claim" and bool(owned.get(dwelling_id, false)):
		return {"ok": false, "reason": "already_owned"}
	if String(definition.get("kind", "")) == "upgrade" and String(upgrades.get(dwelling_id, "")) == action_id:
		return {"ok": false, "reason": "already_upgraded"}
	var required_owned := String(definition.get("requires_owned", ""))
	if not required_owned.is_empty() and not bool(owned.get(required_owned, false)):
		return {"ok": false, "reason": "prerequisite_dwelling_not_owned", "required_dwelling": required_owned}
	var required_quest := String(definition.get("required_quest", ""))
	if not required_quest.is_empty() and (journal == null or String(journal.quest_state(required_quest).get("status", "")) != "completed"):
		return {"ok": false, "reason": "required_quest_incomplete", "required_quest": required_quest}
	var required_faction := String(definition.get("required_faction", ""))
	if not required_faction.is_empty() and (journal == null or journal.faction_standing(required_faction) < float(definition.get("minimum_standing", 0.0))):
		return {"ok": false, "reason": "insufficient_reputation", "required_faction": required_faction, "minimum_standing": float(definition.get("minimum_standing", 0.0))}
	var materials: Dictionary = definition.get("materials", {})
	var missing := _missing_materials(player, materials)
	var gold_cost := int(definition.get("gold_alternative", -1))
	var can_pay_gold := gold_cost >= 0 and player != null and player.gold >= gold_cost
	var can_pay_materials := missing.is_empty() and not materials.is_empty()
	if not materials.is_empty() and not can_pay_materials and not can_pay_gold:
		return {"ok": false, "reason": "insufficient_materials_or_gold" if gold_cost >= 0 else "insufficient_materials", "missing_materials": missing, "gold_required": gold_cost}
	return {"ok": true, "action_id": action_id, "dwelling_id": dwelling_id, "kind": String(definition.get("kind", "")), "materials": materials.duplicate(true), "gold_alternative": gold_cost, "can_pay_materials": can_pay_materials, "can_pay_gold": can_pay_gold, "layout_id": String(definition.get("layout_id", ""))}


func complete_action(action_id: String, journal: CampaignJournal, player: CharacterState, payment: String = "materials") -> Dictionary:
	var availability := evaluate_action(action_id, journal, player)
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
