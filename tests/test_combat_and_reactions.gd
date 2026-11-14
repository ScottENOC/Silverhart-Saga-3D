extends SceneTree

const INITIATIVE_MODEL = preload("res://scripts/ui/combat_initiative_model.gd")

var _failures: int = 0

func _initialize() -> void:
    _test_combat_turn_scheduler()
    _test_initiative_timeline_model()
    _test_simulation_ownership_snapshots_and_restore()
    _test_combat_resolution()
    _test_status_effects_and_combat_debuffs()
    _test_downed_and_death_lifecycle()
    _test_unified_action_contract()
    _test_attack_waits_for_parry_resolution()
    _test_feint_uses_parry_reaction_without_attacking()
    _test_protector_ally_parry()
    _test_shield_other_reduces_one_attack()
    _test_spear_halt_commits_one_step_then_stops()
    _test_spear_intercept_resolves_before_movement()
    _test_sidestep_uses_a_second_stage_destination()
    _test_reaction_resolution_safety()
    _test_incapacitated_turn_cleanup()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Combat and reactions tests passed.")
    quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
    if not condition:
        _failures += 1
        push_error(message)
func _test_combat_turn_scheduler() -> void:
    var sim := WorldSimulation.new()
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    var guard := CharacterState.new("guard", "Guard", Vector2i(1, 0))
    player.time_points = 99.5
    guard.time_points = 99.0
    sim.register_character(player)
    sim.register_character(guard)
    sim.start_combat()
    _check(sim.advance_world_seconds(0.4) == 1)
    _check(not sim.turn_scheduler.has_active_turn())
    _check(is_equal_approx(player.time_points, 100.5))
    _check(is_equal_approx(guard.time_points, 100.0))
    _check(sim.advance_world_seconds(0.4) == 0)
    _check(sim.turn_scheduler.current_character_id == "player")
    _check(sim.get_current_turn_character() == player)
    _check(is_equal_approx(sim.clock.world_seconds, 0.4))
    _check(is_equal_approx(player.time_points, 100.5))
    _check(is_equal_approx(guard.time_points, 100.0))
    _check(sim.advance_world_seconds(0.4) == 0)
    _check(is_equal_approx(player.time_points, 100.5))
    _check(is_equal_approx(guard.time_points, 100.0))
    _check(not sim.try_end_current_turn())
    player.time_points = 80.0
    _check(sim.try_end_current_turn())
    _check(not sim.turn_scheduler.has_active_turn())
    _check(sim.advance_world_seconds(0.4) == 0)
    _check(sim.turn_scheduler.current_character_id == "guard")
    _check(is_equal_approx(guard.time_points, 100.0))
    var save_data := sim.to_dict()
    var loaded := WorldSimulation.new()
    loaded.load_dict(save_data)
    _check(loaded.is_in_combat)
    _check(loaded.get_character("guard") != null)
    _check(loaded.get_character("player") != null)
    _check(is_equal_approx(loaded.clock.world_seconds, sim.clock.world_seconds))
    var forced_actor := CharacterState.new("forced_actor", "Forced Actor", Vector2i(3, 0))
    forced_actor.time_points = 140.0
    loaded.register_character(forced_actor)
    loaded.turn_scheduler.current_character_id = "forced_actor"
    _check(loaded.try_end_current_turn(true), "Forced end should relinquish the active turn")
    _check(forced_actor.time_points == 80.0, "Voluntary turn end should forfeit unused TP to avoid immediate reselection")
    loaded.free()
    sim.free()

    # Test late entry independently so the new combatant cannot perturb the
    # scheduler's existing initiative-order assertions above.
    var join_sim := WorldSimulation.new()
    var existing := CharacterState.new("existing", "Existing", Vector2i.ZERO)
    existing.side = "player"
    existing.time_points = 50.0
    join_sim.register_character(existing)
    join_sim.start_combat()
    var late_joiner := CharacterState.new("late_joiner", "Late Joiner", Vector2i(1, 0))
    late_joiner.side = "player"
    late_joiner.time_points = 12.0
    join_sim.register_character(late_joiner)
    _check(is_equal_approx(late_joiner.time_points, 100.0), "A character joining an active combat should receive 100 TP")
    _check(join_sim.advance_world_seconds(0.1) == 0)
    _check(join_sim.get_current_turn_character() == late_joiner, "A late entrant at 100 TP should be immediately eligible to act")
    join_sim.free()

