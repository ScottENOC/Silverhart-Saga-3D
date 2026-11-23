extends SceneTree

const NPC_INTERACTION_SERVICE = preload("res://scripts/world/campaign_npc_interaction_service.gd")

func _initialize() -> void:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	player.side = "player"
	simulation.register_character(player)

	var streamed_state := CharacterState.new("queen_seraphine_corrin", "Queen Seraphine", Vector2i(1, 0))
	streamed_state.side = "neutral"
	simulation.register_character(streamed_state)
	var streamed_actor := Node3D.new()
	streamed_actor.set_meta("campaign2_npc_id", streamed_state.id)
	streamed_actor.add_to_group("campaign2_npc")
	root.add_child(streamed_actor)

	var local_state := CharacterState.new("old_mac", "Old Mac", Vector2i(0, 2))
	simulation.register_character(local_state)
	var local_actor := Node3D.new()
	root.add_child(local_actor)
	var local_actors := {"old_mac":local_actor}

	var distant_state := CharacterState.new("distant_npc", "Distant NPC", Vector2i(8, 8))
	simulation.register_character(distant_state)
	var distant_actor := Node3D.new()
	distant_actor.set_meta("campaign2_npc_id", distant_state.id)
	distant_actor.add_to_group("campaign2_npc")
	root.add_child(distant_actor)

	var companion := CharacterState.new("companion_test", "Companion", Vector2i(1, 1))
	companion.side = "player"
	simulation.register_character(companion)
	var companion_actor := Node3D.new()
	companion_actor.set_meta("campaign2_npc_id", companion.id)
	companion_actor.add_to_group("campaign2_npc")
	root.add_child(companion_actor)

	var nearby := NPC_INTERACTION_SERVICE.nearby_entries(simulation, "player", local_actors, self, 2)
	var ids: Array[String] = []
	for entry in nearby:
		ids.append(String(entry.get("id", "")))
	if ids != ["queen_seraphine_corrin", "old_mac"]:
		push_error("Shared NPC proximity must include nearby streamed and location-owned NPCs, sorted by distance/name. Got: " + str(ids))
		quit(1)
		return
	if NPC_INTERACTION_SERVICE.actor_for(root.get_tree(), local_actors, "queen_seraphine_corrin") != streamed_actor:
		push_error("Shared NPC lookup must resolve actors owned by streamed chunk nodes.")
		quit(1)
		return
	if NPC_INTERACTION_SERVICE.actor_for(root.get_tree(), local_actors, "old_mac") != local_actor:
		push_error("Shared NPC lookup must preserve location-owned actor registrations.")
		quit(1)
		return

	streamed_state.axial = Vector2i(10, 10)
	var after_move := NPC_INTERACTION_SERVICE.nearby_entries(simulation, "player", local_actors, root.get_tree(), 2)
	if after_move.size() != 1 or String(after_move[0].get("id", "")) != "old_mac":
		push_error("NPC proximity must use persistent simulation positions after an NPC moves.")
		quit(1)
		return

	print("Campaign NPC interaction service tests passed.")
	quit(0)