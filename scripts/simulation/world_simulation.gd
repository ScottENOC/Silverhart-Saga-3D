class_name WorldSimulation
extends Node

var _spell_effect_rules = load("res://scripts/simulation/spell_effect_rules.gd").new()

signal character_moved(character_id: String, from_hex: Vector2i, to_hex: Vector2i)
signal world_tick(tick_index: int, world_seconds: float)
signal combat_started
signal combat_ended
signal combat_action_resolved(result: Dictionary)
signal action_committed(event: SimulationEvent)
signal reaction_requested(reactor_id: String, options: Array[Dictionary], request_id: int, source_event_id: String)
signal reaction_resolved(reactor_id: String, choice_id: String, request_id: int, reason: String)
signal movement_reaction_resolved(mover_id: String, halted: bool)

var campaign_journal: CampaignJournal = CampaignJournal.new()
var map_data: HexMapData = HexMapData.new()
var building_registry: BuildingRegistry = BuildingRegistry.new()
var world_cell_loader: Campaign2WorldCellLoader = Campaign2WorldCellLoader.new()
var wilderness_resources: WildernessResourceSystem = WildernessResourceSystem.new()
var characters: Dictionary = {}
var occupied_hexes: Dictionary = {}
var player_character_id: String = "player"
var party_member_ids: Array[String] = []
var clock: WorldClock = WorldClock.new()
var turn_scheduler: CombatTurnScheduler = CombatTurnScheduler.new()
var is_in_combat: bool = false
var pending_reaction: Dictionary = {}
var next_reaction_request_id: int = 1
var pending_attack_context: Dictionary = {}
var pending_move_context: Dictionary = {}
var pending_spell_context: Dictionary = {}
var multistory_location_states: Dictionary = {}
var pending_multistory_location_saves: Dictionary = {}
var camp_simulation: CampSimulation = CampSimulation.new()
var companion_bonds: CompanionBondState = CompanionBondState.new()

signal multistory_transition_unlocked(location_id: String, quest_id: String, transitions: Array[Dictionary])

func _init() -> void:
    clock.ticked.connect(_on_clock_ticked)
    turn_scheduler.turn_started.connect(_on_combat_turn_started)
    campaign_journal.journal_event.connect(_on_campaign_journal_event)
    building_registry.door_state_changed.connect(_on_door_state_changed)

func _on_door_state_changed(door_id: String) -> void:
    sync_door_map_state(door_id)

## Apply authoritative door state to the shared gameplay cell. The underlying
## walkability is captured when the authored layout registers the door, so
## opening it restores the terrain's original movement rule rather than
## blindly making every door hex walkable.
func sync_door_map_state(door_id: String) -> bool:
    var door := building_registry.get_door(door_id)
    if door == null or not map_data.has_cell(door.hex):
        return false
    var cell: Dictionary = map_data.cells[door.hex]
    var base_walkable := bool(cell.get("door_base_walkable", cell.get("walkable", false)))
    cell["door_base_walkable"] = base_walkable
    cell["walkable"] = base_walkable and door.is_passable()
    cell["blocks_vision"] = not door.is_passable()
    cell["vision_block_height"] = 2.2
    map_data.cells[door.hex] = cell
    return true

func _on_campaign_journal_event(event: Dictionary) -> void:
    var event_type := String(event.get("event_type", "campaign_event"))
    if event_type == "quest_completed":
        var quest_id := String(event.get("quest_id", ""))
        for location_id_variant in multistory_location_states:
            var location_id := String(location_id_variant)
            var state := multistory_location_states[location_id] as Campaign2MultiStoryLocationState
            if state == null:
                continue
            var unlock_result: Dictionary = state.complete_quest(quest_id)
            var revealed: Array[Dictionary] = unlock_result.get("revealed", [])
            if not revealed.is_empty():
                multistory_transition_unlocked.emit(location_id, quest_id, revealed)
    action_committed.emit(SimulationEvent.new(event_type, "", "", event))

func register_multistory_location_state(location_definition: Dictionary) -> Campaign2MultiStoryLocationState:
    var location_id := String(location_definition.get("id", "")).strip_edges()
    if location_id.is_empty():
        return null
    if multistory_location_states.has(location_id):
        return multistory_location_states[location_id] as Campaign2MultiStoryLocationState
    var state := Campaign2MultiStoryLocationState.new()
    var saved_state: Dictionary = pending_multistory_location_saves.get(location_id, {})
    var configured: Dictionary = state.configure(location_definition, saved_state)
    if not bool(configured.get("ok", false)):
        push_error("Could not configure multi-story location state %s: %s" % [location_id, configured])
        return null
    multistory_location_states[location_id] = state
    pending_multistory_location_saves.erase(location_id)
    for quest_id_variant in campaign_journal.quests:
        var quest: Dictionary = campaign_journal.quests[quest_id_variant]
        if String(quest.get("status", "")) == "completed":
            state.complete_quest(String(quest_id_variant))
    return state

func restore_multistory_location_states(saved_locations: Dictionary) -> bool:
    var validated: Dictionary = {}
    for location_id_variant in saved_locations:
        var location_id := String(location_id_variant)
        var saved_state: Variant = saved_locations[location_id_variant]
        if location_id.is_empty() or not saved_state is Dictionary:
            return false
        validated[location_id] = saved_state.duplicate(true)
    pending_multistory_location_saves = validated
    for location_id_variant in multistory_location_states:
        var location_id := String(location_id_variant)
        if not pending_multistory_location_saves.has(location_id):
            continue
        var state := multistory_location_states[location_id] as Campaign2MultiStoryLocationState
        if state == null or not state.restore(pending_multistory_location_saves[location_id]):
            return false
        pending_multistory_location_saves.erase(location_id)
    return true

func multistory_location_states_to_dict() -> Dictionary:
    var result := pending_multistory_location_saves.duplicate(true)
    for location_id_variant in multistory_location_states:
        var location_id := String(location_id_variant)
        var state := multistory_location_states[location_id] as Campaign2MultiStoryLocationState
        if state != null:
            result[location_id] = state.to_dict()
    return result

func _on_combat_turn_started(character_id: String) -> void:
    var state := get_character(character_id)
    if state != null:
        state.parries_remaining = 3
        state.sidesteps_remaining = 3
        state.reaction_blocked = false

func _process(delta: float) -> void:
    advance_real_time(delta)

## Check initiative before advancing time, as the source engine does. A ready
## combatant takes their turn immediately; world time only advances when no
## one is eligible to act.
func advance_real_time(real_delta: float) -> int:
    if is_in_combat:
        if not pending_reaction.is_empty():
            return 0
        if turn_scheduler.has_active_turn():
            return 0
        if turn_scheduler.select_next_ready(characters) != null:
            clock.accumulator = 0.0
            return 0
    if camp_simulation.phase == "evening" or camp_simulation.phase == "night":
        return clock.advance_world_seconds(camp_simulation.advance_real_time(real_delta))
    return clock.advance_real_time(real_delta, is_in_combat)

func advance_world_seconds(delta_seconds: float) -> int:
    # Deterministic equivalent of advance_real_time, for tests and fast-forward.
    if is_in_combat:
        if not pending_reaction.is_empty():
            return 0
        if turn_scheduler.has_active_turn():
            return 0
        if turn_scheduler.select_next_ready(characters) != null:
            clock.accumulator = 0.0
            return 0
    return clock.advance_world_seconds(delta_seconds)

func register_character(state: CharacterState) -> void:
    if state.id.is_empty():
        push_error("Character IDs must have stable, non-empty IDs.")
        return
    if characters.has(state.id):
        push_error("Duplicate character ID: %s" % state.id)
        return
    if occupied_hexes.has(state.axial):
        push_error("Cannot register %s: hex %s is already occupied." % [state.id, state.axial])
        return
    state.sync_skill_effects()
    # A combatant who enters an encounter after it has started joins with a
    # full turn available, matching the campaign's intended encounter rule.
    if is_in_combat and state.side != "neutral" and not state.combat_dormant:
        state.time_points = ActionEconomy.COMBAT_TURN_READY_TP
    characters[state.id] = state
    occupied_hexes[state.axial] = state.id
    if state.id == player_character_id or state.side == "player":
        if not party_member_ids.has(state.id):
            party_member_ids.append(state.id)
    _attach_character_lifecycle(state)


## Replace or add a batch of restored states while preserving registry ownership.
## The batch is validated as a whole so mounted pairs and shared occupancy remain consistent.
func restore_character_states(states: Array[CharacterState]) -> bool:
    var candidate_characters: Dictionary = characters.duplicate()
    var replacement_ids: Dictionary = {}
    for state in states:
        if state == null or state.id.is_empty() or replacement_ids.has(state.id):
            return false
        replacement_ids[state.id] = true
        candidate_characters[state.id] = state

    var rebuilt_occupancy: Dictionary = {}
    for character_id_value in candidate_characters.keys():
        var character_id := String(character_id_value)
        var state := candidate_characters[character_id_value] as CharacterState
        if state == null:
            return false
        if not state.mounted_animal_id.is_empty():
            var mount := candidate_characters.get(state.mounted_animal_id) as CharacterState
            if mount == null or mount.mounted_by_id != state.id:
                return false
        if not state.mounted_by_id.is_empty():
            var rider := candidate_characters.get(state.mounted_by_id) as CharacterState
            if rider == null or rider.mounted_animal_id != state.id:
                return false
        # A mounted rider shares the mount's hex and must not reserve it twice.
        if not state.mounted_animal_id.is_empty():
            continue
        if rebuilt_occupancy.has(state.axial):
            return false
        rebuilt_occupancy[state.axial] = state.id

    for character_id_value in replacement_ids.keys():
        var character_id := String(character_id_value)
        var previous := get_character(character_id)
        if previous != null:
            _detach_character_lifecycle(previous)
        var restored := candidate_characters[character_id] as CharacterState
        characters[character_id] = restored
        _attach_character_lifecycle(restored)

    occupied_hexes.clear()
    for hex in rebuilt_occupancy:
        occupied_hexes[hex] = rebuilt_occupancy[hex]
    return true


## Remove a character through the simulation so listeners and occupancy are released.
## Mounted participants must be dismounted before they can be removed.
func unregister_character(character_id: String) -> bool:
    var state := get_character(character_id)
    if state == null or not state.mounted_animal_id.is_empty() or not state.mounted_by_id.is_empty():
        return false
    _detach_character_lifecycle(state)
    characters.erase(character_id)
    if String(occupied_hexes.get(state.axial, "")) == character_id:
        occupied_hexes.erase(state.axial)
    party_member_ids.erase(character_id)
    return true