func _test_initiative_timeline_model() -> void:
    var fresh := CharacterState.new("fresh", "Fresh Adventurer", Vector2i(-5, 0))
    _check(is_equal_approx(fresh.time_points, 100.0), "New characters should begin with 100 TP")

    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.side = "player"
    player.time_points = 80.0
    var enemy := CharacterState.new("enemy_guard", "Guard", Vector2i(1, 0))
    enemy.side = "enemy"
    enemy.time_points = 120.0
    enemy.health = 64
    enemy.max_health = 120
    enemy.current_mana = 17
    enemy.max_mana = 40
    var downed := CharacterState.new("downed_ally", "Downed Ally", Vector2i(0, 1))
    downed.side = "player"
    downed.time_points = 110.0
    downed.unconscious = true
    var dormant := CharacterState.new("tavern_guest", "Tavern Guest", Vector2i(1, 1))
    dormant.side = "player"
    dormant.combat_dormant = true
    dormant.time_points = 150.0
    var rider := CharacterState.new("horse", "Horse", Vector2i(2, 0))
    rider.side = "player"
    rider.is_rider = true
    rider.time_points = 149.0
    var neutral := CharacterState.new("villager", "Villager", Vector2i(2, 1))
    neutral.side = "neutral"
    neutral.time_points = 148.0

    var characters: Array[CharacterState] = [player, enemy, downed, dormant, rider, neutral]
    var entries: Array[Dictionary] = INITIATIVE_MODEL.build_entries(characters, "player")
    _check(entries.size() == 3, "Initiative should include active player/enemy combatants but exclude dormant NPCs, riders and neutral bystanders")
    _check(String(entries[0]["id"]) == "enemy_guard", "Timeline should sort highest TP first")
    _check(String(entries[1]["id"]) == "downed_ally", "Living unconscious combatants remain visible in the timeline")
    _check(bool(entries[1]["is_unconscious"]) and not bool(entries[1]["can_start_turn"]), "Downed combatants should be visible but not eligible to act")
    _check(String(entries[2]["id"]) == "player" and bool(entries[2]["is_active"]), "Current actor should be marked independently of its TP rank")
    _check(int(entries[0]["health"]) == enemy.health and int(entries[0]["max_health"]) == enemy.max_health, "Initiative entries should expose current and maximum health")
    _check(int(entries[0]["mana"]) == enemy.current_mana and int(entries[0]["max_mana"]) == enemy.max_mana, "Initiative entries should expose current and maximum mana")
    _check(is_equal_approx(ActionEconomy.DEFAULT_MAX_TP, 120.0), "Source entity baseline maxTimePoints is 120, not 150")
    _check(is_equal_approx(ActionEconomy.regenerate(149.0, 1.0, 1.0), 150.0), "TP regeneration should reach the source 150 gate")
    _check(is_equal_approx(ActionEconomy.regenerate(149.5, 1.0, 1.0), 150.5), "The 150 TP regeneration gate should permit a one-tick overshoot")
    _check(is_equal_approx(ActionEconomy.regenerate(150.0, 1.0, 1.0), 150.0), "TP regeneration should pause once current TP reaches 150")

    var tied_a := CharacterState.new("ally_a", "Ally A")
    var tied_b := CharacterState.new("ally_b", "Ally B")
    tied_a.side = "player"
    tied_b.side = "player"
    tied_a.time_points = 100.0
    tied_b.time_points = 100.0
    var tied: Array[CharacterState] = [tied_b, tied_a]
    var tied_entries := INITIATIVE_MODEL.build_entries(tied)
    _check(String(tied_entries[0]["id"]) == "ally_a" and String(tied_entries[1]["id"]) == "ally_b", "Equal TP display order should be stable by ID")

func _test_simulation_ownership_snapshots_and_restore() -> void:
    var sim := WorldSimulation.new()
    var player := CharacterState.new("player", "Player", Vector2i.ZERO)
    player.side = "player"
    var companion := CharacterState.new("companion", "Companion", Vector2i(1, 0))
    companion.side = "player"
    var enemy := CharacterState.new("enemy", "Enemy", Vector2i(2, 0))
    enemy.side = "enemy"
    sim.register_character(player)
    sim.register_character(companion)
    sim.register_character(enemy)

    var states := sim.character_states()
    _check(states.size() == 3, "Character-state snapshots should include all registered characters")
    states.clear()
    _check(sim.get_character("player") == player, "Changing a returned state array must not change the character registry")
    _check(sim.is_hex_occupied(Vector2i(1, 0)) and not sim.is_hex_occupied(Vector2i(9, 9)), "Occupancy queries should reflect registered hexes")

    sim.restore_party_members(["companion", "unknown", "companion", "player"])
    var party_ids := sim.get_party_member_ids()
    _check(party_ids == ["companion", "player"], "Party restore should filter unknown IDs and duplicates while preserving order")
    party_ids.clear()
    _check(sim.get_party_member_ids().size() == 2, "Party ID snapshots must not expose the mutable party registry")
    sim.restore_party_members(["unknown"])
    _check(sim.get_party_member_ids() == ["player"], "Party restore should fall back to the player when no valid IDs remain")

    sim.start_combat()
    sim.turn_scheduler.current_character_id = "player"
    sim.pending_reaction = {"reactor_id": "player"}
    sim.pending_attack_context = {"attacker_id": "player"}
    sim.pending_move_context = {"mover_id": "player"}
    _check(sim.has_pending_reaction(), "Pending reaction query should report an active reaction")
    sim.reset_transient_combat_state()
    _check(not sim.is_in_combat and not sim.has_pending_reaction(), "Restore reset should leave combat inactive with no pending reaction")
    _check(sim.pending_attack_context.is_empty() and sim.pending_move_context.is_empty(), "Restore reset should clear pending action contexts")
    _check(not sim.turn_scheduler.has_active_turn(), "Restore reset should clear the active turn")

    sim.free()


