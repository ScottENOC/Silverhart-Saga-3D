class_name WorldSimulation
extends Node

signal character_moved(character_id: String, from_hex: Vector2i, to_hex: Vector2i)
signal world_tick(tick_index: int, world_seconds: float)
signal combat_started
signal combat_ended
signal combat_action_resolved(result: Dictionary)
signal action_committed(event: SimulationEvent)
signal reaction_requested(reactor_id: String, options: Array[Dictionary], request_id: int, source_event_id: String)
signal reaction_resolved(reactor_id: String, choice_id: String, request_id: int, reason: String)

var map_data: HexMapData = HexMapData.new()
var characters: Dictionary = {}
var occupied_hexes: Dictionary = {}
var player_character_id: String = "player"
var clock: WorldClock = WorldClock.new()
var turn_scheduler: CombatTurnScheduler = CombatTurnScheduler.new()
var is_in_combat: bool = false
var pending_reaction: Dictionary = {}
var next_reaction_request_id: int = 1
var pending_attack_context: Dictionary = {}

func _init() -> void:
    clock.ticked.connect(_on_clock_ticked)
    turn_scheduler.turn_started.connect(_on_combat_turn_started)

func _on_combat_turn_started(character_id: String) -> void:
    var state := get_character(character_id)
    if state != null:
        state.parries_remaining = 3

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
    characters[state.id] = state
    occupied_hexes[state.axial] = state.id
    _attach_character_lifecycle(state)

func get_character(character_id: String) -> CharacterState:
    return characters.get(character_id) as CharacterState

func start_combat() -> void:
    if is_in_combat:
        return
    is_in_combat = true
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
    var cost := float(selected.get("tp_cost", 0.0))
    if not state.spend_time_points(cost):
        return _finish_pending_reaction("", "insufficient_time_points")
    pending_reaction["selected_reactor_id"] = reactor_id
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

func _on_character_lifecycle_changed(character_id: String, _transition: String) -> void:
    var state := get_character(character_id)
    if state == null:
        return
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
        SimulationActionRequest.ActionType.MOVE:
            return _submit_move(request)
        _:
            return {"ok": false, "reason": "unsupported_action_type"}

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
    if target.reaction_blocked or not target.can_act() or target.parries_remaining <= 0:
        return result
    var weapon_id := String(target.equipment.get("weapon", ""))
    var is_ranged := bool(options.get("is_ranged", String(options.get("weapon_id", "")) == "bow"))
    if is_ranged and weapon_id != "sword_arrow_deflection":
        return result
    var skill_base := "sword" if weapon_id == "sword_arrow_deflection" else weapon_id
    if skill_base != "sword" and skill_base != "dagger":
        return result
    if int(target.skills.get("%s_parry" % skill_base, 0)) <= 0 or target.time_points < 3.0:
        return result
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

        var offhand: Variant = ally.equipment.get("offhand", {})
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
                var parry_payload := {
                    "hit": false, "parried": true, "parry_type": effect,
                    "reactor_id": reactor.id, "parry_roll": parry_roll,
                    "parry_chance": parry_chance, "damage": 0
                }
                var parry_result := SimulationActionResult.new("attack", true, "", attacker_id, target_id, parry_payload).to_dict()
                action_committed.emit(SimulationEvent.new("attack_resolved", attacker_id, target_id, parry_result))
                combat_action_resolved.emit(parry_result)
                if attacker.should_end_turn():
                    try_end_current_turn()
                return

        elif effect == "shield_other":
            var bonus_reduction := int(selected.get("shield_reduction", 0))
            target.temp_reduction += bonus_reduction
            var shield_seed := seed + 1 if seed != 0 else 0
            _resolve_attack_action(attacker_id, target_id, options, shield_seed)
            target.temp_reduction -= bonus_reduction
            return

    var followup_seed := seed + 1 if seed != 0 else 0
    _resolve_attack_action(attacker_id, target_id, options, followup_seed)

