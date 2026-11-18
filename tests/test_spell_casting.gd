extends SceneTree

var _failures: int = 0


func _initialize() -> void:
    _test_firebolt_uses_shared_action_and_pays_costs()
    _test_heal_uses_shared_action_and_wakes_target()
    _test_rejected_cast_does_not_spend_resources()
    _test_burst_firebolt_uses_area_effect()
    _test_armour_penalty_and_blood_magic()
    _test_combat_ai_casts_firebolt()
    _test_combat_ai_heals_ally()
    if _failures > 0:
        push_error("%d spell casting assertion(s) failed." % _failures)
        quit(1)
        return
    print("Spell casting and AI tests passed.")
    quit(0)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error("FAIL: " + message)


func _new_character(id: String, side: String, hex: Vector2i) -> CharacterState:
    var state := CharacterState.new(id, id, hex)
    state.side = side
    state.time_points = 100.0
    state.current_mana = 20
    state.max_mana = 20
    return state


func _test_firebolt_uses_shared_action_and_pays_costs() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("caster", "player", Vector2i.ZERO)
    var target := _new_character("target", "enemy", Vector2i(3, 0))
    caster.unlocked_base_spells.append("firebolt")
    caster.skills["firebolt_hit"] = 10
    target.health = 30
    var prepared_firebolt := PreparedSpell.create("firebolt")
    caster.prepared_spells.append(prepared_firebolt.to_dict())
    simulation.register_character(caster)
    simulation.register_character(target)

    var request := SimulationActionRequest.cast_spell(caster.id, target.id, prepared_firebolt)
    var result := simulation.submit_action(request, 1234)
    _check(bool(result.get("ok", false)), "Firebolt should resolve through submit_action")
    _check(bool(result.get("hit", false)), "Firebolt with maximum hit skill should hit")
    _check(target.health == 25, "Firebolt should apply its base magnitude as damage")
    _check(caster.current_mana == 15, "Firebolt should spend its five mana cost")
    _check(is_equal_approx(caster.time_points, 90.0), "Firebolt should spend ten Time Points")
    _check(String(result.get("action_type", "")) == "cast_spell", "Spell result should use the shared action result shape")


func _test_heal_uses_shared_action_and_wakes_target() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("healer", "player", Vector2i.ZERO)
    var target := _new_character("wounded_ally", "player", Vector2i(1, 0))
    caster.unlocked_base_spells.append("heal")
    target.health = 0
    target.unconscious = true
    var prepared_heal := PreparedSpell.create("heal")
    caster.prepared_spells.append(prepared_heal.to_dict())
    simulation.register_character(caster)
    simulation.register_character(target)

    var request := SimulationActionRequest.cast_spell(caster.id, target.id, prepared_heal)
    var result := simulation.submit_action(request)
    _check(bool(result.get("ok", false)), "Heal should resolve through submit_action")
    _check(target.health == 5, "Heal should restore its base magnitude")
    _check(not target.unconscious, "Heal above zero HP should wake an unconscious ally")
    _check(caster.current_mana == 14, "Heal should spend its six mana cost")
    _check(is_equal_approx(caster.time_points, 90.0), "Heal should spend ten Time Points")


func _test_rejected_cast_does_not_spend_resources() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("ranged_caster", "player", Vector2i.ZERO)
    var distant_target := _new_character("distant_target", "enemy", Vector2i(9, 0))
    caster.unlocked_base_spells.append("firebolt")
    caster.skills["firebolt_hit"] = 10
    var prepared_firebolt := PreparedSpell.create("firebolt")
    caster.prepared_spells.append(prepared_firebolt.to_dict())
    simulation.register_character(caster)
    simulation.register_character(distant_target)

    var result := simulation.submit_action(
        SimulationActionRequest.cast_spell(caster.id, distant_target.id, prepared_firebolt)
    )
    _check(not bool(result.get("ok", false)), "Firebolt beyond range should be rejected")
    _check(String(result.get("reason", "")) == "target_out_of_range", "Out-of-range rejection should be explicit")
    _check(caster.current_mana == 20, "Rejected cast must not spend mana")
    _check(is_equal_approx(caster.time_points, 100.0), "Rejected cast must not spend Time Points")