func _test_combat_resolution() -> void:
    var attacker := CharacterState.new("hero", "Hero")
    var target := CharacterState.new("guard", "Guard")
    attacker.side = "player"
    attacker.base_damage = 8
    attacker.to_hit_melee = 20.0
    attacker.time_points = 30.0
    attacker.skills["orc_brute_strength"] = 1
    target.health = 30
    target.max_health = 30
    target.passive_dodge = 10.0
    target.armour_reduction = 3
    target.shield_reduction = 2
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var result := CombatRules.resolve_attack(attacker, target, {
        "time_point_cost": 10.0,
        "weapon_damage": 4,
        "weapon_id": "sword",
        "attacker_terrain_hit_bonus": 5.0
    }, rng)
    _check(bool(result.get("ok", false)))
    _check(float(result.get("hit_chance", 0.0)) == 65.0)
    _check(is_equal_approx(attacker.time_points, 20.0))
    if bool(result.get("hit", false)):
        _check(int(result.get("raw_damage", 0)) == 14)
        _check(int(result.get("reduction", 0)) == 5)
        _check(int(result.get("damage", 0)) == 9)
        _check(target.health == 21)

    var guarded := CharacterState.new("armoured", "Armoured")
    guarded.health = 20
    guarded.max_health = 20
    guarded.base_reduction = 2
    guarded.armour_reduction = 4
    guarded.shield_reduction = 3
    guarded.caught_off_guard = true
    _check(CombatRules.damage_reduction(guarded) == 0)
    guarded.caught_off_guard = false
    guarded.climbing = true
    _check(CombatRules.damage_reduction(guarded) == 6)

    var lethal_rng := RandomNumberGenerator.new()
    lethal_rng.seed = 3
    attacker.to_hit_melee = 100.0
    attacker.time_points = 20.0
    target.health = 1
    target.alive = true
    var lethal := CombatRules.resolve_attack(attacker, target, {
        "time_point_cost": 5.0,
        "weapon_damage": 20
    }, lethal_rng)
    _check(bool(lethal.get("hit", false)))
    _check(bool(lethal.get("target_defeated", false)))
    _check(not target.alive and target.health <= -target.max_health * 0.5)

    var poor := CharacterState.new("poor", "Poor")
    poor.time_points = 1.0
    var before_health := target.health
    var rejected := CombatRules.resolve_attack(poor, target, {"time_point_cost": 5.0}, lethal_rng)
    _check(not bool(rejected.get("ok", false)))
    _check(target.health == before_health)

    var sim := WorldSimulation.new()
    var sim_attacker := CharacterState.new("sim_hero", "Hero", Vector2i.ZERO)
    var sim_target := CharacterState.new("sim_guard", "Guard", Vector2i(1, 0))
    sim_attacker.to_hit_melee = 100.0
    sim_attacker.base_damage = 12
    sim_attacker.time_points = 50.0
    sim.register_character(sim_attacker)
    sim.register_character(sim_target)
    sim.is_in_combat = true
    sim.turn_scheduler.current_character_id = "sim_hero"
    var integrated := sim.try_attack_character("sim_hero", "sim_guard", {
        "time_point_cost": 5.0
    }, 11)
    _check(bool(integrated.get("ok", false)))
    _check(bool(integrated.get("hit", false)))
    _check(sim_target.health == 88)
    _check(is_equal_approx(sim_attacker.time_points, 45.0))
    _check(not bool(sim.try_attack_character("sim_guard", "sim_hero", {}, 11).get("ok", false)))
    sim.free()

