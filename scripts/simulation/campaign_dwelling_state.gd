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
	"silverhart_manor": 3
}

const ACTIONS := {
	"build_crossroads_cottage": {
		"dwelling_id": "crossroads_cottage", "kind": "claim", "label": "Build the crossroads cottage", "required_site": "crossroads_plot",
		"layout_id": "cottage_one_room",
		"camp_profile": {"warmth_bonus": 14.0, "security_bonus": 8.0, "comfort_bonus": 5.0}
	},
	"upgrade_country_house": {
		"dwelling_id": "crossroads_cottage", "kind": "upgrade", "label": "Expand the cottage into a country house",
		"requires_owned": "crossroads_cottage", "required_site": "crossroads_plot", "materials": {"wood": 6, "stone": 6}, "gold_alternative": 90,
		"layout_id": "country_house_three_room",
		"camp_profile": {"warmth_bonus": 18.0, "security_bonus": 12.0, "comfort_bonus": 12.0}
	},
	"restore_abandoned_house": {
		"dwelling_id": "abandoned_house", "kind": "claim", "label": "Restore the abandoned house",
		"required_quest": "abandoned_house_cleared", "required_site": "abandoned_house", "materials": {"wood": 8, "stone": 8},
		"layout_id": "restored_roadside_house",
		"camp_profile": {"warmth_bonus": 10.0, "security_bonus": 6.0, "comfort_bonus": 5.0}
	},
	"claim_silverhart_manor": {
		"dwelling_id": "silverhart_manor", "kind": "claim", "label": "Accept the Silverhart manor",
		"required_faction": "silverhart_kingdom", "minimum_standing": 60.0, "required_site": "silverhart_palace",
		"layout_id": "silverhart_manor_ruined",
		"camp_profile": {"warmth_bonus": 0.0, "security_bonus": 0.0, "comfort_bonus": 0.0}
	},
	"fortify_silverhart_manor": {
		"dwelling_id": "silverhart_manor", "kind": "upgrade", "label": "Fortify the Silverhart manor",
		"requires_owned": "silverhart_manor", "required_site": "silverhart_manor", "materials": {"wood": 10, "stone": 10},
		"layout_id": "silverhart_manor_livable",
		"camp_profile": {"warmth_bonus": 20.0, "security_bonus": 18.0, "comfort_bonus": 18.0}
	}
}

var owned: Dictionary = {}
var upgrades: Dictionary = {}
## Furniture is owned separately from the building and starts empty for every dwelling.
var furniture_inventory: Dictionary = {}
## Each placed entry stores a stable instance ID, catalogue ID, local floor position and rotation.
var placed_furniture: Dictionary = {}
## Non-companion NPCs assigned to a permanent household. Companions remain part of the camp roster.
## Keys are character IDs; values contain dwelling ID, household role and authored routine data.
var residents: Dictionary = {}
var next_furniture_instance_id: int = 1

const FLOOR_SIZES := {
	"crossroads_cottage": Vector2(5.8, 4.8),
	"country_house": Vector2(8.2, 6.4),
	"abandoned_house": Vector2(7.2, 5.8),
	"silverhart_manor": Vector2(10.0, 8.0)
}
const FLOOR_COUNTS := {
	"crossroads_cottage": 1,
	"country_house": 2,
	"abandoned_house": 1,
	"silverhart_manor": 2
}


func site_id_for_dwelling(dwelling_id: String) -> String:
	match dwelling_id:
		"crossroads_cottage":
			return "crossroads_plot"
		"abandoned_house":
			return "abandoned_house"
		"silverhart_manor":
			return "silverhart_manor"
	return ""


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
	profile["sleeping_capacity"] = sleeping_capacity_for(dwelling_id)
	# A restored house shelters its occupants even before the player furnishes it.
	profile["is_sheltered"] = not (dwelling_id == "silverhart_manor" and action_id == "claim_silverhart_manor")
	profile["floor_size"] = floor_size_for(dwelling_id)
	profile["floor_count"] = floor_count_for(dwelling_id)
	var floor_size: Vector2 = profile["floor_size"]
	profile["floor_area_m2"] = floor_size.x * floor_size.y * float(profile["floor_count"])
	profile["indoor_floor_capacity"] = floori(float(profile["floor_area_m2"]) / 8.0) if bool(profile["is_sheltered"]) else 0
	profile["placed_furniture"] = (placed_furniture.get(dwelling_id, []) as Array).duplicate(true)
	return profile





