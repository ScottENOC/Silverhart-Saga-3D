class_name CampaignCharacterFactory
extends RefCounted

const CHARACTER_CREATION_RULES = preload("res://scripts/simulation/character_creation_rules.gd")


static func load_starting_loadouts() -> Dictionary:
	var file := FileAccess.open("res://data/characters/hollowmere_loadouts.json", FileAccess.READ)
	if file == null:
		push_error("Hollowmere starting loadouts are missing.")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Hollowmere starting loadouts are not valid JSON.")
		return {}
	var characters: Variant = parsed.get("characters", {})
	if characters is Dictionary:
		return characters
	return {}


static func create_player_state(profile: Dictionary, character_id: String, spawn_hex: Vector2i) -> CharacterState:
	return CHARACTER_CREATION_RULES.create_player_state(profile, character_id, spawn_hex)


static func create_npc_state(
	character_id: String,
	display_name: String,
	spawn_hex: Vector2i,
	npc_profile: Dictionary,
	starting_loadouts: Dictionary
) -> CharacterState:
	var state := CharacterState.new(character_id, display_name, spawn_hex)
	_apply_starting_loadout(state, starting_loadouts)
	_apply_npc_clothing_loadout(state, npc_profile)

	var progression: Dictionary = npc_profile.get("progression", {})
	if not progression.is_empty() and not progression.get("class_levels", []).is_empty():
		var class_sequence: Array[String] = []
		for class_id in progression.get("class_levels", []):
			class_sequence.append(String(class_id))
		var preferred_skills: Dictionary = {}
		for skill_id in progression.get("skill_picks", []):
			var key := String(skill_id)
			preferred_skills[key] = int(preferred_skills.get(key, 0)) + 1
		var build_result := NPCSkillSpending.build_authored(
			state,
			String(progression.get("race", "human")),
			class_sequence,
			preferred_skills,
			String(progression.get("seed", "canonical-companion:" + character_id))
		)
		if not bool(build_result.get("ok", false)):
			push_error("Could not build canonical companion %s: %s" % [character_id, build_result])

	for extra_item_id in npc_profile.get("extra_inventory", []):
		var extra_item := ItemCatalog.create_instance(String(extra_item_id), "start_%s_extra_%s" % [character_id, String(extra_item_id)])
		if not extra_item.is_empty():
			state.add_inventory_item(extra_item)

	var party_rules: Dictionary = npc_profile.get("party", {})
	state.companion_never_voluntarily_leaves = bool(party_rules.get("never_voluntarily_leaves", false))
	if bool(party_rules.get("starts_in_party", false)):
		state.side = "player"
		state.companion_recruitment_initialized = true
		state.progression_mode = "companion"

	state.time_points = state.max_time_points
	return state


static func _apply_starting_loadout(state: CharacterState, starting_loadouts: Dictionary) -> void:
	var item_ids: Variant = starting_loadouts.get(state.id, [])
	if not item_ids is Array:
		push_error("Starting loadout for %s is not an array." % state.id)
		return
	for index in range(item_ids.size()):
		var item_id := String(item_ids[index])
		var instance_id := "start_%s_%s_%02d" % [state.id, item_id, index]
		var item := ItemCatalog.create_instance(item_id, instance_id)
		if item.is_empty():
			push_error("Unknown starting item '%s' for %s." % [item_id, state.id])
			continue
		if not state.add_inventory_item(item):
			push_error("Could not add starting item '%s' to %s." % [item_id, state.id])
			continue
		if not state.equip_inventory_item(instance_id):
			push_error("Could not equip starting item '%s' on %s." % [item_id, state.id])


static func _apply_npc_clothing_loadout(state: CharacterState, npc_profile: Dictionary) -> void:
	var params: Dictionary = npc_profile.get("params", {})
	var clothing_parameters := [
		{"parameter": "underTop", "slot": "underTop"},
		{"parameter": "underBottom", "slot": "underBottom"},
		{"parameter": "top", "slot": "shirt"},
		{"parameter": "bottom", "slot": "pants"},
		{"parameter": "shoes", "slot": "shoes"}
	]
	for entry in clothing_parameters:
		var garment_id := String(params.get(entry.parameter, "none"))
		if garment_id.is_empty() or garment_id == "none":
			continue
		var item := ItemCatalog.create_instance(garment_id, "start_%s_clothing_%s" % [state.id, entry.slot])
		if item.is_empty():
			push_warning("NPC %s has Ara garment '%s' without an inventory definition." % [state.id, garment_id])
			continue
		if not state.add_inventory_item(item):
			push_error("Could not add NPC clothing '%s' to %s." % [garment_id, state.id])
			continue
		if not state.equip_inventory_item(String(item.instance_id)):
			push_error("Could not equip NPC clothing '%s' on %s." % [garment_id, state.id])