func _test_status_effects_and_combat_debuffs() -> void:
    var attacker := CharacterState.new("status_attacker", "Status Attacker")
    attacker.health = 50
    attacker.max_health = 100
    attacker.skills["life_drain"] = 1
    attacker.skills["lich_grave_chill"] = 2
    attacker.skills["lich_withering_touch"] = 2
    attacker.skills["sunder_armor"] = 2
    attacker.skills["hamstring"] = 2
    attacker.skills["unarmed_reaction_block"] = 1
    var target := CharacterState.new("status_target", "Status Target")
    target.base_reduction = 3
    var rng := RandomNumberGenerator.new()
    rng.seed = 17

    StatusEffectRules.apply_on_hit(attacker, target, {"has_weapon": false, "is_ranged": false}, 4, rng)
    _check(attacker.health == 56, "Life Drain heals up to two HP and Grave Chill heals two HP per rank on melee hits")
    _check(target.reaction_blocked, "Unarmed Reaction Block prevents reactions after a successful unarmed hit")
    _check(target.wither_remaining_tp == 5.0 and target.wither_damage_per_tp == 2.0, "Withering Touch adds five TP of damage-over-time at its rank damage")
    _check(target.sunder_stacks == 1 and target.base_reduction == 2, "Sunder Armour removes one point of base reduction per stack")
    _check(target.hobbled_stacks == 1, "Hamstring applies a movement-cost stack on a melee hit")

    StatusEffectRules.apply_on_hit(attacker, target, {"has_weapon": false, "is_ranged": false}, 4, rng)
    StatusEffectRules.apply_on_hit(attacker, target, {"has_weapon": false, "is_ranged": false}, 4, rng)
    _check(target.wither_remaining_tp == 15.0, "Withering Touch adds five duration TP on each successful hit")
    _check(target.sunder_stacks == 2 and target.base_reduction == 1, "Sunder Armour is capped at the attacker's skill rank")
    _check(target.hobbled_stacks == 2, "Hamstring is capped at the attacker's skill rank")

    var poisoner := CharacterState.new("poisoner", "Poisoner")
    poisoner.skills["poison_bite"] = 1
    var poison_proc := false
    for seed in range(1, 100):
        var poison_target := CharacterState.new("poison_target_%d" % seed, "Poison Target")
        rng.seed = seed
        StatusEffectRules.apply_on_hit(poisoner, poison_target, {"has_weapon": true}, 1, rng)
        if poison_target.poison_remaining_tp > 0.0:
            poison_proc = true
            _check(poison_target.poison_remaining_tp == 10.0 and poison_target.poison_damage_per_tp == 2.0, "Poison Bite applies ten TP at two damage per TP")
            break
    _check(poison_proc, "Poison Bite should successfully proc on a deterministic 50% roll")

    var ranged_attacker := CharacterState.new("ranged_status_attacker", "Ranged Status Attacker")
    ranged_attacker.health = 50
    ranged_attacker.max_health = 100
    ranged_attacker.skills["poison_bite"] = 1
    ranged_attacker.skills["life_drain"] = 1
    var ranged_target := CharacterState.new("ranged_status_target", "Ranged Status Target")
    rng.seed = 1
    StatusEffectRules.apply_on_hit(ranged_attacker, ranged_target, {"is_ranged": true, "has_weapon": true}, 4, rng)
    _check(ranged_attacker.health == 50, "Life Drain does not trigger on ranged attacks")
    _check(ranged_target.poison_remaining_tp == 0.0, "Poison Bite does not trigger on ranged attacks")

    var ticking := CharacterState.new("status_ticking", "Status Ticking")
    ticking.health = 100
    ticking.max_health = 100
    ticking.poison_remaining_tp = 10.0
    ticking.poison_damage_per_tp = 2.0
    ticking.poison_source_id = poisoner.id
    ticking.wither_remaining_tp = 5.0
    ticking.wither_damage_per_tp = 2.0
    ticking.wither_source_id = attacker.id
    var tick_events := StatusEffectRules.advance(ticking, 2.5)
    _check(ticking.health == 90, "Poison and withering each deal damage proportional to gained TP")
    _check(is_equal_approx(ticking.poison_remaining_tp, 7.5) and is_equal_approx(ticking.wither_remaining_tp, 2.5), "Damage-over-time durations decrease by gained TP")
    _check(tick_events.size() == 2, "Each active damage-over-time effect emits a tick event")

    var saved := ticking.to_dict()
    var restored := CharacterState.from_dict(saved)
    _check(is_equal_approx(restored.poison_remaining_tp, ticking.poison_remaining_tp), "Poison duration survives save/load")
    _check(is_equal_approx(restored.wither_remaining_tp, ticking.wither_remaining_tp), "Withering duration survives save/load")
    _check(restored.poison_source_id == poisoner.id and restored.wither_source_id == attacker.id, "Damage-over-time source attribution survives save/load")

    var poison_lethal := CharacterState.new("poison_lethal", "Poison Lethal")
    poison_lethal.health = 2
    poison_lethal.poison_remaining_tp = 1.0
    poison_lethal.poison_damage_per_tp = 2.0
    StatusEffectRules.advance(poison_lethal, 1.0)
    _check(not poison_lethal.alive and not poison_lethal.unconscious, "Poison kills at zero HP, matching the original engine")

    var movement_map := HexMapData.new()
    movement_map.add_cell(Vector2i.ZERO)
    movement_map.add_cell(Vector2i(1, 0))
    var unhampered := CharacterState.new("unhampered", "Unhampered", Vector2i.ZERO)
    var hobbled := CharacterState.new("hobbled", "Hobbled", Vector2i.ZERO)
    hobbled.hobbled_stacks = 2
    _check(is_equal_approx(MovementRules.step_cost(movement_map, Vector2i.ZERO, Vector2i(1, 0), unhampered), 5.0), "Normal movement cost remains unchanged")
    _check(is_equal_approx(MovementRules.step_cost(movement_map, Vector2i.ZERO, Vector2i(1, 0), hobbled), 7.0), "Each Hamstring stack increases movement cost by twenty percent")

