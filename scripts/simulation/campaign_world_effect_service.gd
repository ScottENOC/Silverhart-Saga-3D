class_name CampaignWorldEffectService
extends RefCounted
## Applies the durable, non-dialogue effects returned by source campaign content.
## CampaignJournal owns world state and the consequence idempotency record.

const ALDRIC_ID := "ser_aldric_thorne"
const COMPANION_CAMPAIGN_SCRIPT = preload("res://scripts/simulation/companion_campaign_content.gd")
const QUEST_DEFINITION_REGISTRY = preload("res://scripts/simulation/campaign_quest_definition_registry.gd")


static func apply_effects(
	journal: CampaignJournal,
	simulation: WorldSimulation,
	quest_id: String,
	decision_id: String,
	effects: Dictionary,
	scene_tree: SceneTree = null,
	local_actor_by_id: Dictionary = {}
) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if quest_id.strip_edges().is_empty() or decision_id.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_decision_identity"}
	if effects.is_empty():
		return {"ok": false, "reason": "empty_effects"}

	var validation := _validate_effects(effects)
	if not bool(validation.get("ok", false)):
		return validation

	var experience_delta := int(effects.get("experience", 0))
	var gold_delta := int(effects.get("player_gold", 0))
	var changes_player := experience_delta != 0 or gold_delta != 0
	var rescues_aldric := bool(effects.get("rescue_aldric", false))
	var aldric_leaves := bool(effects.get("aldric_leaves_if_recruited", false))
	if changes_player or rescues_aldric or aldric_leaves:
		if simulation == null:
			return {"ok": false, "reason": "missing_simulation"}
	var player: CharacterState = simulation.get_character(simulation.player_character_id) if simulation != null else null
	if changes_player and player == null:
		return {"ok": false, "reason": "missing_player"}
	if player != null and gold_delta < 0 and player.gold < -gold_delta:
		return {"ok": false, "reason": "insufficient_player_gold"}

	if rescues_aldric:
		var rescue_preflight := _prepare_aldric_rescue(journal)
		if not bool(rescue_preflight.get("ok", false)):
			return rescue_preflight

	var consequence_id := "%s::%s::world_effects" % [quest_id, decision_id]
	var recorded := journal.record_world_consequence(consequence_id, quest_id, decision_id, effects)
	if not bool(recorded.get("ok", false)):
		return recorded
	if bool(recorded.get("already_recorded", false)):
		return {"ok": true, "already_applied": true, "consequence_id": consequence_id}

	var region_results: Array[Dictionary] = []
	var security: Dictionary = effects.get("region_security", {})
	for region_id_value in security.keys():
		region_results.append(journal.apply_region_campaign_state(
			String(region_id_value), {"security": float(security[region_id_value])}
		))
	var prosperity: Dictionary = effects.get("region_prosperity", {})
	for region_id_value in prosperity.keys():
		region_results.append(journal.apply_region_campaign_state(
			String(region_id_value), {"prosperity": float(prosperity[region_id_value])}
		))

	var flags: Dictionary = effects.get("set_world_flag", {}).duplicate(true)
	if effects.has("emberlode_raided"):
		flags["emberlode_raided"] = bool(effects["emberlode_raided"])
	if rescues_aldric:
		flags["aldric_rescued"] = true
	if aldric_leaves:
		flags["aldric_leaves_if_recruited"] = true
	if not flags.is_empty():
		journal.apply_world_campaign_flags(flags)

	if effects.has("aldric_attitude"):
		journal.seed_npc_reputation(ALDRIC_ID, 60.0)
		if aldric_leaves and float(effects["aldric_attitude"]) == 0.0:
			journal.set_npc_standing(ALDRIC_ID, 0.0, "goblin_campaign:%s" % decision_id)
		else:
			journal.adjust_npc_standing(ALDRIC_ID, int(effects["aldric_attitude"]), "goblin_campaign:%s" % decision_id)

	if player != null:
		player.experience += experience_delta
		player.gold += gold_delta

	if rescues_aldric:
		var rescue_result := _complete_aldric_rescue(journal)
		if not bool(rescue_result.get("ok", false)):
			return rescue_result
		var aldric := simulation.get_character(ALDRIC_ID)
		if aldric != null and not simulation.is_party_member(ALDRIC_ID):
			aldric.side = "neutral"
			aldric.combat_dormant = false
		_sync_aldric_actor(scene_tree, local_actor_by_id, false)
	if aldric_leaves and simulation.is_party_member(ALDRIC_ID):
		var aldric_departing := simulation.get_character(ALDRIC_ID)
		var dismissed := simulation.dismiss_companion(ALDRIC_ID, true)
		if bool(dismissed.get("ok", false)):
			if aldric_departing != null:
				aldric_departing.side = "neutral"
				aldric_departing.combat_dormant = true
			simulation.unregister_character(ALDRIC_ID)
			_sync_aldric_actor(scene_tree, local_actor_by_id, true)

	return {
		"ok": true,
		"already_applied": false,
		"consequence_id": consequence_id,
		"region_updates": region_results,
		"experience_awarded": experience_delta,
		"gold_delta": gold_delta,
		"aldric_rescued": rescues_aldric,
		"aldric_departed_if_recruited": aldric_leaves
	}


