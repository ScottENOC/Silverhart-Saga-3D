class_name CampaignCharacterSpawner
extends RefCounted
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
    npc_profile: Dictionary = {},
    ambient_role: String = ""
) -> Node3D:
    if simulation == null or parent == null:
        push_error("Cannot spawn campaign character without a simulation and parent node.")
        return null
    if actor_by_id.has(character_id):
        push_warning("Campaign character '%s' already has a presentation actor." % character_id)
        return actor_by_id[character_id] as Node3D

    var state := CampaignCharacterFactory.create_player_state(player_profile, character_id, spawn_hex) if is_player else CampaignCharacterFactory.create_npc_state(character_id, display_name, spawn_hex, npc_profile, starting_loadouts)
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
        npc_profile,
        ambient_role
    )
    if actor == null:
        return null
    parent.add_child(actor)
    actor_by_id[character_id] = actor
    return actor