func _resolve_attack_action(attacker_id: String, target_id: String, options: Dictionary, random_seed: int) -> Dictionary:
    var attacker := get_character(attacker_id)
    var target := get_character(target_id)
    var rng := RandomNumberGenerator.new()
    if random_seed == 0:
        rng.randomize()
    else:
        rng.seed = random_seed
    var result := CombatRules.resolve_attack(attacker, target, options, rng)
    if bool(result.get("ok", false)):
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
    if not _can_move_to(state, request.destination):
        return {"ok": false, "reason": "invalid_destination"}
    if combat_step and is_in_combat:
        if not turn_scheduler.has_active_turn() or turn_scheduler.current_character_id != request.actor_id:
            return {"ok": false, "reason": "not_actor_turn"}
        if state.time_points <= float(ActionEconomy.turn_end_threshold(state.quick_recovery_rank)):
            return {"ok": false, "reason": "turn_movement_exhausted"}
    var cost := request.time_point_cost
    if terrain_cost:
        cost = MovementRules.step_cost(map_data, state.axial, request.destination, state)
    if not is_finite(cost) or cost < 0.0:
        return {"ok": false, "reason": "invalid_action_cost"}
    if not state.can_spend_time_points(cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    var origin := state.axial
    if not state.spend_time_points(cost):
        return {"ok": false, "reason": "insufficient_time_points"}
    _commit_move(state, request.destination)
    var payload := {"from_hex": origin, "to_hex": request.destination, "time_point_cost": cost}
    var typed_result := SimulationActionResult.new("move", true, "", request.actor_id, "", payload)
    var result_data := typed_result.to_dict()
    action_committed.emit(SimulationEvent.new("character_moved", request.actor_id, "", result_data))
    if is_in_combat and state.should_end_turn():
        try_end_current_turn()
    return result_data

func get_current_turn_character() -> CharacterState:
    if not turn_scheduler.has_active_turn():
        return null
    return get_character(turn_scheduler.current_character_id)

func try_end_current_turn(forced: bool = false) -> bool:
    if not pending_reaction.is_empty() and not forced:
        return false
    return turn_scheduler.try_end_turn(characters, forced)

func _on_clock_ticked(tick_index: int, world_seconds: float) -> void:
    # Guard direct/test-driven clock advancement as well as the normal
    # _process freeze: no TP or world tick work occurs during an active turn.
    if is_in_combat and (turn_scheduler.has_active_turn() or not pending_reaction.is_empty()):
        return
    for value in characters.values():
        var state := value as CharacterState
        if state != null and state.alive:
            state.regenerate_time_points()

    world_tick.emit(tick_index, world_seconds)

## Debug/prototype movement remains free so the M1 movement harness is usable.
## Gameplay actions should call try_move_character_action and supply the
## resolved TP cost from the movement rules.
func try_move_character(character_id: String, destination: Vector2i) -> bool:
    var state := get_character(character_id)
    if not _can_move_to(state, destination):
        return false
    _commit_move(state, destination)
    return true

func try_move_character_action(character_id: String, destination: Vector2i, time_point_cost: float = 5.0) -> bool:
    var result := submit_action(SimulationActionRequest.move(character_id, destination, time_point_cost))
    return bool(result.get("ok", false))

func find_path(character_id: String, destination: Vector2i) -> Array[Vector2i]:
    var state := get_character(character_id)
    if state == null:
        return []
    return HexPathfinder.find_path(map_data, occupied_hexes, state.axial, destination, state)

func movement_cost(character_id: String, destination: Vector2i) -> float:
    var state := get_character(character_id)
    if state == null:
        return INF
    return MovementRules.step_cost(map_data, state.axial, destination, state)

## Execute one adjacent step using the same cost used by pathfinding.
## In combat, the final step may take TP below the normal turn-end threshold,
## matching the original game's movement allowance.
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
        return false
    return true

func _commit_move(state: CharacterState, destination: Vector2i) -> void:
    var origin: Vector2i = state.axial
    occupied_hexes.erase(origin)
    state.axial = destination
    occupied_hexes[destination] = state.id
    character_moved.emit(state.id, origin, destination)

func to_dict() -> Dictionary:
    var character_data: Dictionary = {}
    for character_id in characters:
        var state := characters[character_id] as CharacterState
        character_data[character_id] = state.to_dict()
    return {
        "world_clock": clock.to_dict(),
        "is_in_combat": is_in_combat,
        "characters": character_data,
    }

func load_dict(data: Dictionary) -> void:
    characters.clear()
    occupied_hexes.clear()
    clock.load_dict(data.get("world_clock", {}))
    is_in_combat = bool(data.get("is_in_combat", false))
    var saved_characters: Dictionary = data.get("characters", {})
    for character_id in saved_characters:
        var state := CharacterState.from_dict(saved_characters[character_id])
        if state.id.is_empty():
            state.id = String(character_id)
        if occupied_hexes.has(state.axial):
            push_error("Save contains overlapping characters at %s." % state.axial)
            continue
        characters[state.id] = state
        occupied_hexes[state.axial] = state.id

    # Do not restore transient UI reaction waits or half-finished turns.
    pending_reaction.clear()
    next_reaction_request_id = 1
    for value in characters.values():
        _attach_character_lifecycle(value as CharacterState)
    # The active character's TP is preserved; initiative is selected again.
    turn_scheduler.clear()
