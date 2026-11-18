extends SceneTree

var _failures := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _test_player_firebolt_and_heal()
    _test_rejections_are_free()
    if _failures > 0:
        push_error("%d spell casting test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Spell casting tests passed.")
    quit(0)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error("FAIL: " + message)


func _test_player_firebolt_and_heal() -> void:
    var sim := WorldSimulation.new()
    var caster := CharacterState.new("player_caster", "Player Caster", Vector2i.ZERO)
    var enemy := CharacterState.new("spell_enemy", "Spell Enemy", Vector2i(3, 0))
    var ally := CharacterState.new("spell_ally", "Spell Ally", Vector2i(1, 0))
    caster.side = "player"
    caster.current_mana = 30
    caster.max_mana = 30
    caster.time_points = 100.0
    caster.to_hit_ranged = 100.0
    caster.unlocked_base_spells = ["firebolt", "heal"]
    var firebolt := PreparedSpell.create("firebolt")
    var heal := PreparedSpell.create("heal")
    caster.prepared_spells = [firebolt.to_dict(), heal.to_dict()]
    enemy.side = "enemy"
    enemy.health = 30
    enemy.max_health = 30
    ally.side = "player"
    ally.health = 2
    ally.max_health = 30
    ally.apply_damage(5)
    sim.register_character(caster)
    sim.register_character(enemy)
    sim.register_character(ally)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = caster.id

    var fire_result := sim.submit_action(
        SimulationActionRequest.cast_spell(caster.id, enemy.id, firebolt.to_dict()),
        7
    )
    _check(bool(fire_result.get("ok", false)), "Firebolt should resolve through the shared action")
    _check(String(fire_result.get("action_type", "")) == "cast_spell", "The result should use the cast_spell action type")
    _check(bool(fire_result.get("hit", false)) and enemy.health == 25, "Firebolt should apply its prepared magnitude on a hit")
    _check(caster.current_mana == 25 and is_equal_approx(caster.time_points, 90.0), "Firebolt should pay the calculated mana and TP costs")

    var heal_result := sim.submit_action(
        SimulationActionRequest.cast_spell(caster.id, ally.id, heal.to_dict())
    )
    _check(bool(heal_result.get("ok", false)), "Heal should resolve through the same action")
    _check(ally.health == 2 and not ally.unconscious, "Heal should revive an unconscious friendly target")
    _check(caster.current_mana == 19 and is_equal_approx(caster.time_points, 80.0), "Heal should pay its calculated costs")
    sim.free()


func _test_rejections_are_free() -> void:
    var sim := WorldSimulation.new()
    var caster := CharacterState.new("rejection_caster", "Caster", Vector2i.ZERO)
    var enemy := CharacterState.new("rejection_enemy", "Enemy", Vector2i(9, 0))
    caster.side = "player"
    caster.current_mana = 1
    caster.time_points = 50.0
    caster.unlocked_base_spells = ["firebolt", "heal"]
    var firebolt := PreparedSpell.create("firebolt")
    caster.prepared_spells = [firebolt.to_dict()]
    enemy.side = "enemy"
    sim.register_character(caster)
    sim.register_character(enemy)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = caster.id

    var insufficient_mana := sim.submit_action(
        SimulationActionRequest.cast_spell(caster.id, enemy.id, firebolt.to_dict()),
        3
    )
    _check(not bool(insufficient_mana.get("ok", true)), "Insufficient mana should reject a cast")
    _check(String(insufficient_mana.get("reason", "")) == "insufficient_mana", "Mana rejection should have a stable reason")
    _check(caster.current_mana == 1 and is_equal_approx(caster.time_points, 50.0), "Mana rejection must not spend either resource")

    caster.current_mana = 20
    var out_of_range := sim.submit_action(
        SimulationActionRequest.cast_spell(caster.id, enemy.id, firebolt.to_dict()),
        3
    )
    _check(not bool(out_of_range.get("ok", true)), "Out-of-range spells should be rejected")
    _check(String(out_of_range.get("reason", "")) == "target_out_of_range", "Range rejection should have a stable reason")
    _check(caster.current_mana == 20 and is_equal_approx(caster.time_points, 50.0), "Range rejection must not spend either resource")

    var altered := PreparedSpell.create("firebolt", {"magnitude_bonus": 1})
    var unprepared := sim.submit_action(
        SimulationActionRequest.cast_spell(caster.id, enemy.id, altered.to_dict()),
        3
    )
    _check(not bool(unprepared.get("ok", true)), "A variant absent from the prepared list should be rejected")
    _check(String(unprepared.get("reason", "")) == "spell_not_prepared", "Unprepared cast should have a stable reason")
    _check(caster.current_mana == 20 and is_equal_approx(caster.time_points, 50.0), "Unprepared cast must not spend either resource")
    sim.free()
