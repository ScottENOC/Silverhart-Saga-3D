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
    _test_official_spell_catalogue_is_exactly_twelve()
    _test_curse_triggers_on_hostile_action()
    _test_divine_strength_buffs_ally_damage()
    _test_disguise_self_adds_profile_effect()
    _test_wild_fury_rejects_humans()
    _test_summon_animal_creates_permanent_companion()
    _test_feather_fall_prevents_fall_once()
    _test_counterspell_dispels_active_effect()
    _test_divine_protection_applies_guard_effect()
    _test_entangle_applies_to_enemies_in_area()
    _test_calm_animal_records_selected_mode()
    _test_wild_fury_buffs_allied_animal()
    if _failures > 0:
        push_error("%d spell casting assertion(s) failed." % _failures)
        quit(1)
        return
    print("Spell casting and AI tests passed.")
    quit(0)



func _test_official_spell_catalogue_is_exactly_twelve() -> void:
    var expected := [
        "firebolt", "counterspell", "feather_fall", "disguise_self",
        "heal", "divine_protection", "divine_strength", "curse",
        "summon_animal", "entangle", "calm_animal", "wild_fury"
    ]
    var catalogue := SpellRules.base_spells()
    _check(catalogue.size() == 12, "Official spell catalogue should contain exactly twelve entries")
    for spell_id in expected:
        _check(catalogue.has(spell_id), "Official spell catalogue should contain %s" % spell_id)


func _test_curse_triggers_on_hostile_action() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("curse_caster", "player", Vector2i.ZERO)
    var target := _new_character("cursed_enemy", "enemy", Vector2i(1, 0))
    target.to_hit_melee = 100
    caster.unlocked_base_spells.append("curse")
    var prepared := PreparedSpell.create("curse")
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    simulation.register_character(target)
    var mana_before := caster.current_mana
    var tp_before := caster.time_points
    var cast_result := simulation.submit_action(SimulationActionRequest.cast_spell(caster.id, target.id, prepared))
    _check(bool(cast_result.get("ok", false)), "Curse should cast on an enemy")
    _check(mana_before - caster.current_mana == 8 and is_equal_approx(tp_before - caster.time_points, 8.0), "Curse should cost 8 mana and 8 Time Points")
    _check(target.has_spell_effect("curse"), "Curse should mark its target")
    var before := target.health
    var attack := SimulationActionRequest.new(SimulationActionRequest.ActionType.ATTACK, target.id, caster.id, Vector2i.ZERO, 0.0, {})
    var attack_result := simulation.submit_action(attack, 44)
    _check(bool(attack_result.get("ok", false)), "Cursed target should still be able to take its hostile action")
    _check(before - target.health == 2, "Curse should deal two damage when the target attacks")
    _check(not target.has_spell_effect("curse"), "Curse should be consumed by the hostile action")


func _test_divine_strength_buffs_ally_damage() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("cleric", "player", Vector2i.ZERO)
    var ally := _new_character("blessed_ally", "player", Vector2i(1, 0))
    ally.to_hit_melee = 100
    var enemy := _new_character("strength_target", "enemy", Vector2i(2, 0))
    ally.base_damage = 3
    caster.unlocked_base_spells.append("divine_strength")
    var prepared := PreparedSpell.create("divine_strength")
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    simulation.register_character(ally)
    simulation.register_character(enemy)
    var cast_result := simulation.submit_action(SimulationActionRequest.cast_spell(caster.id, ally.id, prepared))
    _check(bool(cast_result.get("ok", false)), "Divine Strength should cast on an ally")
    _check(ally.has_spell_effect("divine_strength"), "Divine Strength should add its timed buff")
    var attack := SimulationActionRequest.new(SimulationActionRequest.ActionType.ATTACK, ally.id, enemy.id, Vector2i.ZERO, 0.0, {})
    var enemy_health_before := enemy.health
    var result := simulation.submit_action(attack, 99)
    _check(bool(result.get("ok", false)), "Buffed ally should be able to attack")
    _check(enemy_health_before - enemy.health >= 6, "Divine Strength should add three damage to the ally's attack")


func _test_disguise_self_adds_profile_effect() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("disguised_mage", "player", Vector2i.ZERO)
    caster.unlocked_base_spells.append("disguise_self")
    var prepared := PreparedSpell.create("disguise_self")
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    var result := simulation.submit_action(SimulationActionRequest.cast_spell(caster.id, caster.id, prepared))
    _check(bool(result.get("ok", false)), "Disguise Self should cast on its caster")
    _check(caster.has_spell_effect("disguise_self"), "Disguise Self should create a persistent appearance effect")


func _test_wild_fury_rejects_humans() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("wild_druid", "player", Vector2i.ZERO)
    var human_ally := _new_character("human_ally", "player", Vector2i(1, 0))
    caster.unlocked_base_spells.append("wild_fury")
    var prepared := PreparedSpell.create("wild_fury")
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    simulation.register_character(human_ally)
    var result := simulation.submit_action(SimulationActionRequest.cast_spell(caster.id, human_ally.id, prepared))
    _check(not bool(result.get("ok", false)), "Wild Fury must reject human allies")
    _check(String(result.get("reason", "")) == "wild_fury_requires_ally_animal", "Wild Fury rejection should identify the animal-only restriction")