const RESIDENT_DAY_ACTIVITIES: Array[String] = ["study_map", "repair_gear", "train", "watch", "socialise", "cook", "housekeeping", "manage_stores", "welcome_guests"]
const RESIDENT_STATION_ROLES := {
	"wake": "bedroom", "breakfast": "table", "study_map": "study",
	"repair_gear": "workshop", "train": "yard", "watch": "threshold",
	"socialise": "common", "sleep": "bedroom", "cook": "hearth",
	"housekeeping": "common", "manage_stores": "common", "welcome_guests": "threshold"
}
const HALVARD_ID := "steward_halvard_greer"
const HALVARD_DUTIES: Array[String] = ["cook", "housekeeping", "manage_stores", "welcome_guests"]


## Capacity follows the same bed-plus-floor sleeping model used by camp lodging.
## Residents are not party members and do not consume a party slot.
func resident_capacity_for(dwelling_id: String) -> int:
	var profile := camp_profile_for(dwelling_id)
	if profile.is_empty() or not bool(profile.get("is_sheltered", false)):
		return 0
	return maxi(0, int(profile.get("sleeping_capacity", 0))) + maxi(0, int(profile.get("indoor_floor_capacity", 0)))


func assign_resident(dwelling_id: String, character_id: String, character_profile: Dictionary = {}) -> Dictionary:
	var clean_id := character_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "reason": "missing_character_id"}
	if _is_companion_character_id(clean_id):
		return {"ok": false, "reason": "companions_belong_to_camp_roster"}
	var profile := camp_profile_for(dwelling_id)
	if profile.is_empty():
		return {"ok": false, "reason": "dwelling_not_owned"}
	if not bool(profile.get("is_sheltered", false)):
		return {"ok": false, "reason": "dwelling_not_livable"}
	var existing: Dictionary = residents.get(clean_id, {})
	if String(existing.get("dwelling_id", "")) == dwelling_id:
		return {"ok": true, "already_assigned": true, "resident": existing.duplicate(true)}
	var capacity := resident_capacity_for(dwelling_id)
	var current_count := resident_ids_for_dwelling(dwelling_id).size()
	if capacity <= current_count:
		return {"ok": false, "reason": "residence_at_capacity", "capacity": capacity, "resident_count": current_count}
	var preferred_activity := _preferred_resident_activity(character_profile)
	var resident := {
		"character_id": clean_id,
		"dwelling_id": dwelling_id,
		"preferred_activity": preferred_activity,
		"household_role": String(character_profile.get("household_role", "resident")),
		"duties": (character_profile.get("duties", []) as Array).duplicate(true)
	}
	residents[clean_id] = resident
	return {"ok": true, "resident": resident.duplicate(true), "capacity": capacity, "resident_count": current_count + 1}


## Halvard is a household steward, not a recruitable companion. His appointment
## is tied to a livable Silverhart manor and persists independently of the party.
func appoint_halvard_as_steward() -> Dictionary:
	return assign_resident("silverhart_manor", HALVARD_ID, {
		"household_role": "steward",
		"preferred_activity": "cook",
		"duties": HALVARD_DUTIES
	})


func remove_resident(character_id: String) -> Dictionary:
	var clean_id := character_id.strip_edges()
	if not residents.has(clean_id):
		return {"ok": false, "reason": "resident_not_found"}
	var previous: Dictionary = residents[clean_id].duplicate(true)
	residents.erase(clean_id)
	return {"ok": true, "resident": previous}


func resident_ids_for_dwelling(dwelling_id: String) -> Array[String]:
	var ids: Array[String] = []
	for character_id_value in residents:
		var record: Dictionary = residents[character_id_value]
		if String(record.get("dwelling_id", "")) == dwelling_id:
			ids.append(String(character_id_value))
	ids.sort()
	return ids