func _test_downed_and_death_lifecycle() -> void:
    var target := CharacterState.new("target", "Target")
    target.max_health = 100
    target.health = 20
    _check(target.apply_damage(40) == "downed")
    _check(target.alive and target.unconscious)
    _check(target.health == -20, "Downed HP remains negative rather than clamping to zero")
    _check(target.can_be_targeted(), "Unconscious living characters remain valid targets")
    _check(not target.can_act(), "Unconscious characters cannot act")
    _check(not target.can_start_combat_turn(), "Unconscious characters cannot receive turns")
    _check(target.apply_healing(25) == "revived_from_unconscious")
    _check(target.health == 5 and not target.unconscious and target.alive)
    _check(target.apply_damage(56) == "died")
    _check(not target.alive and not target.unconscious)
    _check(target.health <= -50, "True death occurs at or below -50% maximum HP")
    _check(target.apply_healing(100) == "unchanged", "Healing does not silently resurrect true-dead characters")
    var second := CharacterState.new("second", "Second")
    second.health = 1
    second.apply_damage(51)
    _check(not second.alive and not second.unconscious, "Exact -50% HP boundary is true death")

func _test_unified_action_contract() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i(0, 0))
    sim.map_data.add_cell(Vector2i(1, 0))
    var mover := CharacterState.new("mover", "Mover", Vector2i.ZERO)
    mover.time_points = 20.0
    sim.register_character(mover)
    var move_result := sim.submit_action(SimulationActionRequest.move("mover", Vector2i(1, 0), 5.0))
    _check(bool(move_result.get("ok", false)))
    _check(mover.axial == Vector2i(1, 0))
    _check(is_equal_approx(mover.time_points, 15.0))
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i(0, 1))
    var victim := CharacterState.new("victim", "Victim", Vector2i(1, 1))
    attacker.to_hit_melee = 100.0
    attacker.base_damage = 10
    attacker.time_points = 20.0
    victim.health = 10
    victim.max_health = 100
    sim.register_character(attacker)
    sim.register_character(victim)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "attacker"
    var attack_result := sim.submit_action(SimulationActionRequest.attack("attacker", "victim", {"time_point_cost": 5.0}), 19)
    _check(bool(attack_result.get("ok", false)))
    _check(victim.unconscious and victim.alive, "Attack downs rather than kills in the negative HP band")
    _check(bool(attack_result.get("target_unconscious", false)))
    _check(String(attack_result.get("action_type", "")) == "attack")
    sim.free()