## Register an animal through the same character, occupancy, lifecycle and save path.
func register_animal(state: CharacterState) -> Dictionary:
    if state == null:
        return {"ok": false, "reason": "missing_animal_state"}
    if state.race != "animal" or not AnimalCatalog.has_profile(state.creature_kind):
        return {"ok": false, "reason": "invalid_animal_profile"}
    if state.id.is_empty():
        return {"ok": false, "reason": "empty_animal_id"}
    if characters.has(state.id):
        return {"ok": false, "reason": "duplicate_character_id"}
    if occupied_hexes.has(state.axial):
        return {"ok": false, "reason": "occupied_hex"}
    register_character(state)
    return {"ok": characters.has(state.id), "reason": "" if characters.has(state.id) else "registration_failed"}


func can_ride(character_id: String, animal_id: String) -> Dictionary:
    var rider := get_character(character_id)
    var mount := get_character(animal_id)
    if rider == null or mount == null:
        return {"ok": false, "reason": "unknown_character"}
    if rider.race == "animal" or mount.race != "animal" or not mount.mountable:
        return {"ok": false, "reason": "not_a_mount"}
    if mount.side == "enemy":
        return {"ok": false, "reason": "hostile_mount"}
    if not rider.mounted_animal_id.is_empty() or not mount.mounted_by_id.is_empty():
        return {"ok": false, "reason": "already_mounted"}
    if not rider.can_act() or not mount.can_act():
        return {"ok": false, "reason": "character_unavailable"}
    var has_riding_skill := int(rider.skills.get("riding", 0)) > 0 \
        or int(rider.skills.get("riding_druid", 0)) > 0 \
        or int(rider.skills.get("riding_paladin", 0)) > 0
    if not has_riding_skill:
        return {"ok": false, "reason": "riding_skill_required"}
    if mount.mount_size < 2:
        return {"ok": false, "reason": "mount_too_small"}
    if HexGrid.distance(rider.axial, mount.axial) > 1:
        return {"ok": false, "reason": "mount_not_adjacent"}
    return {"ok": true, "reason": ""}


