class_name CampaignNpcInteractionService
extends RefCounted
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
		result.append({
			"id":actor_id,
			"name":state.display_name,
			"distance":distance,
			"hostile":state.side == "enemy"
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.distance) == int(b.distance):
			return String(a.name) < String(b.name)
		return int(a.distance) < int(b.distance)
	)
	return result


static func actor_for(scene_tree: SceneTree, local_actor_by_id: Dictionary, character_id: String) -> Node3D:
	if local_actor_by_id.has(character_id):
		return local_actor_by_id[character_id] as Node3D
	if scene_tree == null:
		return null
	for actor in scene_tree.get_nodes_in_group("campaign2_npc"):
		if String(actor.get_meta("campaign2_npc_id", "")) == character_id:
			return actor as Node3D
	return null