func _test_attack_waits_for_parry_resolution() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i.ZERO)
    var defender := CharacterState.new("defender", "Defender", Vector2i(1, 0))
    attacker.to_hit_melee = 100.0
    attacker.base_damage = 20
    attacker.time_points = 30.0
    defender.time_points = 20.0
    defender.health = 100
    defender.max_health = 100
    defender.to_hit_melee = 100.0
    defender.base_damage = 2
    defender.equipment["weapon"] = "sword"
    defender.skills["sword_parry"] = 1
    defender.skills["sword_riposte"] = 1
    sim.register_character(attacker)
    sim.register_character(defender)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "attacker"

    var pending := sim.try_attack_character("attacker", "defender", {"time_point_cost": 5.0}, 41)
    _check(bool(pending.get("pending", false)), "A qualified defender should be offered a parry before damage resolves")
    _check(defender.health == 100, "Damage must not land while the reaction is pending")
    _check(is_equal_approx(attacker.time_points, 30.0), "Attacker TP must not be spent before the reaction resolves")
    var resolved := sim.resolve_reaction("parry")
    _check(bool(resolved.get("ok", false)))
    _check(defender.health == 100, "A successful parry cancels the incoming attack")
    _check(attacker.health == 98, "Sword Riposte immediately makes a basic counterattack after a successful parry")
    _check(defender.parries_remaining == 2, "A parry consumes one per-turn parry use")
    _check(is_equal_approx(defender.time_points, 12.0), "The defender pays 3 TP to parry and 5 TP to riposte")
    _check(is_equal_approx(attacker.time_points, 25.0), "A successful parry still consumes the attack action's TP cost")
    sim.free()

func _test_feint_uses_parry_reaction_without_attacking() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    var attacker := CharacterState.new("feinter", "Feinter", Vector2i.ZERO)
    var defender := CharacterState.new("feint_defender", "Feint Defender", Vector2i(1, 0))
    attacker.side = "player"
    attacker.time_points = 10.0
    attacker.equipment["weapon"] = "sword"
    attacker.skills["sword_feint"] = 1
    defender.side = "enemy"
    defender.time_points = 20.0
    defender.to_hit_melee = 100.0
    defender.equipment["weapon"] = "sword"
    defender.skills["sword_parry"] = 1
    sim.register_character(attacker)
    sim.register_character(defender)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "feinter"

    var pending := sim.submit_action(SimulationActionRequest.feint("feinter", "feint_defender"), 123)
    _check(bool(pending.get("pending", false)), "A valid sword feint should request the defender's parry reaction")
    _check(is_equal_approx(attacker.time_points, 9.0), "Feint should cost one TP before the reaction")
    var resolved := sim.resolve_reaction("parry")
    _check(bool(resolved.get("ok", false)))
    _check(defender.parries_remaining == 2, "A feint should consume a parry when the defender takes the bait")
    _check(is_equal_approx(defender.time_points, 17.0), "Defender pays the normal parry cost against a feint")
    _check(attacker.health == 100 and defender.health == 100, "Feint itself should not deal attack damage")
    _check(is_equal_approx(attacker.time_points, 9.0), "Feint should not also charge a normal attack")
    sim.free()

func _test_protector_ally_parry() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i.ZERO)
    var target := CharacterState.new("target", "Target", Vector2i(1, 0))
    var protector := CharacterState.new("protector", "Protector", Vector2i(0, 1))
    attacker.to_hit_melee = 100.0
    attacker.base_damage = 20
    attacker.time_points = 30.0
    target.side = "player"
    target.time_points = 10.0
    protector.side = "player"
    protector.time_points = 20.0
    protector.to_hit_melee = 100.0
    protector.equipment["weapon"] = "sword"
    protector.skills["protector"] = 1
    protector.skills["sword_parry"] = 1
    sim.register_character(attacker)
    sim.register_character(target)
    sim.register_character(protector)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "attacker"

    var pending := sim.try_attack_character("attacker", "target", {"time_point_cost": 5.0}, 77)
    _check(bool(pending.get("pending", false)), "An eligible adjacent Protector should be offered a reaction")
    _check(target.health == 100, "Protector choice must be offered before attack damage")
    var chosen := sim.resolve_reaction("protector_parry_protector")
    _check(bool(chosen.get("ok", false)))
    _check(target.health == 100, "A successful Protector parry cancels the attack")
    _check(protector.parries_remaining == 2, "Protector consumes one parry allowance")
    _check(is_equal_approx(protector.time_points, 17.0), "Protector pays their own 3 TP")
    _check(is_equal_approx(target.time_points, 10.0), "Protected target does not pay the ally's TP cost")
    _check(is_equal_approx(attacker.time_points, 25.0), "A successful Protector parry still charges the attack")
    sim.free()

