class_name CampaignNpcInteractionService
extends RefCounted

const WORLD_STATE_SERVICE = preload("res://scripts/simulation/campaign_world_state_service.gd")
const REDDALE_DIALOGUE_SERVICE = preload("res://scripts/simulation/reddale_campaign_dialogue_service.gd")
const REDDALE_ESPIONAGE_DIALOGUE_SERVICE = preload("res://scripts/simulation/reddale_espionage_dialogue_service.gd")
## Shared proximity and actor lookup for location-owned and streamed NPCs.
## Dialogue rules remain in campaign content; this service only resolves who
## can be interacted with in the currently resident world presentation.

static func nearby_entries(
	simulation: WorldSimulation,
	active_character_id: String,
	local_actor_by_id: Dictionary,
	scene_tree: SceneTree,
	interaction_radius: int = 2
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if simulation == null or scene_tree == null or interaction_radius < 0:
		return result
	var active_state := simulation.get_character(active_character_id)
	if active_state == null:
		return result
	var visible_actor_ids: Dictionary = {}
	for actor_id_value in local_actor_by_id.keys():
		visible_actor_ids[String(actor_id_value)] = true
	for actor in scene_tree.get_nodes_in_group("campaign2_npc"):
		var actor_id := String(actor.get_meta("campaign2_npc_id", ""))
		if not actor_id.is_empty():
			visible_actor_ids[actor_id] = true
	for actor_id_value in visible_actor_ids.keys():
		var actor_id := String(actor_id_value)
		if actor_id == active_character_id or simulation.is_party_member(actor_id):
			continue
		var state := simulation.get_character(actor_id)
		if state == null or not state.can_act():
			continue
		var distance := HexGrid.distance(active_state.axial, state.axial)
		if distance > interaction_radius:
			continue
		var actor := actor_for(scene_tree, local_actor_by_id, actor_id)
		var settlement_id := String(actor.get_meta("campaign2_settlement_id", "")) if actor != null else ""
		var faction_id := String(actor.get_meta("faction_id", "")) if actor != null else ""
		if actor != null:
			WORLD_STATE_SERVICE.apply_npc_actor_state(
				actor, simulation.campaign_journal, actor_id, settlement_id, faction_id
			)
		var campaign_context := WORLD_STATE_SERVICE.npc_context(
			simulation.campaign_journal, actor_id, settlement_id, faction_id
		)
		var entry := {
			"id":actor_id,
			"name":state.display_name,
			"distance":distance,
			"hostile":state.side == "enemy",
			"campaign_context":campaign_context,
			"public_status":String(campaign_context.get("public_status", ""))
		}
		if actor_id == "reeve_aldous_finch":
			entry["dialogue"] = REDDALE_DIALOGUE_SERVICE.dialogue_for_reeve(simulation.campaign_journal)
		elif actor_id == "baron_corwin_aldervale" or actor_id == "petra_voss":
			entry["dialogue"] = REDDALE_ESPIONAGE_DIALOGUE_SERVICE.dialogue_for_npc(simulation.campaign_journal, actor_id)
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.distance) == int(b.distance):
			return String(a.name) < String(b.name)
		return int(a.distance) < int(b.distance)
	)
	return result


static func select_dialogue_choice(
	simulation: WorldSimulation,
	player_id: String,
	npc_id: String,
	choice_id: String
) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok": false, "reason": "missing_campaign"}
	var player := simulation.get_character(player_id)
	if player == null:
		return {"ok": false, "reason": "missing_player"}
	if npc_id == "reeve_aldous_finch":
		return REDDALE_DIALOGUE_SERVICE.select_choice(simulation.campaign_journal, player, choice_id)
	if npc_id == "baron_corwin_aldervale" or npc_id == "petra_voss":
		return REDDALE_ESPIONAGE_DIALOGUE_SERVICE.select_choice(simulation.campaign_journal, player, npc_id, choice_id)
	return {"ok": false, "reason": "unsupported_dialogue_actor"}


static func actor_for(scene_tree: SceneTree, local_actor_by_id: Dictionary, character_id: String) -> Node3D:
	if local_actor_by_id.has(character_id):
		return local_actor_by_id[character_id] as Node3D
	if scene_tree == null:
		return null
	for actor in scene_tree.get_nodes_in_group("campaign2_npc"):
		if String(actor.get_meta("campaign2_npc_id", "")) == character_id:
			return actor as Node3D
	return null