## Return the current home routine for a resident. The caller supplies local
## world-clock hour and current party IDs; joining the party temporarily
## suspends the home schedule without deleting the permanent residence.
func resident_schedule_for(character_id: String, local_hour: float, party_ids: Array = []) -> Dictionary:
	if not residents.has(character_id):
		return {}
	var resident: Dictionary = residents[character_id]
	if party_ids.has(character_id):
		return {"activity": "travelling_with_party", "station_role": "none", "dwelling_id": String(resident.get("dwelling_id", ""))}
	var hour := fposmod(local_hour, 24.0)
	var activity := "socialise"
	if String(resident.get("household_role", "")) == "steward":
		if hour < 6.0 or hour >= 21.0:
			activity = "sleep"
		elif hour < 7.0:
			activity = "wake"
		elif hour < 9.0:
			activity = "cook"
		elif hour < 12.0:
			activity = "housekeeping"
		elif hour < 14.0:
			activity = "manage_stores"
		elif hour < 17.0:
			activity = "welcome_guests"
		elif hour < 19.0:
			activity = "cook"
	else:
		if hour < 6.0 or hour >= 21.0:
			activity = "sleep"
		elif hour < 7.0:
			activity = "wake"
		elif hour < 9.0:
			activity = "breakfast"
		elif hour < 17.0:
			activity = String(resident.get("preferred_activity", "socialise"))
	var station_role := String(RESIDENT_STATION_ROLES.get(activity, "common"))
	return {
		"activity": activity,
		"station_role": station_role,
		"dwelling_id": String(resident.get("dwelling_id", "")),
		"household_role": String(resident.get("household_role", "resident")),
		"duties": (resident.get("duties", []) as Array).duplicate(true)
	}


func _is_companion_character_id(character_id: String) -> bool:
	return CompanionCampaignContent.is_companion_id(character_id) or CompanionRelationshipState.PROFILES.has(character_id) or character_id == "companion_wren_talbot"


func _preferred_resident_activity(character_profile: Dictionary) -> String:
	var requested := String(character_profile.get("preferred_activity", ""))
	if RESIDENT_DAY_ACTIVITIES.has(requested):
		return requested
	var tags: Variant = character_profile.get("personality_tags", character_profile.get("tags", []))
	if tags is Array:
		if tags.has("scholarly"):
			return "study_map"
		if tags.has("practical"):
			return "repair_gear"
		if tags.has("guardian"):
			return "watch"
	return "socialise"


func _layout_key_for(dwelling_id: String) -> String:
	if dwelling_id == "crossroads_cottage" and String(upgrades.get(dwelling_id, "")) == "upgrade_country_house":
		return "country_house"
	return dwelling_id


func floor_count_for(dwelling_id: String) -> int:
	return int(FLOOR_COUNTS.get(_layout_key_for(dwelling_id), 0))


func floor_size_for(dwelling_id: String, floor_index: int = 0) -> Vector2:
	if floor_index < 0 or floor_index >= floor_count_for(dwelling_id):
		return Vector2.ZERO
	return FLOOR_SIZES.get(_layout_key_for(dwelling_id), Vector2.ZERO)


func furniture_inventory_count(item_id: String) -> int:
	return int(furniture_inventory.get(item_id, 0))


func sleeping_capacity_for(dwelling_id: String) -> int:
	var capacity := 0
	for placed_value in placed_furniture.get(dwelling_id, []):
		if not placed_value is Dictionary:
			continue
		var definition := CampaignFurnitureCatalog.definition(String(placed_value.get("item_id", "")))
		capacity += int(definition.get("sleeping_capacity", 0))
	return capacity


