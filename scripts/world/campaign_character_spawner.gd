class_name CampaignCharacterSpawner
extends RefCounted

const PROCEDURAL_NPC_PROFILES = preload("res://scripts/simulation/procedural_npc_profile_factory.gd")
## Owns campaign character-state creation, simulation registration and actor
## insertion. Scene controllers supply world-specific spawn positions only.

static func spawn_character(
	simulation: WorldSimulation,
	parent: Node3D,
	actor_by_id: Dictionary,
	player_profile: Dictionary,
	starting_loadouts: Dictionary,
	character_id: String,
	display_name: String,
	spawn_hex: Vector2i,
	world_position: Vector3,
	is_player: bool = false,
	ara_model_id: String = "",
	npc_profile: Dictionary = {},
	ambient_role: String = ""
) -> Node3D:
	if simulation == null or parent == null:
		push_error("Cannot spawn campaign character without a simulation and parent node.")
		return null
	if actor_by_id.has(character_id):
		push_warning("Campaign character '%s' already has a presentation actor." % character_id)
		return actor_by_id[character_id] as Node3D

	var resolved_npc_profile := npc_profile
	if not is_player and resolved_npc_profile.is_empty():
		resolved_npc_profile = PROCEDURAL_NPC_PROFILES.create_profile(character_id, display_name, ambient_role if not ambient_role.is_empty() else "villager")
	var state := CampaignCharacterFactory.create_player_state(player_profile, character_id, spawn_hex) if is_player else CampaignCharacterFactory.create_npc_state(character_id, display_name, spawn_hex, resolved_npc_profile, starting_loadouts)
	if state == null:
		push_error("Campaign character factory failed to create state for '%s'." % character_id)
		return null
	state.time_points = state.max_time_points
	simulation.register_character(state)

	var actor := CampaignCharacterActorFactory.create_actor(
		state,
		world_position,
		is_player,
		player_profile,
		resolved_npc_profile,
		ara_model_id,
		ambient_role
	)
	if actor == null:
		return null
	parent.add_child(actor)
	if not is_player:
		actor.set_meta("campaign2_npc_id", character_id)
		actor.set_meta("dialogue_id", String(resolved_npc_profile.get("dialogue_id", character_id)))
		actor.set_meta("faction_id", String(resolved_npc_profile.get("faction_id", "")))
		actor.set_meta("side", String(state.side))
		actor.add_to_group("campaign2_npc")
	actor_by_id[character_id] = actor
	return actor