func _test_shield_other_reduces_one_attack() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    var attacker := CharacterState.new("attacker", "Attacker", Vector2i.ZERO)
    var target := CharacterState.new("target", "Target", Vector2i(1, 0))
    var protector := CharacterState.new("shield_ally", "Shield Ally", Vector2i(0, 1))
    attacker.to_hit_melee = 100.0
    attacker.base_damage = 20
    attacker.time_points = 30.0
    target.side = "player"
    target.time_points = 10.0
    protector.side = "player"
    protector.time_points = 20.0
    protector.equipment["offhand"] = {"id": "round_shield", "type": "shield", "reduction": 4}
    protector.skills["shield_other"] = 1
    protector.skills["shield_proficiency"] = 1
    sim.register_character(attacker)
    sim.register_character(target)
    sim.register_character(protector)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "attacker"

    var pending := sim.try_attack_character("attacker", "target", {"time_point_cost": 5.0}, 91)
    _check(bool(pending.get("pending", false)), "An adjacent shield ally should be offered Shield Other")
    var chosen := sim.resolve_reaction("shield_other_shield_ally")
    _check(bool(chosen.get("ok", false)))
    _check(target.health == 85, "Shield Other should reduce only this incoming hit by shield plus proficiency")
    _check(target.temp_reduction == 0, "Temporary Shield Other reduction must be removed after the attack")
    _check(is_equal_approx(protector.time_points, 19.0), "Shield Other ally pays 1 TP")
    _check(is_equal_approx(target.time_points, 10.0), "Protected target does not pay ally TP")
    sim.free()

func _test_spear_halt_commits_one_step_then_stops() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    var mover := CharacterState.new("mover", "Mover", Vector2i.ZERO)
    var guard := CharacterState.new("guard", "Spear Guard", Vector2i(0, 1))
    mover.time_points = 100.0
    guard.time_points = 20.0
    guard.equipment["weapon"] = "spear"
    guard.skills["spear_halt"] = 1
    sim.register_character(mover)
    sim.register_character(guard)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "mover"
    var halt_events := [false]
    sim.movement_reaction_resolved.connect(func(_id: String, halted: bool) -> void: halt_events[0] = halted)

    var pending := sim.try_move_character_step("mover", Vector2i(1, 0))
    _check(pending and not sim.pending_reaction.is_empty(), "Spear Halt should pause the movement step")
    _check(mover.axial == Vector2i.ZERO, "Mover must not commit position before the reaction resolves")
    var resolved := sim.resolve_reaction("spear_halt_guard")
    _check(bool(resolved.get("ok", false)))
    _check(mover.axial == Vector2i(1, 0), "Spear Halt commits the triggering step")
    _check(halt_events[0], "Spear Halt signals the path controller to stop remaining steps")
    _check(is_equal_approx(guard.time_points, 19.0), "Spear Halt costs 1 TP")
    sim.free()

func _test_spear_intercept_resolves_before_movement() -> void:
    var sim := WorldSimulation.new()
    sim.map_data.add_cell(Vector2i.ZERO)
    sim.map_data.add_cell(Vector2i(1, 0))
    sim.map_data.add_cell(Vector2i(0, 1))
    var mover := CharacterState.new("mover", "Mover", Vector2i.ZERO)
    var guard := CharacterState.new("interceptor", "Spear Guard", Vector2i(0, 1))
    mover.time_points = 100.0
    mover.health = 100
    guard.time_points = 20.0
    guard.to_hit_melee = 100.0
    guard.base_damage = 10
    guard.equipment["weapon"] = "spear"
    guard.skills["spear_intercept"] = 1
    sim.register_character(mover)
    sim.register_character(guard)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "mover"

    var pending := sim.try_move_character_step("mover", Vector2i(1, 0))
    _check(pending and not sim.pending_reaction.is_empty(), "Spear Intercept should pause movement")
    var resolved := sim.resolve_reaction("spear_intercept_interceptor")
    _check(bool(resolved.get("ok", false)))
    _check(mover.health == 90, "Spear Intercept attacks the mover before the step commits")
    _check(mover.axial == Vector2i(1, 0), "Movement continues after Spear Intercept")
    _check(is_equal_approx(guard.time_points, 15.0), "Spear Intercept costs 5 TP")
    sim.free()

func _test_sidestep_uses_a_second_stage_destination() -> void:
    var sim := WorldSimulation.new()
    for q in range(-1, 3):
        for r in range(-1, 3):
            sim.map_data.add_cell(Vector2i(q, r))
    var mover := CharacterState.new("mover", "Mover", Vector2i.ZERO)
    var defender := CharacterState.new("sidestepper", "Sidestepper", Vector2i(0, 1))
    mover.time_points = 100.0
    defender.time_points = 20.0
    defender.skills["sidestep"] = 1
    defender.sidesteps_remaining = 3
    sim.register_character(mover)
    sim.register_character(defender)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "mover"

    var pending := sim.try_move_character_step("mover", Vector2i(1, 0))
    _check(pending and not sim.pending_reaction.is_empty(), "Sidestep should be offered as a movement reaction")
    var first_stage := sim.resolve_reaction("sidestep_sidestepper")
    _check(bool(first_stage.get("pending", false)) and String(first_stage.get("stage", "")) == "sidestep_destination", "Choosing Sidestep opens a destination stage without spending TP")
    _check(is_equal_approx(defender.time_points, 20.0), "Sidestep TP is not spent before a destination is chosen")
    var second_stage := sim.resolve_reaction("sidestep_to_1_1")
    _check(bool(second_stage.get("ok", false)))
    _check(defender.axial == Vector2i(1, 1), "Sidestep moves the reactor to the selected adjacent free hex")
    _check(defender.sidesteps_remaining == 2, "Sidestep consumes one allowance")
    _check(is_equal_approx(defender.time_points, 14.0), "Sidestep costs 6 TP")
    _check(mover.axial == Vector2i(1, 0), "Mover continues after Sidestep")
    sim.free()