func buy_furniture(item_id: String, player: CharacterState, shop_id: String, actor_hex: Vector2i, quantity: int = 1) -> Dictionary:
	if player == null or quantity < 1:
		return {"ok": false, "reason": "invalid_purchase"}
	if shop_id != CampaignFurnitureCatalog.SHOP_ID or not is_at_site("silverhart_palace", actor_hex):
		return {"ok": false, "reason": "not_at_furniture_shop"}
	var definition := CampaignFurnitureCatalog.definition(item_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_furniture"}
	var total_cost := int(definition.get("price", 0)) * quantity
	if total_cost <= 0 or player.gold < total_cost:
		return {"ok": false, "reason": "insufficient_gold", "required_gold": total_cost, "current_gold": player.gold}
	player.gold -= total_cost
	furniture_inventory[item_id] = furniture_inventory_count(item_id) + quantity
	return {"ok": true, "item_id": item_id, "quantity": quantity, "gold_spent": total_cost}


func craft_furniture(item_id: String, player: CharacterState, dwelling_id: String, actor_hex: Vector2i) -> Dictionary:
	if player == null or not bool(owned.get(dwelling_id, false)):
		return {"ok": false, "reason": "dwelling_not_owned"}
	var site_id := site_id_for_dwelling(dwelling_id)
	if site_id.is_empty() or not is_at_site(site_id, actor_hex):
		return {"ok": false, "reason": "not_at_dwelling"}
	var definition := CampaignFurnitureCatalog.definition(item_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_furniture"}
	var recipe: Dictionary = definition.get("materials", {})
	var missing := _missing_materials(player, recipe)
	if not missing.is_empty():
		return {"ok": false, "reason": "insufficient_materials", "missing_materials": missing}
	_consume_materials(player, recipe)
	furniture_inventory[item_id] = furniture_inventory_count(item_id) + 1
	return {"ok": true, "item_id": item_id, "quantity": 1, "materials_spent": recipe.duplicate(true)}


func place_furniture(dwelling_id: String, item_id: String, local_position: Vector2, rotation_degrees: int, actor_hex: Vector2i, floor_index: int = 0) -> Dictionary:
	if not bool(owned.get(dwelling_id, false)):
		return {"ok": false, "reason": "dwelling_not_owned"}
	var site_id := site_id_for_dwelling(dwelling_id)
	if site_id.is_empty() or not is_at_site(site_id, actor_hex):
		return {"ok": false, "reason": "not_at_dwelling"}
	if furniture_inventory_count(item_id) <= 0:
		return {"ok": false, "reason": "furniture_not_owned"}
	var definition := CampaignFurnitureCatalog.definition(item_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_furniture"}
	if not [0, 90, 180, 270].has(posmod(rotation_degrees, 360)):
		return {"ok": false, "reason": "invalid_rotation"}
	var position := Vector2(snappedf(local_position.x, 0.25), snappedf(local_position.y, 0.25))
	var footprint: Vector2 = definition.get("footprint", Vector2.ONE)
	if posmod(rotation_degrees, 180) == 90:
		footprint = Vector2(footprint.y, footprint.x)
	var candidate := Rect2(position - footprint * 0.5, footprint)
	var floor_size := floor_size_for(dwelling_id, floor_index)
	if floor_size == Vector2.ZERO:
		return {"ok": false, "reason": "invalid_floor"}
	var floor_bounds := Rect2(-floor_size * 0.5, floor_size)
	if not floor_bounds.encloses(candidate):
		return {"ok": false, "reason": "outside_floor_bounds", "floor_size": floor_size}
	for existing_value in placed_furniture.get(dwelling_id, []):
		if not existing_value is Dictionary or int(existing_value.get("floor_index", 0)) != floor_index:
			continue
		var existing_definition := CampaignFurnitureCatalog.definition(String(existing_value.get("item_id", "")))
		var existing_footprint: Vector2 = existing_definition.get("footprint", Vector2.ONE)
		if posmod(int(existing_value.get("rotation_degrees", 0)), 180) == 90:
			existing_footprint = Vector2(existing_footprint.y, existing_footprint.x)
		var existing_position: Vector2 = existing_value.get("position", Vector2.ZERO)
		var existing_rect := Rect2(existing_position - existing_footprint * 0.5, existing_footprint)
		if candidate.intersects(existing_rect, true):
			return {"ok": false, "reason": "furniture_overlap", "blocking_instance_id": String(existing_value.get("instance_id", ""))}
	var instance_id := "dwelling_furniture_%06d" % next_furniture_instance_id
	next_furniture_instance_id += 1
	var entry := {"instance_id": instance_id, "item_id": item_id, "position": position, "rotation_degrees": posmod(rotation_degrees, 360), "floor_index": floor_index}
	var entries: Array = placed_furniture.get(dwelling_id, []).duplicate(true)
	entries.append(entry)
	placed_furniture[dwelling_id] = entries
	furniture_inventory[item_id] = furniture_inventory_count(item_id) - 1
	if furniture_inventory_count(item_id) <= 0:
		furniture_inventory.erase(item_id)
	return {"ok": true, "dwelling_id": dwelling_id, "furniture": entry.duplicate(true), "sleeping_capacity": sleeping_capacity_for(dwelling_id)}


func remove_furniture(dwelling_id: String, instance_id: String, actor_hex: Vector2i) -> Dictionary:
	if not bool(owned.get(dwelling_id, false)):
		return {"ok": false, "reason": "dwelling_not_owned"}
	var site_id := site_id_for_dwelling(dwelling_id)
	if site_id.is_empty() or not is_at_site(site_id, actor_hex):
		return {"ok": false, "reason": "not_at_dwelling"}
	var entries: Array = placed_furniture.get(dwelling_id, []).duplicate(true)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if String(entry.get("instance_id", "")) != instance_id:
			continue
		var item_id := String(entry.get("item_id", ""))
		entries.remove_at(index)
		placed_furniture[dwelling_id] = entries
		furniture_inventory[item_id] = furniture_inventory_count(item_id) + 1
		return {"ok": true, "item_id": item_id, "sleeping_capacity": sleeping_capacity_for(dwelling_id)}
	return {"ok": false, "reason": "furniture_instance_not_found"}


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
	return {
		"owned": owned.duplicate(true),
		"upgrades": upgrades.duplicate(true),
		"furniture_inventory": furniture_inventory.duplicate(true),
		"placed_furniture": placed_furniture.duplicate(true),
		"residents": residents.duplicate(true),
		"next_furniture_instance_id": next_furniture_instance_id
	}


func from_dict(data: Dictionary) -> bool:
	var saved_owned: Variant = data.get("owned", {})
	var saved_upgrades: Variant = data.get("upgrades", {})
	var saved_inventory: Variant = data.get("furniture_inventory", {})
	var saved_placed: Variant = data.get("placed_furniture", {})
	var saved_residents: Variant = data.get("residents", {})
	if not saved_owned is Dictionary or not saved_upgrades is Dictionary or not saved_inventory is Dictionary or not saved_placed is Dictionary or not saved_residents is Dictionary:
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
	var validated_inventory: Dictionary = {}
	for item_id_value in saved_inventory:
		var item_id := String(item_id_value)
		var quantity := int(saved_inventory[item_id_value])
		if CampaignFurnitureCatalog.definition(item_id).is_empty() or quantity < 1:
			return false
		validated_inventory[item_id] = quantity
	var validated_placed: Dictionary = {}
	for dwelling_id_value in saved_placed:
		var dwelling_id := String(dwelling_id_value)
		if not bool(saved_owned.get(dwelling_id, false)) or not saved_placed[dwelling_id_value] is Array:
			return false
		var seen_instances: Dictionary = {}
		var entries: Array = []
		for entry_value in saved_placed[dwelling_id_value]:
			if not entry_value is Dictionary:
				return false
			var entry: Dictionary = entry_value
			var instance_id := String(entry.get("instance_id", ""))
			var item_id := String(entry.get("item_id", ""))
			if instance_id.is_empty() or seen_instances.has(instance_id) or CampaignFurnitureCatalog.definition(item_id).is_empty():
				return false
			if not entry.get("position", Vector2.ZERO) is Vector2:
				return false
			seen_instances[instance_id] = true
			entries.append(entry.duplicate(true))
		validated_placed[dwelling_id] = entries
	var candidate := CampaignDwellingState.new()
	candidate.owned = saved_owned.duplicate(true)
	candidate.upgrades = saved_upgrades.duplicate(true)
	candidate.placed_furniture = validated_placed.duplicate(true)
	var validated_residents: Dictionary = {}
	var resident_counts: Dictionary = {}
	for character_id_value in saved_residents:
		var character_id := String(character_id_value)
		var resident_value: Variant = saved_residents[character_id_value]
		if character_id.is_empty() or _is_companion_character_id(character_id) or not resident_value is Dictionary:
			return false
		var resident: Dictionary = resident_value
		var dwelling_id := String(resident.get("dwelling_id", ""))
		var preferred_activity := String(resident.get("preferred_activity", "socialise"))
		if String(resident.get("character_id", "")) != character_id or not bool(candidate.owned.get(dwelling_id, false)):
			return false
		if candidate.resident_capacity_for(dwelling_id) <= 0 or not RESIDENT_DAY_ACTIVITIES.has(preferred_activity):
			return false
		validated_residents[character_id] = {
			"character_id": character_id,
			"dwelling_id": dwelling_id,
			"preferred_activity": preferred_activity,
			"household_role": String(resident.get("household_role", "resident")),
			"duties": (resident.get("duties", []) as Array).duplicate(true)
		}
		resident_counts[dwelling_id] = int(resident_counts.get(dwelling_id, 0)) + 1
	for dwelling_id_value in resident_counts:
		var dwelling_id := String(dwelling_id_value)
		if int(resident_counts[dwelling_id]) > candidate.resident_capacity_for(dwelling_id):
			return false
	owned = saved_owned.duplicate(true)
	upgrades = saved_upgrades.duplicate(true)
	furniture_inventory = validated_inventory
	placed_furniture = validated_placed
	residents = validated_residents
	next_furniture_instance_id = maxi(1, int(data.get("next_furniture_instance_id", 1)))
	return true