func _test_burst_firebolt_uses_area_effect() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("burst_caster", "player", Vector2i.ZERO)
    var target := _new_character("burst_target", "enemy", Vector2i(2, 0))
    var nearby := _new_character("burst_nearby", "enemy", Vector2i(3, 0))
    target.health = 30
    nearby.health = 30
    caster.unlocked_base_spells.append("firebolt")
    simulation.map_data.add_cell(Vector2i(2, 0))
    for hex in HexGrid.neighbors(Vector2i(2, 0)):
        simulation.map_data.add_cell(hex)
    simulation.register_character(caster)
    simulation.register_character(target)
    simulation.register_character(nearby)

    var burst_spell := PreparedSpell.create("firebolt", {"burst": true})
    caster.prepared_spells.append(burst_spell.to_dict())
    var result := simulation.submit_action(
        SimulationActionRequest.cast_spell_at_hex(caster.id, Vector2i(2, 0), burst_spell)
    )
    _check(bool(result.get("ok", false)), "Burst Firebolt should resolve as an area effect")
    _check(target.health == 25 and nearby.health == 25, "Burst Firebolt should damage opponents in the radius")
    _check(caster.current_mana == 7, "Burst Firebolt should pay its increased mana cost")
    _check(is_equal_approx(caster.time_points, 90.0), "Burst Firebolt should pay its standard TP cost")


func _test_armour_penalty_and_blood_magic() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("blood_caster", "player", Vector2i.ZERO)
    var target := _new_character("blood_target", "enemy", Vector2i(2, 0))
    caster.unlocked_base_spells.append("firebolt")
    caster.skills["firebolt_hit"] = 10
    caster.skills["blood_magic"] = 1
    caster.blood_magic_active = true
    caster.current_mana = 2
    caster.health = 20
    caster.equipment["armour"] = "light_armor"
    var prepared_firebolt := PreparedSpell.create("firebolt")
    caster.prepared_spells.append(prepared_firebolt.to_dict())
    simulation.register_character(caster)
    simulation.register_character(target)

    var result := simulation.submit_action(
        SimulationActionRequest.cast_spell(caster.id, target.id, prepared_firebolt),
        77
    )
    _check(bool(result.get("ok", false)), "Blood Magic should cover a valid mana shortfall")
    _check(int(result.get("armour_mana_penalty", -1)) == 1, "Light armour should add one mana to an arcane spell")
    _check(int(result.get("mana_cost", -1)) == 6, "Total cost should include the armour penalty")
    _check(caster.current_mana == 0, "Available mana should be spent first")
    _check(caster.health == 12, "Each of four missing mana should cost two HP")


func _test_combat_ai_casts_firebolt() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("ai_mage", "enemy", Vector2i.ZERO)
    var target := _new_character("player_target", "player", Vector2i(3, 0))
    caster.unlocked_base_spells.append("firebolt")
    caster.skills["firebolt_hit"] = 10
    target.health = 30
    simulation.register_character(caster)
    simulation.register_character(target)
    simulation.start_combat()
    simulation.turn_scheduler.current_character_id = caster.id

    var enemy_ids: Array[String] = ["ai_mage"]
    var party_ids: Array[String] = ["player_target"]
    CombatAI.take_turn(simulation, caster, enemy_ids, party_ids)
    _check(target.health == 25, "Combat AI should use Firebolt against a target outside melee range")
    _check(caster.current_mana == 15, "AI Firebolt must use the same mana payment")
    _check(is_equal_approx(caster.time_points, 80.0), "AI should end its turn after paying Firebolt costs")


func _test_combat_ai_heals_ally() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("ai_healer", "enemy", Vector2i.ZERO)
    var ally := _new_character("ai_ally", "enemy", Vector2i(1, 0))
    var target := _new_character("player_target_2", "player", Vector2i(3, 0))
    caster.unlocked_base_spells.append("heal")
    ally.health = 40
    simulation.register_character(caster)
    simulation.register_character(ally)
    simulation.register_character(target)
    simulation.start_combat()
    simulation.turn_scheduler.current_character_id = caster.id

    var enemy_ids: Array[String] = ["ai_healer", "ai_ally"]
    var party_ids: Array[String] = ["player_target_2"]
    CombatAI.take_turn(simulation, caster, enemy_ids, party_ids)
    _check(ally.health == 45, "Combat AI should heal a nearby injured ally")
    _check(caster.current_mana == 14, "AI Heal must use the same mana payment")
    _check(is_equal_approx(caster.time_points, 80.0), "AI should end its turn after paying Heal costs")