func mount_animal(rider_id: String, animal_id: String, time_point_cost: float = 5.0) -> Dictionary:
    var eligibility := can_ride(rider_id, animal_id)
    if not bool(eligibility.get("ok", false)):
        return eligibility
    var rider := get_character(rider_id)
    var mount := get_character(animal_id)
    if is_in_combat:
        if not turn_scheduler.has_active_turn() or turn_scheduler.current_character_id != rider.id:
            return {"ok": false, "reason": "not_actor_turn"}
        if rider.time_points <= float(ActionEconomy.turn_end_threshold(rider.quick_recovery_rank)):
            return {"ok": false, "reason": "turn_movement_exhausted"}
    if not rider.can_spend_time_points(time_point_cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    if occupied_hexes.get(rider.axial, "") == rider.id:
        occupied_hexes.erase(rider.axial)
    if not rider.spend_time_points(time_point_cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    rider.mounted_animal_id = mount.id
    rider.axial = mount.axial
    rider.facing_direction = mount.facing_direction
    mount.mounted_by_id = rider.id
    mount.mounted_original_side = mount.side
    mount.mounted_original_combat_dormant = mount.combat_dormant
    mount.side = rider.side
    mount.combat_dormant = false
    mount.is_rider = true
    action_committed.emit(SimulationEvent.new("animal_mounted", rider.id, mount.id, {
        "rider_id": rider.id, "mount_id": mount.id, "hex": mount.axial,
        "time_point_cost": time_point_cost
    }))
    if is_in_combat and rider.should_end_turn():
        try_end_current_turn()
    return {"ok": true, "rider_id": rider.id, "mount_id": mount.id, "hex": mount.axial}


func _find_dismount_destination(origin: Vector2i) -> Vector2i:
    for candidate in HexGrid.neighbors(origin):
        if map_data.is_walkable(candidate) and not occupied_hexes.has(candidate):
            return candidate
    return Vector2i(2147483647, 2147483647)


func dismount_animal(rider_id: String, time_point_cost: float = 5.0) -> Dictionary:
    var rider := get_character(rider_id)
    if rider == null:
        return {"ok": false, "reason": "unknown_character"}
    if rider.mounted_animal_id.is_empty():
        return {"ok": false, "reason": "not_mounted"}
    var mount := get_character(rider.mounted_animal_id)
    if mount == null or mount.mounted_by_id != rider.id:
        return {"ok": false, "reason": "mount_link_invalid"}
    if not rider.can_act():
        return {"ok": false, "reason": "character_unavailable"}
    if is_in_combat:
        if not turn_scheduler.has_active_turn() or turn_scheduler.current_character_id != rider.id:
            return {"ok": false, "reason": "not_actor_turn"}
        if rider.time_points <= float(ActionEconomy.turn_end_threshold(rider.quick_recovery_rank)):
            return {"ok": false, "reason": "turn_movement_exhausted"}
    if not rider.can_spend_time_points(time_point_cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    var destination := _find_dismount_destination(mount.axial)
    if destination.x == 2147483647:
        return {"ok": false, "reason": "no_dismount_space"}
    if not rider.spend_time_points(time_point_cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    var origin := rider.axial
    rider.mounted_animal_id = ""
    rider.axial = destination
    rider.facing_direction = mount.facing_direction
    occupied_hexes[destination] = rider.id
    mount.mounted_by_id = ""
    mount.is_rider = false
    mount.side = mount.mounted_original_side
    mount.combat_dormant = mount.mounted_original_combat_dormant
    action_committed.emit(SimulationEvent.new("animal_dismounted", rider.id, mount.id, {
        "rider_id": rider.id, "mount_id": mount.id, "from_hex": origin,
        "to_hex": destination, "time_point_cost": time_point_cost
    }))
    if is_in_combat and rider.should_end_turn():
        try_end_current_turn()
    return {"ok": true, "rider_id": rider.id, "mount_id": mount.id, "hex": destination}


func _force_dismount_pair(rider: CharacterState, mount: CharacterState, reason: String) -> void:
    if rider == null or mount == null:
        return
    var origin := mount.axial
    var destination := _find_dismount_destination(origin)
    rider.mounted_animal_id = ""
    mount.mounted_by_id = ""
    mount.is_rider = false
    mount.side = mount.mounted_original_side
    mount.combat_dormant = mount.mounted_original_combat_dormant
    if destination.x != 2147483647:
        rider.axial = destination
        occupied_hexes[destination] = rider.id
        occupied_hexes[origin] = mount.id
    else:
        # If every adjacent hex is blocked, the incapacitated body yields the
        # shared cell to the still-capable participant. No reciprocal link remains.
        rider.axial = origin
        if rider.can_act() and not mount.can_act():
            occupied_hexes[origin] = rider.id
        else:
            occupied_hexes[origin] = mount.id
    action_committed.emit(SimulationEvent.new("animal_forced_dismount", rider.id, mount.id, {
        "rider_id": rider.id, "mount_id": mount.id, "hex": rider.axial, "reason": reason
    }))


func _movement_state_for(state: CharacterState) -> CharacterState:
    if state == null or state.mounted_animal_id.is_empty():
        return state
    var mount := get_character(state.mounted_animal_id)
    if mount == null or mount.mounted_by_id != state.id or not mount.can_act():
        return state
    return mount

## Build and register a humanoid NPC using the shared source-derived progression service.
func build_and_register_npc(state: CharacterState, options: Dictionary) -> Dictionary:
    if state == null:
        return {"ok": false, "reason": "missing_character"}
    if characters.has(state.id):
        return {"ok": false, "reason": "duplicate_character_id"}
    var result := NPCSkillSpending.build_npc(state, options)
    if not bool(result.get("ok", false)):
        return result
    register_character(state)
    return result

## Recruitment is a one-time progression transition; rejoining only restores party membership.
func recruit_companion(character_id: String, preferred_skills: Dictionary = {}, seed: String = "") -> Dictionary:
    var state := get_character(character_id)
    if state == null:
        return {"ok": false, "reason": "unknown_character"}
    if character_id == player_character_id:
        return {"ok": false, "reason": "player_is_not_recruitable"}
    var result := NPCSkillSpending.recruit_companion(state, preferred_skills, seed)
    var reason := String(result.get("reason", ""))
    if not bool(result.get("ok", false)) and reason != "already_recruited_once":
        return result
    if not party_member_ids.has(character_id):
        party_member_ids.append(character_id)
    state.side = "player"
    state.combat_dormant = false
    state.time_points = 100.0
    if reason == "already_recruited_once":
        return {"ok": true, "reason": "rejoined_existing_companion", "remaining": SkillProgression.available_points(state)}
    return result

## Leaving the active party never deletes or rebuilds the character's progression state.
func dismiss_companion(character_id: String, player_initiated: bool = false) -> Dictionary:
    if character_id == player_character_id:
        return {"ok": false, "reason": "cannot_dismiss_player"}
    var state := get_character(character_id)
    if state == null:
        return {"ok": false, "reason": "unknown_character"}
    if not player_initiated and state.companion_never_voluntarily_leaves:
        return {"ok": false, "reason": "companion_will_not_voluntarily_leave"}
    var index := party_member_ids.find(character_id)
    if index < 0:
        return {"ok": false, "reason": "not_in_party"}
    party_member_ids.remove_at(index)
    return {"ok": true, "reason": "companion_dismissed"}

func is_party_member(character_id: String) -> bool:
    return party_member_ids.has(character_id)

func party_members() -> Array[CharacterState]:
    var result: Array[CharacterState] = []
    for character_id in party_member_ids:
        var state := get_character(character_id)
        if state != null:
            result.append(state)
    return result

## Return a detached snapshot of registered character states for presentation and iteration.
func character_states() -> Array[CharacterState]:
    var result: Array[CharacterState] = []
    for value in characters.values():
        var state := value as CharacterState
        if state != null:
            result.append(state)
    return result


## Return a copy so callers cannot mutate the simulation's party registry.
func get_party_member_ids() -> Array[String]:
    return party_member_ids.duplicate()


## Restore party membership while ignoring unknown IDs and duplicate entries.
func restore_party_members(member_ids: Array) -> void:
    party_member_ids.clear()
    for value in member_ids:
        var character_id := String(value)
        if characters.has(character_id) and not party_member_ids.has(character_id):
            party_member_ids.append(character_id)
    if party_member_ids.is_empty() and characters.has(player_character_id):
        party_member_ids.append(player_character_id)


func is_hex_occupied(hex: Vector2i) -> bool:
    return occupied_hexes.has(hex)


func has_pending_reaction() -> bool:
    return not pending_reaction.is_empty()


## Clear transient combat state before a location-level save is applied.
## This is intentionally silent: restoring a save should not emit gameplay combat events.
func reset_transient_combat_state() -> void:
    is_in_combat = false
    pending_reaction.clear()
    pending_attack_context.clear()
    pending_move_context.clear()
    turn_scheduler.clear()

func get_character(character_id: String) -> CharacterState:
    return characters.get(character_id) as CharacterState

## Move a character between connected building floors without spending movement TP.
func relocate_character(character_id: String, destination: Vector2i) -> bool:
    var state := get_character(character_id)
    if state == null or not map_data.is_walkable(destination) or occupied_hexes.has(destination):
        return false
    var origin := state.axial
    if origin == destination:
        return true
    occupied_hexes.erase(origin)
    state.axial = destination
    occupied_hexes[destination] = character_id
    character_moved.emit(character_id, origin, destination)
    return true


## Player and recruited companion points remain unspent; ordinary NPCs auto-allocate.
func grant_character_level(character_id: String, class_id: String, grant_id: String) -> Dictionary:
    var state := get_character(character_id)
    if state == null:
        return {"ok": false, "reason": "unknown_character"}
    if state.progression_mode == "player" or state.progression_mode == "companion" or state.companion_recruitment_initialized:
        return SkillProgression.grant_level(state, class_id, grant_id)
    return NPCSkillSpending.grant_npc_level(state, class_id, grant_id)

func start_combat() -> void:
    if is_in_combat:
        return
    is_in_combat = true
    for value in characters.values():
        var state := value as CharacterState
        if state != null and state.alive:
            state.time_points += 5.0 * float(maxi(0, int(state.skills.get("initiativeBonus", 0))))
    combat_started.emit()

func end_combat() -> void:
    if not is_in_combat:
        return
    if not pending_reaction.is_empty():
        _finish_pending_reaction("", "combat_ended")
    turn_scheduler.clear()
    is_in_combat = false
    combat_ended.emit()

## Request a reaction without coupling simulation rules to a UI modal.
## Options use {id, name, tp_cost}; an ineligible reactor resolves to no choice immediately.
func request_reaction(reactor_id: String, options: Array[Dictionary], source_event_id: String = "") -> Dictionary:
    if not is_in_combat:
        return _emit_immediate_reaction_resolution(reactor_id, "not_in_combat", source_event_id)
    if not pending_reaction.is_empty():
        return _emit_immediate_reaction_resolution(reactor_id, "another_reaction_pending", source_event_id)

    # Preserve the specific unavailable reason for a normal single-reactor
    # request, while still allowing nearby allies to protect an incapacitated
    # target when their options explicitly name a different reactor.
    var primary := get_character(reactor_id)
    var has_other_reactor := false
    for option in options:
        if String(option.get("reactor_id", reactor_id)) != reactor_id:
            has_other_reactor = true
            break
    if (primary == null or not primary.can_act() or primary.reaction_blocked) and not has_other_reactor:
        return _emit_immediate_reaction_resolution(reactor_id, "reactor_unavailable", source_event_id)

    # A single incoming action may offer choices to the defender and nearby
    # allies. Each option names its own TP-paying reactor; the prompt remains
    # presentation-only and the simulation validates that owner on selection.
    var available: Array[Dictionary] = []
    var reactor_ids: Array[String] = []
    for option in options:
        var option_id := String(option.get("id", ""))
        var option_reactor_id := String(option.get("reactor_id", reactor_id))
        var option_reactor := get_character(option_reactor_id)
        var tp_cost := float(option.get("tp_cost", option.get("tpCost", 0.0)))
        if option_id.is_empty() or option_reactor == null or not option_reactor.can_act() or option_reactor.reaction_blocked:
            continue
        if not is_finite(tp_cost) or tp_cost < 0.0 or not option_reactor.can_spend_time_points(tp_cost):
            continue
        var clean_option := option.duplicate(true)
        clean_option["tp_cost"] = tp_cost
        clean_option["reactor_id"] = option_reactor_id
        available.append(clean_option)
        if not reactor_ids.has(option_reactor_id):
            reactor_ids.append(option_reactor_id)
    if available.is_empty():
        return _emit_immediate_reaction_resolution(reactor_id, "no_available_reaction", source_event_id)

    var request_id := next_reaction_request_id
    next_reaction_request_id += 1
    pending_reaction = {
        "request_id": request_id,
        "reactor_id": reactor_id,
        "reactor_ids": reactor_ids,
        "source_event_id": source_event_id,
        "options": available
    }
    reaction_requested.emit(reactor_id, available.duplicate(true), request_id, source_event_id)
    return {"ok": true, "pending": true, "request_id": request_id, "reactor_id": reactor_id}

## Resolve a pending reaction. Empty choice means decline; invalid choices leave it pending.
func resolve_reaction(choice_id: String = "") -> Dictionary:
    if pending_reaction.is_empty():
        return {"ok": false, "reason": "no_pending_reaction"}
    var default_reactor_id := String(pending_reaction.get("reactor_id", ""))
    if choice_id.is_empty():
        return _finish_pending_reaction("", "declined")

    var selected: Dictionary = {}
    for option in pending_reaction.get("options", []):
        if String(option.get("id", "")) == choice_id:
            selected = option
            break
    if selected.is_empty():
        return {"ok": false, "reason": "invalid_reaction_choice"}
    var reactor_id := String(selected.get("reactor_id", default_reactor_id))
    var state := get_character(reactor_id)
    if state == null or not state.can_act() or state.reaction_blocked:
        return _finish_pending_reaction("", "reactor_unavailable")

    # Sidestep is deliberately a two-stage reaction. The first selection
    # opens a validated destination list but spends nothing until a legal hex
    # is chosen.
    if String(pending_reaction.get("stage", "")) != "sidestep_destination" and String(selected.get("effect", "")) == "sidestep":
        var mover_destination: Vector2i = pending_move_context.get("destination", Vector2i(999999, 999999))
        var destinations := _sidestep_destination_options(state, mover_destination)
        if destinations.is_empty():
            return _finish_pending_reaction("", "no_sidestep_destination")
        pending_reaction["stage"] = "sidestep_destination"
        pending_reaction["sidestep_reactor_id"] = reactor_id
        pending_reaction["selected_option"] = selected.duplicate(true)
        pending_reaction["options"] = destinations
        reaction_requested.emit(reactor_id, destinations.duplicate(true), int(pending_reaction.get("request_id", 0)), "sidestep_destination")
        return {"ok": true, "pending": true, "stage": "sidestep_destination", "request_id": pending_reaction.get("request_id", 0)}

    if String(pending_reaction.get("stage", "")) == "sidestep_destination":
        var original_option: Dictionary = pending_reaction.get("selected_option", {})
        var original_reactor_id := String(pending_reaction.get("sidestep_reactor_id", ""))
        var sidestep_reactor := get_character(original_reactor_id)
        var destination: Vector2i = selected.get("destination", Vector2i.ZERO)
        if sidestep_reactor == null or not sidestep_reactor.can_act() or not _is_valid_sidestep_destination(sidestep_reactor, destination, pending_move_context.get("destination", Vector2i(999999, 999999))):
            return {"ok": false, "reason": "invalid_sidestep_destination"}
        if not sidestep_reactor.spend_time_points(float(original_option.get("tp_cost", 0.0))):
            return _finish_pending_reaction("", "insufficient_time_points")
        sidestep_reactor.sidesteps_remaining = maxi(0, sidestep_reactor.sidesteps_remaining - 1)
        _commit_move(sidestep_reactor, destination)
        pending_reaction["selected_reactor_id"] = original_reactor_id
        return _finish_pending_reaction(String(original_option.get("id", "sidestep")), "selected")

    var cost := float(selected.get("tp_cost", 0.0))
    if not state.spend_time_points(cost):
        return _finish_pending_reaction("", "insufficient_time_points")
    pending_reaction["selected_reactor_id"] = reactor_id
    if not pending_spell_context.is_empty():
        for option in pending_reaction.get("options", []):
            if String(option.get("id", "")) == choice_id:
                pending_spell_context["selected_counterspell"] = option.duplicate(true)
                break
    return _finish_pending_reaction(choice_id, "selected")

func cancel_pending_reaction(reason: String = "cancelled") -> Dictionary:
    if pending_reaction.is_empty():
        return {"ok": false, "reason": "no_pending_reaction"}
    return _finish_pending_reaction("", reason)

func _emit_immediate_reaction_resolution(reactor_id: String, reason: String, source_event_id: String) -> Dictionary:
    var request_id := next_reaction_request_id
    next_reaction_request_id += 1
    reaction_resolved.emit(reactor_id, "", request_id, reason)
    action_committed.emit(SimulationEvent.new("reaction_resolved", reactor_id, "", {
        "choice_id": "", "reason": reason, "source_event_id": source_event_id
    }))
    return {"ok": true, "pending": false, "choice_id": "", "reason": reason, "request_id": request_id}

func _finish_pending_reaction(choice_id: String, reason: String) -> Dictionary:
    var request := pending_reaction.duplicate(true)
    pending_reaction.clear()
    var reactor_id := String(request.get("selected_reactor_id", request.get("reactor_id", "")))
    var request_id := int(request.get("request_id", 0))
    var source_event_id := String(request.get("source_event_id", ""))
    reaction_resolved.emit(reactor_id, choice_id, request_id, reason)
    action_committed.emit(SimulationEvent.new("reaction_resolved", reactor_id, "", {
        "choice_id": choice_id, "reason": reason, "source_event_id": source_event_id
    }))
    if not pending_attack_context.is_empty():
        _resume_pending_attack(choice_id, reason)
    if not pending_move_context.is_empty():
        _resume_pending_move(choice_id, reason)
    if not pending_spell_context.is_empty():
        _resume_pending_spell(choice_id, reason)
    if is_in_combat and turn_scheduler.has_active_turn():
        var active := get_current_turn_character()
        if active == null or not active.can_act():
            turn_scheduler.try_end_turn(characters, true)
        elif active.should_end_turn():
            turn_scheduler.try_end_turn(characters)
    return {"ok": true, "pending": false, "choice_id": choice_id, "reason": reason, "request_id": request_id}

func _attach_character_lifecycle(state: CharacterState) -> void:
    if not state.lifecycle_changed.is_connected(_on_character_lifecycle_changed):
        state.lifecycle_changed.connect(_on_character_lifecycle_changed)


func _detach_character_lifecycle(state: CharacterState) -> void:
    if state != null and state.lifecycle_changed.is_connected(_on_character_lifecycle_changed):
        state.lifecycle_changed.disconnect(_on_character_lifecycle_changed)

func _on_character_lifecycle_changed(character_id: String, transition: String) -> void:
    var state := get_character(character_id)
    if state == null:
        return
    if not state.can_act():
        if not state.mounted_animal_id.is_empty():
            _force_dismount_pair(state, get_character(state.mounted_animal_id), transition)
        elif not state.mounted_by_id.is_empty():
            _force_dismount_pair(get_character(state.mounted_by_id), state, transition)
    if not state.can_act() and not pending_reaction.is_empty() and (String(pending_reaction.get("reactor_id", "")) == character_id or pending_reaction.get("reactor_ids", []).has(character_id)):
        _finish_pending_reaction("", "reactor_incapacitated")
    if not state.can_act() and turn_scheduler.has_active_turn() and turn_scheduler.current_character_id == character_id:
        if pending_reaction.is_empty():
            turn_scheduler.try_end_turn(characters, true)
func try_attack_character(attacker_id: String, target_id: String, options: Dictionary = {}, random_seed: int = 0) -> Dictionary:
    return submit_action(SimulationActionRequest.attack(attacker_id, target_id, options), random_seed)

## Authoritative entry point for simulation actions.
func submit_action(request: SimulationActionRequest, random_seed: int = 0) -> Dictionary:
    if request == null:
        return {"ok": false, "reason": "missing_action_request"}
    match request.action_type:
        SimulationActionRequest.ActionType.ATTACK:
            return _submit_attack(request, random_seed)
        SimulationActionRequest.ActionType.FEINT:
            return _submit_feint(request, random_seed)
        SimulationActionRequest.ActionType.MOVE:
            return _submit_move(request)
        SimulationActionRequest.ActionType.CAST_SPELL:
            return _submit_spell_cast(request, random_seed)
        _:
            return {"ok": false, "reason": "unsupported_action_type"}

## Both player controls and NPC decision-making submit this same action.
## The resolver owns legality, range, resource payment and effect resolution.
func _submit_spell_cast(request: SimulationActionRequest, random_seed: int = 0) -> Dictionary:
    if not pending_reaction.is_empty():
        return {"ok": false, "reason": "reaction_pending"}
    if is_in_combat:
        if not turn_scheduler.has_active_turn():
            return {"ok": false, "reason": "no_active_combat_turn"}
        if turn_scheduler.current_character_id != request.actor_id:
            return {"ok": false, "reason": "not_actor_turn"}

    var caster := get_character(request.actor_id)
    var target: CharacterState = get_character(request.target_id) if not request.target_id.is_empty() else null
    if caster == null or not caster.can_act():
        return {"ok": false, "reason": "caster_unavailable"}
    var saved_spell: Variant = request.options.get("prepared_spell", {})
    if not saved_spell is Dictionary:
        return {"ok": false, "reason": "missing_prepared_spell"}
    var prepared := PreparedSpell.from_dict(saved_spell)
    if prepared == null or not prepared.is_valid():
        return {"ok": false, "reason": "invalid_prepared_spell"}
    var spell_id := prepared.base_spell_id
    if not caster.unlocked_base_spells.has(spell_id) and int(caster.skills.get("learn_%s" % spell_id, 0)) <= 0:
        return {"ok": false, "reason": "spell_not_learned"}
    var exact_variant_prepared := false
    for saved_value in caster.prepared_spells:
        if not saved_value is Dictionary:
            continue
        var saved_prepared := PreparedSpell.from_dict(saved_value)
        if saved_prepared != null and saved_prepared.base_spell_id == prepared.base_spell_id \
        and saved_prepared.modifiers == prepared.modifiers:
            exact_variant_prepared = true
            break
    if not exact_variant_prepared:
        return {"ok": false, "reason": "spell_not_prepared"}

    var variant := SpellRules.compute_variant(spell_id, prepared.modifiers, caster.skills)
    if not bool(variant.get("ok", false)):
        return {"ok": false, "reason": String(variant.get("reason", "invalid_spell_variant"))}
    if not SpellRules.supports_initial_cast(spell_id, variant):
        return {"ok": false, "reason": "spell_variant_effect_not_implemented"}
    var target_validation: Dictionary = _spell_effect_rules.validate(self, caster, target, prepared, variant, request)
    if not bool(target_validation.get("ok", false)):
        return {"ok": false, "reason": String(target_validation.get("reason", "invalid_spell_target"))}
    target = target_validation.get("target") as CharacterState

    var tp_cost := float(variant.get("time_point_cost", 0))
    if not is_finite(tp_cost) or tp_cost < 0.0 or not caster.can_spend_time_points(tp_cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    var armour_penalty := SpellRules.armour_mana_penalty(caster, String(variant.get("school", "")))
    var total_mana_cost := int(variant.get("mana_cost", 0)) + armour_penalty
    var affordability := SpellRules.cast_affordability(caster, total_mana_cost)
    if not bool(affordability.get("ok", false)):
        return {"ok": false, "reason": String(affordability.get("reason", "insufficient_mana"))}

    var context := {
        "caster_id": caster.id,
        "target_id": target.id if target != null else "",
        "prepared_spell": prepared.to_dict(),
        "variant": variant.duplicate(true),
        "request_options": request.options.duplicate(true),
        "request_destination": request.destination,
        "random_seed": random_seed,
        "time_point_cost": tp_cost,
        "armour_penalty": armour_penalty,
        "total_mana_cost": total_mana_cost,
        "affordability": affordability.duplicate(true)
    }
    if is_in_combat and spell_id != "counterspell":
        var counter_result := _offer_counterspell_reaction(context, caster, target)
        if not counter_result.is_empty():
            return counter_result
    return _complete_spell_cast(context)


func _complete_spell_cast(context: Dictionary) -> Dictionary:
    var caster := get_character(String(context.get("caster_id", "")))
    var target := get_character(String(context.get("target_id", "")))
    if caster == null or not caster.can_act():
        return {"ok": false, "reason": "caster_unavailable"}
    var prepared := PreparedSpell.from_dict(context.get("prepared_spell", {}))
    if prepared == null:
        return {"ok": false, "reason": "invalid_prepared_spell"}
    var variant: Dictionary = context.get("variant", {})
    var tp_cost := float(context.get("time_point_cost", 0.0))
    var armour_penalty := int(context.get("armour_penalty", 0))
    var total_mana_cost := int(context.get("total_mana_cost", 0))
    var affordability: Dictionary = context.get("affordability", {})
    if not caster.can_spend_time_points(tp_cost) or not bool(SpellRules.cast_affordability(caster, total_mana_cost).get("ok", false)):
        return {"ok": false, "reason": "resources_changed_before_cast"}
    if not caster.spend_time_points(tp_cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    caster.current_mana -= int(affordability.get("mana_to_spend", 0))
    var blood_hp_cost := int(affordability.get("hp_cost", 0))
    if blood_hp_cost > 0:
        caster.apply_damage(blood_hp_cost)

    caster.remove_spell_effect("divine_silence")
    var spell_id := prepared.base_spell_id
    var is_offensive := spell_id in ["firebolt", "smite_evil", "divine_silence", "dragon_breath", "entangle", "temporal_rift"]
    if is_offensive and target != null:
        _apply_spell_protection_triggers(caster, target)
    elif is_offensive:
        var center: Vector2i = _spell_effect_rules.target_hex_for(self, SimulationActionRequest.new(
            SimulationActionRequest.ActionType.CAST_SPELL, caster.id, "", context.get("request_destination", Vector2i.ZERO), 0.0, context.get("request_options", {})
        ), null)
        var protection_radius := maxi(0, int(variant.get("radius", 0)))
        for value in characters.values():
            var protected_target := value as CharacterState
            if protected_target != null and protected_target.side != caster.side and HexGrid.distance(center, protected_target.axial) <= protection_radius:
                _apply_spell_protection_triggers(caster, protected_target)
    if is_offensive:
        caster.remove_spell_effect("sanctuary")

    var request := SimulationActionRequest.new(
        SimulationActionRequest.ActionType.CAST_SPELL,
        caster.id,
        target.id if target != null else "",
        context.get("request_destination", Vector2i.ZERO),
        0.0,
        context.get("request_options", {})
    )
    var cast_id := "%s:%d:%s:%d" % [caster.id, clock.tick_index, spell_id, int(context.get("random_seed", 0))]
    var effect_payload: Dictionary = _spell_effect_rules.apply(self, caster, target, prepared, variant, request, cast_id)
    effect_payload["spell_id"] = spell_id
    effect_payload["spell_name"] = String(variant.get("name", spell_id))
    effect_payload["mana_cost"] = total_mana_cost
    effect_payload["base_mana_cost"] = int(variant.get("mana_cost", 0))
    effect_payload["armour_mana_penalty"] = armour_penalty
    effect_payload["blood_magic_hp_cost"] = blood_hp_cost
    effect_payload["time_point_cost"] = tp_cost
    effect_payload["core_mana_cost"] = int(variant.get("core_mana_cost", variant.get("mana_cost", 0)))
    effect_payload["caster_mana_remaining"] = caster.current_mana
    effect_payload["caster_health"] = caster.health
    var target_id := target.id if target != null else ""
    var result_data := SimulationActionResult.new("cast_spell", true, "", caster.id, target_id, effect_payload).to_dict()
    action_committed.emit(SimulationEvent.new("spell_cast", caster.id, target_id, result_data))
    combat_action_resolved.emit(result_data)
    if is_in_combat and caster.should_end_turn():
        try_end_current_turn()
    return result_data


func _offer_counterspell_reaction(context: Dictionary, caster: CharacterState, target: CharacterState) -> Dictionary:
    var options: Array[Dictionary] = []
    var player_options: Array[Dictionary] = []
    for value in characters.values():
        var reactor := value as CharacterState
        if reactor == null or not reactor.can_act() or reactor.reaction_blocked or reactor.side == caster.side:
            continue
        if not reactor.unlocked_base_spells.has("counterspell") and int(reactor.skills.get("learn_counterspell", 0)) <= 0:
            continue
        var prepared_counter: PreparedSpell
        for saved in reactor.prepared_spells:
            var candidate := PreparedSpell.from_dict(saved)
            if candidate != null and candidate.base_spell_id == "counterspell":
                prepared_counter = candidate
                break
        if prepared_counter == null:
            if reactor.side == "player":
                continue
            prepared_counter = PreparedSpell.create("counterspell")
        var counter_variant := SpellRules.compute_variant("counterspell", prepared_counter.modifiers, reactor.skills)
        if not bool(counter_variant.get("ok", false)):
            continue
        var counter_range := maxi(1, int(counter_variant.get("range", 1)))
        var target_in_range := HexGrid.distance(reactor.axial, caster.axial) <= counter_range
        if target != null:
            target_in_range = target_in_range or HexGrid.distance(reactor.axial, target.axial) <= counter_range
        if not target_in_range or not reactor.can_spend_time_points(5.0):
            continue
        var counter_penalty := SpellRules.armour_mana_penalty(reactor, "arcane")
        var counter_cost := int(counter_variant.get("mana_cost", 10)) + counter_penalty
        var counter_affordability := SpellRules.cast_affordability(reactor, counter_cost)
        if not bool(counter_affordability.get("ok", false)):
            continue
        var option := {
            "id": "counterspell_%s" % reactor.id,
            "name": "Counterspell — %s" % reactor.display_name,
            "tp_cost": 5.0,
            "reactor_id": reactor.id,
            "effect": "counterspell",
            "prepared_spell": prepared_counter.to_dict(),
            "mana_cost": counter_cost,
            "mana_to_spend": int(counter_affordability.get("mana_to_spend", 0)),
            "hp_cost": int(counter_affordability.get("hp_cost", 0))
        }
        options.append(option)
        if reactor.side == "player":
            player_options.append(option)

    if caster.side == "player":
        # Enemy counterspell decisions mirror the source game's 50% AI response.
        var enemy_options: Array[Dictionary] = []
        for option in options:
            var reactor := get_character(String(option.get("reactor_id", "")))
            if reactor != null and reactor.side != "player":
                enemy_options.append(option)
        if not enemy_options.is_empty():
            var rng := RandomNumberGenerator.new()
            rng.seed = int(context.get("random_seed", 0)) if int(context.get("random_seed", 0)) != 0 else int(caster.id.hash())
            if rng.randf() < 0.5:
                var selected: Dictionary = enemy_options[0]
                var reactor := get_character(String(selected.get("reactor_id", "")))
                if reactor != null and reactor.spend_time_points(5.0):
                    reactor.current_mana -= int(selected.get("mana_to_spend", 0))
                    if int(selected.get("hp_cost", 0)) > 0:
                        reactor.apply_damage(int(selected.get("hp_cost", 0)))
                    return _resolve_countered_spell(context, reactor, caster, selected)
    elif not player_options.is_empty():
        pending_spell_context = context.duplicate(true)
        var first_reactor_id := String(player_options[0].get("reactor_id", ""))
        var reaction_result := request_reaction(first_reactor_id, player_options, "spell:%s:%s" % [caster.id, prepared_spell_id(context)])
        if bool(reaction_result.get("pending", false)):
            return {"ok": true, "pending": true, "action_type": "cast_spell", "request_id": reaction_result.get("request_id", 0)}
        pending_spell_context.clear()
    return {}


func prepared_spell_id(context: Dictionary) -> String:
    var prepared := PreparedSpell.from_dict(context.get("prepared_spell", {}))
    return prepared.base_spell_id if prepared != null else ""


func _resume_pending_spell(choice_id: String, reason: String) -> void:
    var context := pending_spell_context.duplicate(true)
    pending_spell_context.clear()
    if context.is_empty() or reason == "combat_ended":
        return
    if reason == "selected" and choice_id.begins_with("counterspell_"):
        var reactor_id := choice_id.trim_prefix("counterspell_")
        var reactor := get_character(reactor_id)
        if reactor == null:
            _complete_spell_cast(context)
            return
        var option: Dictionary = {}
        for candidate in pending_reaction.get("options", []):
            if String(candidate.get("id", "")) == choice_id:
                option = candidate
                break
        # _finish_pending_reaction clears the request before resuming; the
        # selected option is retained in this context by resolve_reaction.
        option = context.get("selected_counterspell", option)
        if option.is_empty():
            return
        reactor.current_mana -= int(option.get("mana_to_spend", 0))
        if int(option.get("hp_cost", 0)) > 0:
            reactor.apply_damage(int(option.get("hp_cost", 0)))
        var caster := get_character(String(context.get("caster_id", "")))
        _resolve_countered_spell(context, reactor, caster, option)
        return
    _complete_spell_cast(context)


func _resolve_countered_spell(context: Dictionary, reactor: CharacterState, caster: CharacterState, option: Dictionary) -> Dictionary:
    if caster != null:
        var caster_affordability := SpellRules.cast_affordability(caster, int(context.get("total_mana_cost", 0)))
        if bool(caster_affordability.get("ok", false)):
            caster.current_mana -= int(caster_affordability.get("mana_to_spend", 0))
            if int(caster_affordability.get("hp_cost", 0)) > 0:
                caster.apply_damage(int(caster_affordability.get("hp_cost", 0)))
    var payload := {
        "countered": true,
        "counterspell_reactor_id": reactor.id,
        "counterspell_mana_cost": int(option.get("mana_cost", 0)),
        "caster_mana_remaining": caster.current_mana if caster != null else 0
    }
    var result := SimulationActionResult.new(
        "cast_spell", true, "countered", caster.id if caster != null else "",
        "", payload
    ).to_dict()
    action_committed.emit(SimulationEvent.new("spell_countered", reactor.id, caster.id if caster != null else "", result))
    combat_action_resolved.emit(result)
    if is_in_combat and turn_scheduler.has_active_turn():
        try_end_current_turn(true)
    return result


func _apply_spell_protection_triggers(attacker: CharacterState, target: CharacterState) -> void:
    if attacker == null or target == null or attacker.side == target.side:
        return
    var sanctuary := target.get_spell_effect("sanctuary")
    var protection := target.get_spell_effect("divine_protection")
    for effect in [sanctuary, protection]:
        if effect.is_empty():
            continue
        var penalty := maxi(1, int(effect.get("magnitude", 1)))
        attacker.time_points = maxf(0.0, attacker.time_points - float(penalty))
        var source := get_character(String(effect.get("source_id", "")))
        if source != null:
            var damage := maxi(0, int(source.skills.get("cleric_trigger_damage", 0)))
            if damage > 0:
                attacker.apply_damage(damage)
            var mana_loss := maxi(0, int(source.skills.get("cleric_trigger_mana", 0)))
            if mana_loss > 0:
                attacker.current_mana = maxi(0, attacker.current_mana - mana_loss)


func _resolve_firebolt_hit(caster: CharacterState, target: CharacterState, magnitude: int, random_seed: int) -> Dictionary:
    var chance := clampf(50.0 + caster.to_hit_spell + float(int(caster.skills.get("firebolt_hit", 0)) * 5) - target.passive_dodge, 0.0, 100.0)
    var rng := RandomNumberGenerator.new()
    if random_seed == 0:
        rng.randomize()
    else:
        rng.seed = random_seed
    var roll := rng.randi_range(0, 99)
    if float(roll) >= chance:
        return {
            "effect": "firebolt",
            "hit": false,
            "roll": roll,
            "hit_chance": chance,
            "damage": 0,
            "target_health": target.health
        }

    var reduction := maxi(0, target.base_reduction + target.armour_reduction + target.shield_reduction + target.helmet_reduction)
    var damage := maxi(1, magnitude - reduction)
    var lifecycle := target.apply_damage(damage)
    return {
        "effect": "firebolt",
        "hit": true,
        "roll": roll,
        "hit_chance": chance,
        "magnitude": magnitude,
        "reduction": reduction,
        "damage": damage,
        "target_lifecycle": lifecycle,
        "target_health": target.health
    }


func _submit_feint(request: SimulationActionRequest, random_seed: int) -> Dictionary:
    if not pending_reaction.is_empty():
        return {"ok": false, "reason": "reaction_pending"}
    if not is_in_combat or not turn_scheduler.has_active_turn():
        return {"ok": false, "reason": "no_active_combat_turn"}
    if turn_scheduler.current_character_id != request.actor_id:
        return {"ok": false, "reason": "not_attacker_turn"}
    var attacker := get_character(request.actor_id)
    var target := get_character(request.target_id)
    if attacker == null or target == null or not attacker.can_act() or not target.can_be_targeted():
        return {"ok": false, "reason": "combatant_unavailable"}
    if attacker.side == target.side or target.side == "neutral":
        return {"ok": false, "reason": "invalid_feint_target"}
    if HexGrid.distance(attacker.axial, target.axial) != 1:
        return {"ok": false, "reason": "target_out_of_feint_range"}
    var equipped_weapon_data: Dictionary = attacker.equipped_item_data.get("weapon", {})
    var weapon_id := String(attacker.equipment.get("weapon", equipped_weapon_data.get("id", "")))
    var family := CombatRules.weapon_skill_family(weapon_id, ItemCatalog.get_definition(weapon_id))
    if family not in ["sword", "dagger"] or int(attacker.skills.get("%s_feint" % family, 0)) <= 0:
        return {"ok": false, "reason": "feint_skill_or_weapon_required"}
    if not attacker.spend_time_points(1.0):
        return {"ok": false, "reason": "insufficient_time_points"}

    var reactions := _attack_reaction_options(attacker, target, {"is_feint": true})
    if reactions.is_empty():
        if attacker.should_end_turn():
            try_end_current_turn()
        return {"ok": true, "action_type": "feint", "feinted": true, "reaction_offered": false, "time_point_cost": 1.0}
    pending_attack_context = {
        "attacker_id": attacker.id,
        "target_id": target.id,
        "options": {"time_point_cost": 0.0, "is_feint": true},
        "reactions": reactions.duplicate(true),
        "random_seed": random_seed,
        "is_feint": true
    }
    var reaction_result := request_reaction(target.id, reactions, "feint:%s:%s" % [attacker.id, target.id])
    if bool(reaction_result.get("pending", false)):
        return {"ok": true, "pending": true, "action_type": "feint", "request_id": reaction_result.get("request_id", 0)}
    pending_attack_context.clear()
    return {"ok": true, "action_type": "feint", "feinted": true, "reaction_offered": false, "time_point_cost": 1.0}


func _submit_attack(request: SimulationActionRequest, random_seed: int) -> Dictionary:
    if not pending_reaction.is_empty():
        return {"ok": false, "reason": "reaction_pending"}
    if not is_in_combat or not turn_scheduler.has_active_turn():
        return {"ok": false, "reason": "no_active_combat_turn"}
    if turn_scheduler.current_character_id != request.actor_id:
        return {"ok": false, "reason": "not_attacker_turn"}
    var attacker := get_character(request.actor_id)
    var target := get_character(request.target_id)
    if attacker == null or target == null:
        return SimulationActionResult.new("attack", false, "missing_combatant", request.actor_id, request.target_id).to_dict()

    var reactions := _attack_reaction_options(attacker, target, request.options)
    if not reactions.is_empty():
        pending_attack_context = {
            "attacker_id": request.actor_id,
            "target_id": request.target_id,
            "options": request.options.duplicate(true),
            "reactions": reactions.duplicate(true),
            "random_seed": random_seed
        }
        var reaction_result := request_reaction(target.id, reactions, "attack:%s:%s" % [request.actor_id, request.target_id])
        if bool(reaction_result.get("pending", false)):
            return {"ok": true, "pending": true, "action_type": "attack", "request_id": reaction_result.get("request_id", 0)}
        pending_attack_context.clear()

    return _resolve_attack_action(request.actor_id, request.target_id, request.options, random_seed)

## Source-ported sword/dagger parry eligibility. Active dodge is not a separate
## source reaction: passive dodge remains part of hit chance in CombatRules.
func _attack_reaction_options(attacker: CharacterState, target: CharacterState, options: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if target.reaction_blocked:
        return result
    if target.can_act() and target.parries_remaining > 0:
        var weapon_id := String(target.equipment.get("weapon", ""))
        var is_ranged := bool(options.get("is_ranged", String(options.get("weapon_id", "")) == "bow"))
        if not is_ranged or weapon_id == "sword_arrow_deflection":
            var skill_base := "sword" if weapon_id == "sword_arrow_deflection" else weapon_id
            if (skill_base == "sword" or skill_base == "dagger") and int(target.skills.get("%s_parry" % skill_base, 0)) > 0:
                var cost := 3.0
                if int(target.skills.get("%s_parry_cost" % skill_base, 0)) > 0:
                    cost -= 1.0
                if target.can_spend_time_points(cost):
                    result.append({
                        "id": "parry",
                        "name": "Parry",
                        "tp_cost": cost,
                        "effect": "parry",
                        "reactor_id": target.id,
                        "skill_base": skill_base,
                        "attacker_id": attacker.id
                    })

    # Source-backed adjacent ally reactions. The old engine requires an
    # actual shield in the offhand for Shield Other, and a sword/dagger plus
    # matching parry skill for Protector. Equipment dictionaries are explicit
    # item instances; legacy string-only slots are not guessed to be shields.
    for ally_value in characters.values():
        var ally := ally_value as CharacterState
        if ally == null or ally == target or not ally.can_act() or ally.side != target.side or ally.reaction_blocked:
            continue
        if HexGrid.distance(ally.axial, target.axial) > 1:
            continue

        var offhand: Variant = ally.equipped_item_data.get("offhand", ally.equipment.get("offhand", {}))
        if offhand is Dictionary and String(offhand.get("type", "")) == "shield" and ally.can_spend_time_points(1.0):
            result.append({
                "id": "shield_other_%s" % ally.id,
                "name": "Shield Other — %s" % ally.display_name,
                "tp_cost": 1.0,
                "effect": "shield_other",
                "reactor_id": ally.id,
                "shield_reduction": int(offhand.get("reduction", ally.shield_reduction)) + int(ally.skills.get("shield_proficiency", 0))
            })

        var weapon_id := String(ally.equipment.get("weapon", ""))
        if int(ally.skills.get("protector", 0)) > 0 and ally.parries_remaining > 0 and (weapon_id == "sword" or weapon_id == "dagger") and int(ally.skills.get("%s_parry" % weapon_id, 0)) > 0:
            var protector_cost := 2.0 if int(ally.skills.get("%s_parry_cost" % weapon_id, 0)) > 0 else 3.0
            if ally.can_spend_time_points(protector_cost):
                result.append({
                    "id": "protector_parry_%s" % ally.id,
                    "name": "Protector Parry — %s" % ally.display_name,
                    "tp_cost": protector_cost,
                    "effect": "protector_parry",
                    "reactor_id": ally.id,
                    "weapon_id": weapon_id,
                    "parry_skill_base": weapon_id
                })
    return result

func _resume_pending_attack(choice_id: String, reason: String) -> void:
    var context := pending_attack_context.duplicate(true)
    pending_attack_context.clear()
    if reason == "combat_ended":
        return
    var attacker_id := String(context.get("attacker_id", ""))
    var target_id := String(context.get("target_id", ""))
    var attacker := get_character(attacker_id)
    var target := get_character(target_id)
    var options: Dictionary = context.get("options", {})
    var seed := int(context.get("random_seed", 0))
    var is_feint := bool(context.get("is_feint", false))
    if attacker == null or target == null:
        return

    var selected: Dictionary = {}
    for candidate in context.get("reactions", []):
        if String(candidate.get("id", "")) == choice_id:
            selected = candidate
            break

    if reason == "selected" and not selected.is_empty():
        var effect := String(selected.get("effect", ""))
        var reactor := get_character(String(selected.get("reactor_id", target_id)))
        if reactor == null or not reactor.can_act():
            if not is_feint:
                _resolve_attack_action(attacker_id, target_id, options, seed + 1 if seed != 0 else 0)
            return

        if effect == "parry" or effect == "protector_parry":
            if effect == "protector_parry":
                reactor.parries_remaining = maxi(0, reactor.parries_remaining - 1)
            else:
                reactor.parries_remaining = maxi(0, reactor.parries_remaining - 1)
            var skill_base := String(selected.get("skill_base", selected.get("parry_skill_base", reactor.equipment.get("weapon", "sword"))))
            var chance_multiplier := 10.0 if effect == "protector_parry" else 5.0
            var bonus := float(reactor.skills.get("%s_parry_chance" % skill_base, 0)) * chance_multiplier
            var rng_parry := RandomNumberGenerator.new()
            if seed == 0:
                rng_parry.randomize()
            else:
                rng_parry.seed = seed
            var parry_roll := float(rng_parry.randi_range(0, 99))
            var parry_chance := 50.0 + reactor.to_hit_melee + bonus - attacker.passive_dodge
            if parry_roll < parry_chance:
                var attack_cost := float(options.get("time_point_cost", 0.0))
                if attacker.can_spend_time_points(attack_cost):
                    attacker.spend_time_points(attack_cost)
                var riposte_payload: Dictionary = {}
                var riposte_skill := "%s_riposte" % skill_base
                if effect == "parry" and int(reactor.skills.get(riposte_skill, 0)) > 0 and reactor.can_spend_time_points(5.0):
                    reactor.spend_time_points(5.0)
                    var riposte_chance := clampf(50.0 + reactor.to_hit_melee - attacker.passive_dodge, 0.0, 100.0)
                    var riposte_roll := float(rng_parry.randi_range(0, 99))
                    var riposte_damage := 0
                    var riposte_lifecycle := "missed"
                    if riposte_roll < riposte_chance:
                        riposte_damage = maxi(1, reactor.base_damage)
                        riposte_lifecycle = attacker.apply_damage(riposte_damage)
                    riposte_payload = {
                        "attempted": true, "hit": riposte_damage > 0,
                        "roll": riposte_roll, "hit_chance": riposte_chance,
                        "damage": riposte_damage, "attacker_lifecycle": riposte_lifecycle,
                        "attacker_health": attacker.health
                    }
                var parry_payload := {
                    "hit": false, "parried": true, "parry_type": effect,
                    "reactor_id": reactor.id, "parry_roll": parry_roll,
                    "parry_chance": parry_chance, "damage": 0,
                    "riposte": riposte_payload
                }
                var parry_result := SimulationActionResult.new("attack", true, "", attacker_id, target_id, parry_payload).to_dict()
                action_committed.emit(SimulationEvent.new("attack_resolved", attacker_id, target_id, parry_result))
                combat_action_resolved.emit(parry_result)
                if attacker.should_end_turn():
                    try_end_current_turn()
                return

        elif effect == "shield_other":
            if is_feint:
                return
            var bonus_reduction := int(selected.get("shield_reduction", 0))
            target.temp_reduction += bonus_reduction
            var shield_seed := seed + 1 if seed != 0 else 0
            _resolve_attack_action(attacker_id, target_id, options, shield_seed)
            target.temp_reduction -= bonus_reduction
            return

    if is_feint:
        return
    var followup_seed := seed + 1 if seed != 0 else 0
    _resolve_attack_action(attacker_id, target_id, options, followup_seed)

func _movement_reaction_options(mover: CharacterState, next_hex: Vector2i, excluded_character_id: String = "") -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in characters.values():
        var reactor := value as CharacterState
        if reactor == null or reactor == mover or reactor.id == excluded_character_id or not reactor.can_act() or reactor.reaction_blocked:
            continue
        if HexGrid.distance(next_hex, reactor.axial) > 1:
            continue

        var weapon_id := String(reactor.equipment.get("weapon", ""))
        if weapon_id == "spear":
            if int(reactor.skills.get("spear_intercept", 0)) > 0 and reactor.can_spend_time_points(5.0):
                result.append({
                    "id": "spear_intercept_%s" % reactor.id,
                    "name": "Spear Intercept — %s" % reactor.display_name,
                    "tp_cost": 5.0,
                    "effect": "spear_intercept",
                    "reactor_id": reactor.id
                })
            if int(reactor.skills.get("spear_halt", 0)) > 0 and reactor.can_spend_time_points(1.0):
                result.append({
                    "id": "spear_halt_%s" % reactor.id,
                    "name": "Spear Halt — %s" % reactor.display_name,
                    "tp_cost": 1.0,
                    "effect": "spear_halt",
                    "reactor_id": reactor.id
                })

        var armour: Variant = reactor.equipped_item_data.get("armour", reactor.equipment.get("armour", ""))
        var light_or_unarmoured := false
        if armour is Dictionary:
            light_or_unarmoured = String(armour.get("weight_class", "")) == "light"
        else:
            var armour_id := String(armour)
            light_or_unarmoured = armour_id.is_empty() or armour_id == "light_armor"
        if int(reactor.skills.get("sidestep", 0)) > 0 and reactor.sidesteps_remaining > 0 and light_or_unarmoured:
            var sidestep_cost := 5.0 if int(reactor.skills.get("sidestep_mastery", 0)) > 0 else 6.0
            if reactor.can_spend_time_points(sidestep_cost):
                result.append({
                    "id": "sidestep_%s" % reactor.id,
                    "name": "Sidestep — %s" % reactor.display_name,
                    "tp_cost": sidestep_cost,
                    "effect": "sidestep",
                    "reactor_id": reactor.id
                })
    return result


func _sidestep_destination_options(reactor: CharacterState, mover_destination: Vector2i) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for direction in HexGrid.DIRECTIONS:
        var destination: Vector2i = reactor.axial + direction
        if not _is_valid_sidestep_destination(reactor, destination, mover_destination):
            continue
        result.append({
            "id": "sidestep_to_%s_%s" % [destination.x, destination.y],
            "name": "Move to hex (%s, %s)" % [destination.x, destination.y],
            "tp_cost": 0.0,
            "reactor_id": reactor.id,
            "destination": destination
        })
    return result


func _is_valid_sidestep_destination(reactor: CharacterState, destination: Vector2i, mover_destination: Vector2i) -> bool:
    if reactor == null or destination == mover_destination or not _can_move_to(reactor, destination):
        return false
    if map_data.terrain_id_at(destination).to_lower() == "water":
        return false
    # Equal forward/reverse elevation multipliers of 1.0 identify same-height
    # neighbors; a free sidestep must not climb or drop.
    var forward := TerrainElevationRules.movement_multiplier(map_data, reactor.axial, destination, reactor)
    var reverse := TerrainElevationRules.movement_multiplier(map_data, destination, reactor.axial, reactor)
    return is_finite(forward) and is_finite(reverse) and is_equal_approx(forward, 1.0) and is_equal_approx(reverse, 1.0)


func _resume_pending_move(choice_id: String, reason: String) -> void:
    var context := pending_move_context.duplicate(true)
    pending_move_context.clear()
    if reason == "combat_ended":
        return
    var mover := get_character(String(context.get("mover_id", "")))
    var turn_actor := get_character(String(context.get("turn_actor_id", context.get("mover_id", ""))))
    if mover == null or turn_actor == null or not mover.can_act() or not turn_actor.can_act():
        movement_reaction_resolved.emit(String(context.get("turn_actor_id", context.get("mover_id", ""))), true)
        return
    if turn_actor.id != mover.id and turn_actor.mounted_animal_id != mover.id:
        movement_reaction_resolved.emit(turn_actor.id, true)
        return

    var selected: Dictionary = {}
    for option in context.get("reactions", []):
        if String(option.get("id", "")) == choice_id:
            selected = option
            break
    var effect := String(selected.get("effect", "")) if reason == "selected" else ""
    if effect == "spear_intercept":
        var reactor := get_character(String(selected.get("reactor_id", "")))
        if reactor != null and reactor.can_act():
            var rng := RandomNumberGenerator.new()
            var reaction_seed := int(context.get("reaction_request_id", 1))
            rng.seed = maxi(1, reaction_seed)
            var intercept := CombatRules.resolve_attack(reactor, mover, {"time_point_cost": 0.0, "weapon_id": "spear"}, rng)
            if bool(intercept.get("ok", false)):
                var typed_intercept := SimulationActionResult.new("attack", true, "", reactor.id, mover.id, intercept).to_dict()
                action_committed.emit(SimulationEvent.new("attack_resolved", reactor.id, mover.id, typed_intercept))
                combat_action_resolved.emit(typed_intercept)

    var halt_after_step := effect == "spear_halt"
    var origin: Vector2i = context.get("origin", mover.axial)
    var destination: Vector2i = context.get("destination", mover.axial)
    if not mover.can_act() or (turn_actor.id != mover.id and turn_actor.mounted_animal_id != mover.id):
        movement_reaction_resolved.emit(turn_actor.id, true)
        return
    if mover.axial != origin or not _can_move_to(mover, destination):
        movement_reaction_resolved.emit(turn_actor.id, true)
        return
    var cost := float(context.get("time_point_cost", 0.0))
    if not mover.spend_time_points(cost):
        movement_reaction_resolved.emit(turn_actor.id, true)
        return
    _commit_move(mover, destination)
    var payload := {"from_hex": origin, "to_hex": destination, "time_point_cost": cost, "halted_by_reaction": halt_after_step, "movement_owner_id": mover.id}
    var result_data := SimulationActionResult.new("move", true, "", turn_actor.id, "", payload).to_dict()
    action_committed.emit(SimulationEvent.new("character_moved", turn_actor.id, "", result_data))
    movement_reaction_resolved.emit(turn_actor.id, halt_after_step)
    if turn_actor.should_end_turn():
        try_end_current_turn()
func _resolve_attack_action(attacker_id: String, target_id: String, options: Dictionary, random_seed: int) -> Dictionary:
    var attacker := get_character(attacker_id)
    var target := get_character(target_id)
    var rng := RandomNumberGenerator.new()
    if random_seed == 0:
        rng.randomize()
    else:
        rng.seed = random_seed
    var fury := attacker.get_spell_effect("wild_fury")
    var resolved_options := options.duplicate(true)
    var weapon_id := String(attacker.equipment.get("weapon", ""))
    if not fury.is_empty() and weapon_id.is_empty():
        resolved_options["wild_fury_bonus"] = int(fury.get("magnitude", 0))
    var result := CombatRules.resolve_attack(attacker, target, resolved_options, rng)
    if bool(result.get("ok", false)):
        _apply_spell_protection_triggers(attacker, target)
        attacker.remove_spell_effect("sanctuary")
        target.remove_spell_effect("calmed")
        var typed_result := SimulationActionResult.new("attack", true, "", attacker_id, target_id, result)
        var result_data := typed_result.to_dict()
        action_committed.emit(SimulationEvent.new("attack_resolved", attacker_id, target_id, result_data))
        combat_action_resolved.emit(result_data)
        if attacker != null and attacker.should_end_turn():
            try_end_current_turn()
        return result_data
    return SimulationActionResult.new("attack", false, String(result.get("reason", "action_failed")), attacker_id, target_id, result).to_dict()

func _submit_move(request: SimulationActionRequest) -> Dictionary:
    if not pending_reaction.is_empty():
        return {"ok": false, "reason": "reaction_pending"}
    var state := get_character(request.actor_id)
    var terrain_cost := bool(request.options.get("terrain_cost", false))
    var combat_step := bool(request.options.get("combat_step", false))
    if state == null or not state.can_act():
        return {"ok": false, "reason": "actor_unavailable"}
    var movement_state := _movement_state_for(state)
    if not _is_virtual_building_floor_hex(request.destination):
        ensure_exploration_region(request.destination)
    if not _can_move_to(movement_state, request.destination):
        return {"ok": false, "reason": "invalid_destination"}
    if combat_step and is_in_combat:
        if not turn_scheduler.has_active_turn() or turn_scheduler.current_character_id != request.actor_id:
            return {"ok": false, "reason": "not_actor_turn"}
        if state.time_points <= float(ActionEconomy.turn_end_threshold(state.quick_recovery_rank)):
            return {"ok": false, "reason": "turn_movement_exhausted"}
    var cost := request.time_point_cost
    if terrain_cost:
        cost = MovementRules.step_cost(map_data, movement_state.axial, request.destination, movement_state)
    if state.has_spell_effect("entangled"):
        cost += 5.0
    if not is_finite(cost) or cost < 0.0:
        return {"ok": false, "reason": "invalid_action_cost"}
    if not movement_state.can_spend_time_points(cost):
        return {"ok": false, "reason": "insufficient_time_points"}

    if is_in_combat and combat_step:
        var movement_reactions := _movement_reaction_options(movement_state, request.destination, state.id)
        if not movement_reactions.is_empty():
            pending_move_context = {
                "mover_id": movement_state.id,
                "turn_actor_id": state.id,
                "origin": movement_state.axial,
                "destination": request.destination,
                "time_point_cost": cost,
                "reactions": movement_reactions.duplicate(true)
            }
            var first_reactor_id := String(movement_reactions[0].get("reactor_id", ""))
            var reaction_request := request_reaction(first_reactor_id, movement_reactions, "move:%s:%s:%s" % [movement_state.id, request.destination.x, request.destination.y])
            if bool(reaction_request.get("pending", false)):
                pending_move_context["reaction_request_id"] = int(reaction_request.get("request_id", 0))
                return {"ok": true, "pending": true, "action_type": "move", "request_id": reaction_request.get("request_id", 0)}
            pending_move_context.clear()

    var origin := movement_state.axial
    if not movement_state.spend_time_points(cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    _commit_move(movement_state, request.destination)
    var payload := {"from_hex": origin, "to_hex": request.destination, "time_point_cost": cost, "movement_owner_id": movement_state.id}
    var typed_result := SimulationActionResult.new("move", true, "", request.actor_id, "", payload)
    var result_data := typed_result.to_dict()
    action_committed.emit(SimulationEvent.new("character_moved", request.actor_id, "", result_data))
    if is_in_combat and state.should_end_turn():
        try_end_current_turn()
    return result_data
## Shared landing hook for elevation/fall systems. Feather Fall prevents one
## fall event and is consumed; otherwise normal damage/lifecycle rules apply.
func resolve_fall_damage(character_id: String, damage: int) -> Dictionary:
    var state := get_character(character_id)
    if state == null or not state.alive or damage < 0:
        return {"ok": false, "reason": "invalid_fall"}
    if _spell_effect_rules.consume_feather_fall(state):
        var prevented := {"ok": true, "prevented": true, "damage": 0, "character_id": character_id}
        action_committed.emit(SimulationEvent.new("fall_prevented", character_id, "", prevented))
        return prevented
    var lifecycle := state.apply_damage(damage)
    var result := {"ok": true, "prevented": false, "damage": damage, "lifecycle": lifecycle, "health": state.health}
    action_committed.emit(SimulationEvent.new("fall_resolved", character_id, "", result))
    return result


func get_current_turn_character() -> CharacterState:
    if not turn_scheduler.has_active_turn():
        return null
    return get_character(turn_scheduler.current_character_id)

func try_end_current_turn(forced: bool = false) -> bool:
    if not pending_reaction.is_empty() and not forced:
        return false
    var ending_character := get_current_turn_character()
    var ended := turn_scheduler.try_end_turn(characters, forced)
    if ended and ending_character != null and not ending_character.mounted_animal_id.is_empty():
        var mount := get_character(ending_character.mounted_animal_id)
        if mount != null:
            mount.time_points = minf(mount.time_points, float(ActionEconomy.TURN_END_TP))
    return ended
func _advance_character_spell_effects(state: CharacterState, gained_tp: float) -> void:
    if state == null:
        return
    for index in range(state.spell_effects.size() - 1, -1, -1):
        var effect: Dictionary = state.spell_effects[index]
        if String(effect.get("effect_id", "")) == "divine_silence" and gained_tp > 0.0:
            var accumulated := float(effect.get("damage_remainder", 0.0)) + float(effect.get("magnitude", 6)) * 0.05 * gained_tp
            var whole_damage := floori(accumulated)
            if whole_damage > 0:
                state.apply_damage(whole_damage)
                accumulated -= float(whole_damage)
            effect["damage_remainder"] = accumulated
        if effect.has("ticks_remaining"):
            effect["ticks_remaining"] = float(effect.get("ticks_remaining", 0.0)) - 1.0
            if float(effect["ticks_remaining"]) <= 0.0:
                state.spell_effects.remove_at(index)
                continue
        state.spell_effects[index] = effect


func begin_camp(site_data: Dictionary, environment_data: Dictionary = {}, resource_data: Dictionary = {}) -> Dictionary:
    if is_in_combat:
        return {"ok": false, "reason": "cannot_camp_during_combat"}
    var resolved_site := site_data.duplicate(true)
    if site_data.has("hex"):
        var hex_value: Variant = site_data.get("hex")
        if not hex_value is Vector2i:
            return {"ok": false, "reason": "invalid_camp_hex"}
        var camp_hex: Vector2i = hex_value
        if not map_data.has_cell(camp_hex):
            return {"ok": false, "reason": "unknown_camp_hex"}
        resolved_site["walkable"] = map_data.is_walkable(camp_hex)
        resolved_site["occupied"] = occupied_hexes.has(camp_hex)
        resolved_site["terrain_id"] = map_data.terrain_id_at(camp_hex)
    resolved_site["in_combat"] = is_in_combat
    return camp_simulation.begin_camp(resolved_site, party_member_ids, environment_data, resource_data)


func skip_camp_to_morning(hours: float = CampSimulation.DEFAULT_NIGHT_HOURS) -> Dictionary:
    var result := camp_simulation.skip_to_morning(hours)
    if not bool(result.get("ok", false)):
        return result
    clock.advance_world_seconds(float(result.summary.get("hours", hours)) * WorldClock.SECONDS_PER_HOUR)
    return result


func _on_clock_ticked(tick_index: int, world_seconds: float) -> void:
    # Guard direct/test-driven clock advancement as well as the normal
    # _process freeze: no TP or world tick work occurs during an active turn.
    if is_in_combat and (turn_scheduler.has_active_turn() or not pending_reaction.is_empty()):
        return
    for value in characters.values():
        var state := value as CharacterState
        if state != null and state.alive:
            var previous_tp := state.time_points
            state.regenerate_time_points()
            var gained_tp := maxf(0.0, state.time_points - previous_tp)
            # The source engine advances poison and withering only while the
            # entity is below the 150 TP cap, using gained TP as the duration.
            if gained_tp > 0.0 and previous_tp < 150.0:
                for effect_event in StatusEffectRules.advance(state, gained_tp):
                    action_committed.emit(SimulationEvent.new(
                        String(effect_event.get("effect", "status_effect_tick")),
                        state.id,
                        String(effect_event.get("source_id", "")),
                        effect_event
                    ))
            _advance_character_spell_effects(state, gained_tp)
            if state.alive and gained_tp > 0.0 and state.health < state.max_health:
                state.health_regen_remainder += state.health_regeneration_per_time_point() * gained_tp
                var whole_healing := floori(state.health_regen_remainder)
                if whole_healing > 0:
                    state.apply_healing(whole_healing)
                    state.health_regen_remainder -= float(whole_healing)
            elif state.health >= state.max_health:
                state.health_regen_remainder = 0.0

    wilderness_resources.advance_time(world_seconds)
    world_tick.emit(tick_index, world_seconds)

## Debug/prototype movement remains free so the M1 movement harness is usable.
## Gameplay actions should call try_move_character_action and supply the
## resolved TP cost from the movement rules.
func try_move_character(character_id: String, destination: Vector2i) -> bool:
    var state := get_character(character_id)
    if state == null:
        return false
    var movement_state := _movement_state_for(state)
    if not _is_virtual_building_floor_hex(destination):
        ensure_exploration_region(destination)
    if not _can_move_to(movement_state, destination):
        return false
    _commit_move(movement_state, destination)
    return true
func try_move_character_action(character_id: String, destination: Vector2i, time_point_cost: float = 5.0) -> bool:
    var result := submit_action(SimulationActionRequest.move(character_id, destination, time_point_cost))
    return bool(result.get("ok", false))

func ensure_exploration_region(centre: Vector2i, chunk_radius: int = Campaign2WorldCellLoader.DEFAULT_LOAD_RADIUS) -> int:
    return world_cell_loader.load_around(map_data, centre, chunk_radius)

func ensure_resource_at(hex: Vector2i) -> Dictionary:
    return wilderness_resources.ensure_node(hex, map_data.terrain_id_at(hex))

func set_authored_resource_at(hex: Vector2i, terrain_id: String, node: Dictionary) -> void:
    var elevation := map_data.elevation_at(hex)
    map_data.add_cell(hex, elevation, true, terrain_id)
    wilderness_resources.set_authored_node(hex, node)

func harvest_resource_at(character_id: String, hex: Vector2i) -> Dictionary:
    var character := get_character(character_id)
    return wilderness_resources.harvest(hex, map_data.terrain_id_at(hex), character, clock.world_seconds)

func find_path(character_id: String, destination: Vector2i) -> Array[Vector2i]:
    if not _is_virtual_building_floor_hex(destination):
        ensure_exploration_region(destination)
    var state := get_character(character_id)
    if state == null:
        return []
    var movement_state := _movement_state_for(state)
    return HexPathfinder.find_path(map_data, occupied_hexes, movement_state.axial, destination, movement_state, characters, is_in_combat)
func _is_virtual_building_floor_hex(hex: Vector2i) -> bool:
    for definition_value in building_registry.definitions.values():
        if not definition_value is Dictionary:
            continue
        var bounds: Variant = definition_value.get("virtual_floor_bounds", [])
        if bounds is Array and bounds.size() == 4:
            if hex.x >= int(bounds[0]) and hex.x <= int(bounds[1]) and hex.y >= int(bounds[2]) and hex.y <= int(bounds[3]):
                return true
    return false

func movement_cost(character_id: String, destination: Vector2i) -> float:
    var state := get_character(character_id)
    if state == null:
        return INF
    var movement_state := _movement_state_for(state)
    return MovementRules.step_cost(map_data, movement_state.axial, destination, movement_state)
func try_move_character_step(character_id: String, destination: Vector2i) -> bool:
    var request := SimulationActionRequest.move(character_id, destination, 0.0)
    request.options["terrain_cost"] = true
    request.options["combat_step"] = true
    var result := submit_action(request)
    return bool(result.get("ok", false))

func _can_move_to(state: CharacterState, destination: Vector2i) -> bool:
    if state == null:
        return false
    if HexGrid.distance(state.axial, destination) != 1:
        return false
    if not map_data.is_walkable(destination):
        return false
    if occupied_hexes.has(destination):
        var occupant := get_character(String(occupied_hexes[destination]))
        if not _can_pass_through_character(state, occupant):
            return false
        if _find_npc_sidestep_hex(occupant, state.axial) == Vector2i(999999, 999999):
            return false
    return true

func _can_pass_through_character(mover: CharacterState, occupant: CharacterState) -> bool:
    if mover == null or occupant == null:
        return false
    if occupant.impassable_to_player and mover.side != "enemy":
        return false
    if (mover.side == "enemy") != (occupant.side == "enemy") and (mover.side == "enemy" or occupant.side == "enemy"):
        return false
    return true

func _find_npc_sidestep_hex(occupant: CharacterState, mover_origin: Vector2i) -> Vector2i:
    if occupant == null:
        return Vector2i(999999, 999999)
    var candidates := HexGrid.neighbors(occupant.axial)
    candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
        var da := HexGrid.distance(a, mover_origin)
        var db := HexGrid.distance(b, mover_origin)
        if da == db:
            return a.x < b.x if a.x != b.x else a.y < b.y
        return da < db
    )
    for candidate in candidates:
        if candidate == mover_origin or not map_data.is_walkable(candidate) or occupied_hexes.has(candidate):
            continue
        return candidate
    return Vector2i(999999, 999999)

func _commit_move(state: CharacterState, destination: Vector2i) -> void:
    if not _is_virtual_building_floor_hex(destination):
        ensure_exploration_region(destination)
    var origin: Vector2i = state.axial
    var occupant_id := String(occupied_hexes.get(destination, ""))
    if not occupant_id.is_empty():
        var occupant := get_character(occupant_id)
        var sidestep := _find_npc_sidestep_hex(occupant, origin)
        if occupant != null and sidestep != Vector2i(999999, 999999):
            var occupant_origin := occupant.axial
            occupied_hexes.erase(occupant_origin)
            occupant.axial = sidestep
            occupied_hexes[sidestep] = occupant.id
            character_moved.emit(occupant.id, occupant_origin, sidestep)
    ensure_resource_at(destination)
    occupied_hexes.erase(origin)
    state.axial = destination
    occupied_hexes[destination] = state.id
    if not state.mounted_by_id.is_empty():
        var mounted_rider := get_character(state.mounted_by_id)
        if mounted_rider != null and mounted_rider.mounted_animal_id == state.id:
            mounted_rider.axial = destination
            mounted_rider.facing_direction = state.facing_direction
            character_moved.emit(mounted_rider.id, origin, destination)
    character_moved.emit(state.id, origin, destination)
func to_dict() -> Dictionary:
    var character_data: Dictionary = {}
    for character_id in characters:
        var state := characters[character_id] as CharacterState
        character_data[character_id] = state.to_dict()
    return {
        "world_clock": clock.to_dict(),
        "is_in_combat": is_in_combat,
        "player_character_id": player_character_id,
        "party_member_ids": party_member_ids.duplicate(),
        "characters": character_data,
        "wilderness_resources": wilderness_resources.to_dict(),
        "buildings": building_registry.to_dict(),
        "camp_simulation": camp_simulation.to_dict(),
        "companion_bonds": companion_bonds.to_dict(),
    }

func load_dict(data: Dictionary) -> void:
    # CharacterState objects can outlive a restore through references held by
    # presentation or campaign code. Detach them before replacing the registry
    # so stale lifecycle events cannot act on restored characters with the same ID.
    for value in characters.values():
        _detach_character_lifecycle(value as CharacterState)
    characters.clear()
    occupied_hexes.clear()
    party_member_ids.clear()
    player_character_id = String(data.get("player_character_id", "player"))
    clock.load_dict(data.get("world_clock", {}))
    wilderness_resources.load_dict(data.get("wilderness_resources", {}))
    building_registry.load_dict(data.get("buildings", {}))
    camp_simulation = CampSimulation.new()
    var saved_camp: Variant = data.get("camp_simulation", {})
    if saved_camp is Dictionary and not saved_camp.is_empty():
        if not camp_simulation.from_dict(saved_camp):
            push_error("Save contains invalid camp simulation state; camp was reset.")
            camp_simulation = CampSimulation.new()
    companion_bonds = CompanionBondState.new()
    var saved_bonds: Variant = data.get("companion_bonds", {})
    if saved_bonds is Dictionary and not saved_bonds.is_empty():
        if not companion_bonds.from_dict(saved_bonds):
            push_error("Save contains invalid companion bond state; bonds were reset.")
            companion_bonds = CompanionBondState.new()
    for door_id_value in building_registry.doors.keys():
        sync_door_map_state(String(door_id_value))
    is_in_combat = bool(data.get("is_in_combat", false))
    var saved_characters: Dictionary = data.get("characters", {})
    for character_id in saved_characters:
        var state := CharacterState.from_dict(saved_characters[character_id])
        if state.id.is_empty():
            state.id = String(character_id)
        characters[state.id] = state
        # Mounted riders share their mount's hex and do not reserve a second cell.
        if state.mounted_animal_id.is_empty():
            if occupied_hexes.has(state.axial):
                push_error("Save contains overlapping characters at %s." % state.axial)
                characters.erase(state.id)
                continue
            occupied_hexes[state.axial] = state.id
    # Validate reciprocal links after every character has been restored.
    for value in characters.values():
        var state := value as CharacterState
        if state == null:
            continue
        if not state.mounted_animal_id.is_empty():
            var mount := get_character(state.mounted_animal_id)
            if mount == null or mount.mounted_by_id != state.id:
                state.mounted_animal_id = ""
                if not occupied_hexes.has(state.axial):
                    occupied_hexes[state.axial] = state.id
            else:
                state.axial = mount.axial
        if not state.mounted_by_id.is_empty():
            var rider := get_character(state.mounted_by_id)
            if rider == null or rider.mounted_animal_id != state.id:
                state.mounted_by_id = ""
                state.is_rider = false
                state.side = state.mounted_original_side
                state.combat_dormant = state.mounted_original_combat_dormant
    for member_id in data.get("party_member_ids", []):
        var saved_member_id := String(member_id)
        if characters.has(saved_member_id) and not party_member_ids.has(saved_member_id):
            party_member_ids.append(saved_member_id)
    if party_member_ids.is_empty() and characters.has(player_character_id):
        party_member_ids.append(player_character_id)

    # Do not restore transient UI reaction waits or half-finished turns.
    pending_reaction.clear()
    next_reaction_request_id = 1
    for value in characters.values():
        _attach_character_lifecycle(value as CharacterState)
    turn_scheduler.clear()