static func _validate_effects(effects: Dictionary) -> Dictionary:
	for map_key in ["region_security", "region_prosperity"]:
		var region_values: Variant = effects.get(map_key, {})
		if not region_values is Dictionary:
			return {"ok": false, "reason": "invalid_" + map_key}
		for region_id_value in region_values.keys():
			var region_id := String(region_id_value).strip_edges()
			var delta: Variant = region_values[region_id_value]
			if region_id.is_empty() or not _is_finite_number(delta):
				return {"ok": false, "reason": "invalid_" + map_key + "_entry"}

	for number_key in ["experience", "player_gold", "aldric_attitude"]:
		if effects.has(number_key) and not _is_finite_number(effects[number_key]):
			return {"ok": false, "reason": "invalid_" + number_key}

	for flag_key in ["rescue_aldric", "aldric_leaves_if_recruited", "emberlode_raided"]:
		if effects.has(flag_key) and not effects[flag_key] is bool:
			return {"ok": false, "reason": "invalid_" + flag_key}

	var custom_flags: Variant = effects.get("set_world_flag", {})
	if not custom_flags is Dictionary:
		return {"ok": false, "reason": "invalid_set_world_flag"}
	for flag_id_value in custom_flags.keys():
		var flag_id := String(flag_id_value).strip_edges()
		var flag_value: Variant = custom_flags[flag_id_value]
		if flag_id.is_empty() or not (flag_value is bool or flag_value is String):
			return {"ok": false, "reason": "invalid_world_flag"}
	return {"ok": true}


static func _is_finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _prepare_aldric_rescue(journal: CampaignJournal) -> Dictionary:
	QUEST_DEFINITION_REGISTRY.register_all(journal)
	var quest := journal.quest_state("aldric_rescue")
	if quest.is_empty():
		var started := journal.start_quest("aldric_rescue")
		if not bool(started.get("ok", false)):
			return started
		quest = journal.quest_state("aldric_rescue")
	var status := String(quest.get("status", ""))
	if status == "failed":
		return {"ok":false,"reason":"aldric_rescue_quest_failed"}
	if status == "completed":
		return {"ok":true,"already_completed":true}
	if status != "active" or not quest.get("objectives", {}).has("freed"):
		return {"ok":false,"reason":"aldric_rescue_quest_not_ready"}
	return {"ok":true}


static func _complete_aldric_rescue(journal: CampaignJournal) -> Dictionary:
	QUEST_DEFINITION_REGISTRY.register_all(journal)
	var quest := journal.quest_state("aldric_rescue")
	if quest.is_empty():
		var started := journal.start_quest("aldric_rescue")
		if not bool(started.get("ok", false)):
			return started
		quest = journal.quest_state("aldric_rescue")
	if String(quest.get("status", "")) == "completed":
		journal.seed_npc_reputation(ALDRIC_ID, 60.0)
		return {"ok": true, "already_completed": true}
	if String(quest.get("status", "")) != "active":
		return {"ok": false, "reason": "aldric_rescue_quest_not_active"}
	journal.seed_npc_reputation(ALDRIC_ID, 60.0)
	return COMPANION_CAMPAIGN_SCRIPT.complete_objective(journal, "aldric_rescue", "freed")


static func _sync_aldric_actor(scene_tree: SceneTree, local_actor_by_id: Dictionary, departed: bool) -> void:
	var actor := local_actor_by_id.get(ALDRIC_ID) as Node3D
	if actor == null and scene_tree != null:
		for candidate in scene_tree.get_nodes_in_group("campaign2_npc"):
			if String(candidate.get_meta("campaign2_npc_id", "")) == ALDRIC_ID:
				actor = candidate as Node3D
				break
	if actor == null or not is_instance_valid(actor):
		return
	actor.set_meta("tied_up", false)
	actor.set_meta("ambient_enabled", false)
	actor.set_meta("campaign_rescued", true)
	if departed:
		actor.set_meta("campaign_departed", true)
		if local_actor_by_id.has(ALDRIC_ID):
			local_actor_by_id.erase(ALDRIC_ID)
		if actor.is_inside_tree():
			actor.queue_free()