func _test_reaction_resolution_safety() -> void:
    var sim := WorldSimulation.new()
    var reactor := CharacterState.new("reactor", "Reactor", Vector2i.ZERO)
    reactor.time_points = 20.0
    sim.register_character(reactor)
    sim.start_combat()
    var requested_count := [0]
    var resolved_count := [0]
    var last_choice := [""]
    var last_reason := [""]
    sim.reaction_requested.connect(func(_id: String, _options: Array[Dictionary], _request_id: int, _source: String) -> void:
        requested_count[0] += 1
    )
    sim.reaction_resolved.connect(func(_id: String, choice: String, _request_id: int, reason: String) -> void:
        resolved_count[0] += 1
        last_choice[0] = choice
        last_reason[0] = reason
    )

    reactor.alive = false
    var dead_result := sim.request_reaction("reactor", [{"id": "parry", "name": "Parry", "tp_cost": 3.0}])
    _check(bool(dead_result.get("ok", false)) and not bool(dead_result.get("pending", true)))
    _check(resolved_count[0] == 1 and last_choice[0].is_empty())
    _check(last_reason[0] == "reactor_unavailable")
    _check(requested_count[0] == 0 and sim.pending_reaction.is_empty())

    reactor.alive = true
    reactor.unconscious = true
    var unconscious_result := sim.request_reaction("reactor", [{"id": "parry", "tp_cost": 3.0}])
    _check(not bool(unconscious_result.get("pending", true)))
    _check(resolved_count[0] == 2 and last_choice[0].is_empty())
    _check(sim.pending_reaction.is_empty())

    reactor.unconscious = false
    var opened := sim.request_reaction("reactor", [
        {"id": "parry", "name": "Parry", "tp_cost": 3.0},
        {"id": "dodge", "name": "Dodge", "tp_cost": 5.0}
    ], "attack_001")
    _check(bool(opened.get("pending", false)))
    _check(requested_count[0] == 1 and not sim.pending_reaction.is_empty())
    _check(not sim.try_end_current_turn(), "A pending reaction must prevent normal turn completion")
    _check(not sim.resolve_reaction("unknown").get("ok", false), "Invalid choices must not consume the pending request")
    var chosen := sim.resolve_reaction("parry")
    _check(bool(chosen.get("ok", false)) and String(chosen.get("choice_id", "")) == "parry")
    _check(is_equal_approx(reactor.time_points, 17.0))
    _check(resolved_count[0] == 3 and last_choice[0] == "parry" and last_reason[0] == "selected")
    _check(sim.pending_reaction.is_empty())

    reactor.time_points = 20.0
    var death_wait := sim.request_reaction("reactor", [{"id": "parry", "tp_cost": 3.0}], "attack_002")
    _check(bool(death_wait.get("pending", false)))
    reactor.apply_damage(150)
    _check(not reactor.alive)
    _check(sim.pending_reaction.is_empty(), "Death while a reaction is pending must clear the wait immediately")
    _check(resolved_count[0] == 4 and last_choice[0].is_empty() and last_reason[0] == "reactor_incapacitated")

    reactor.alive = true
    reactor.health = 100
    reactor.unconscious = false
    reactor.reaction_blocked = true
    var blocked := sim.request_reaction("reactor", [{"id": "parry", "tp_cost": 3.0}])
    _check(not bool(blocked.get("pending", true)) and String(blocked.get("reason", "")) == "reactor_unavailable")
    _check(sim.pending_reaction.is_empty())
    sim.free()

func _test_incapacitated_turn_cleanup() -> void:
    var sim := WorldSimulation.new()
    var actor := CharacterState.new("actor", "Actor", Vector2i.ZERO)
    actor.time_points = 120.0
    sim.register_character(actor)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = "actor"
    actor.apply_damage(150)
    _check(not sim.turn_scheduler.has_active_turn(), "An incapacitated active combatant must relinquish their turn")
    sim.free()