func _test_summon_animal_creates_permanent_companion() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("companion_druid", "player", Vector2i.ZERO)
    caster.skills["animal_companion"] = 1
    caster.unlocked_base_spells.append("summon_animal")
    simulation.map_data.add_cell(Vector2i(1, 0))
    var prepared := PreparedSpell.create("summon_animal", {"summon_id": "wolf"})
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    var result := simulation.submit_action(SimulationActionRequest.cast_spell_at_hex(caster.id, Vector2i(1, 0), prepared))
    _check(bool(result.get("ok", false)), "Summon Animal should resolve on an available hex")
    var summoned := simulation.get_character(String(result.get("summoned_id", "")))
    _check(summoned != null and summoned.is_animal_companion, "Animal Companion skill should make the first summon permanent")


func _test_feather_fall_prevents_fall_once() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("falling_mage", "player", Vector2i.ZERO)
    caster.unlocked_base_spells.append("feather_fall")
    var prepared := PreparedSpell.create("feather_fall")
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    var cast_result := simulation.submit_action(SimulationActionRequest.cast_spell(caster.id, caster.id, prepared))
    _check(bool(cast_result.get("ok", false)), "Feather Fall should cast on its caster")
    var fall := simulation.resolve_fall_damage(caster.id, 5)
    _check(bool(fall.get("prevented", false)), "Feather Fall should prevent one fall")
    _check(not caster.has_spell_effect("feather_fall"), "Feather Fall should be consumed by the prevented fall")



func _test_counterspell_dispels_active_effect() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("counter_mage", "player", Vector2i.ZERO)
    var target := _new_character("enemy_mage", "enemy", Vector2i(2, 0))
    caster.unlocked_base_spells.append("counterspell")
    target.add_spell_effect({"effect_id": "divine_protection", "source_id": target.id})
    var prepared := PreparedSpell.create("counterspell")
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    simulation.register_character(target)
    var result := simulation.submit_action(SimulationActionRequest.cast_spell(caster.id, target.id, prepared))
    _check(bool(result.get("ok", false)), "Counterspell should resolve against an enemy with an active effect")
    _check(not target.has_spell_effect("divine_protection"), "Counterspell should remove the target's active spell effect")


func _test_divine_protection_applies_guard_effect() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("protective_cleric", "player", Vector2i.ZERO)
    var ally := _new_character("protected_ally", "player", Vector2i(1, 0))
    caster.unlocked_base_spells.append("divine_protection")
    var prepared := PreparedSpell.create("divine_protection")
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    simulation.register_character(ally)
    var result := simulation.submit_action(SimulationActionRequest.cast_spell(caster.id, ally.id, prepared))
    _check(bool(result.get("ok", false)), "Divine Protection should cast on an ally")
    _check(ally.has_spell_effect("divine_protection"), "Divine Protection should add its defensive trigger")


func _test_entangle_applies_to_enemies_in_area() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("entangle_druid", "player", Vector2i.ZERO)
    var target := _new_character("entangled_enemy", "enemy", Vector2i(2, 0))
    caster.unlocked_base_spells.append("entangle")
    simulation.map_data.add_cell(Vector2i(2, 0))
    for hex in HexGrid.neighbors(Vector2i(2, 0)):
        simulation.map_data.add_cell(hex)
    var prepared := PreparedSpell.create("entangle")
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    simulation.register_character(target)
    var result := simulation.submit_action(SimulationActionRequest.cast_spell_at_hex(caster.id, Vector2i(2, 0), prepared))
    _check(bool(result.get("ok", false)), "Entangle should resolve at a valid hex")
    _check(target.has_spell_effect("entangled"), "Entangle should restrict enemies in its area")


func _test_calm_animal_records_selected_mode() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("calm_druid", "player", Vector2i.ZERO)
    var animal := _new_character("wild_wolf", "neutral", Vector2i(2, 0))
    animal.tags.append("animal")
    caster.unlocked_base_spells.append("calm_animal")
    var prepared := PreparedSpell.create("calm_animal", {"calm_mode": "come"})
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    simulation.register_character(animal)
    var result := simulation.submit_action(SimulationActionRequest.cast_spell(caster.id, animal.id, prepared))
    _check(bool(result.get("ok", false)), "Calm Animal should affect a mundane animal")
    _check(String(animal.get_spell_effect("calmed").get("mode", "")) == "come", "Calm Animal should preserve the selected mode")


func _test_wild_fury_buffs_allied_animal() -> void:
    var simulation := WorldSimulation.new()
    var caster := _new_character("fury_druid", "player", Vector2i.ZERO)
    var animal := _new_character("fury_wolf", "player", Vector2i(1, 0))
    animal.tags.append("animal")
    caster.unlocked_base_spells.append("wild_fury")
    var prepared := PreparedSpell.create("wild_fury")
    caster.prepared_spells.append(prepared.to_dict())
    simulation.register_character(caster)
    simulation.register_character(animal)
    var result := simulation.submit_action(SimulationActionRequest.cast_spell(caster.id, animal.id, prepared))
    _check(bool(result.get("ok", false)), "Wild Fury should buff an allied animal")
    _check(animal.has_spell_effect("wild_fury"), "Wild Fury should add its timed animal buff")


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
