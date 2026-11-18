extends SceneTree

const WORLD_SIMULATION_SCRIPT = preload("res://scripts/simulation/world_simulation.gd")
const CHARACTER_STATE_SCRIPT = preload("res://scripts/simulation/character_state.gd")
const HEX_GRID_SCRIPT = preload("res://scripts/core/hex_grid.gd")
const PREPARED_SPELL_SCRIPT = preload("res://scripts/simulation/prepared_spell.gd")
const ACTION_REQUEST_SCRIPT = preload("res://scripts/simulation/simulation_action_request.gd")
const COMBAT_AI_SCRIPT = preload("res://scripts/simulation/combat_ai.gd")

var failures := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _test_smite_evil()
    _test_smite_tag_restriction()
    _test_burst_heal()
    _test_divine_silence_breaks_on_cast()
    _test_divine_silence()
    _test_sanctuary_and_divine_protection()
    _test_summon_animal()
    _test_permanent_animal_companion()
    _test_counterspell()
    _test_counterspell_reaction()
    _test_dragon_breath()
    _test_entangle()
    _test_entangle_persists_until_dispelled()
    _test_wild_fury()
    _test_calm_animal()
    _test_calm_animal_modes_and_break()
    _test_disguise_self()
    _test_temporal_rift()
    _test_feather_fall()
    _test_feather_fall_expiry()
    if failures > 0:
        push_error("%d full spell effect test(s) failed." % failures)
        quit(1)
        return
    print("All spell effect assertions passed.")
    quit(0)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failures += 1
    push_error("FAIL: " + message)


func _new_sim() -> Dictionary:
    var sim := WORLD_SIMULATION_SCRIPT.new()
    var caster := CHARACTER_STATE_SCRIPT.new("caster", "Caster", Vector2i.ZERO)
    caster.side = "player"
    caster.current_mana = 100
    caster.max_mana = 100
    caster.time_points = 500.0
    caster.unlocked_base_spells = [
        "firebolt", "heal", "smite_evil", "divine_silence", "sanctuary",
        "divine_protection", "summon_animal", "counterspell", "dragon_breath",
        "entangle", "wild_fury", "calm_animal", "disguise_self",
        "temporal_rift", "feather_fall"
    ]
    sim.map_data.add_cell(Vector2i.ZERO)
    for hex in HEX_GRID_SCRIPT.neighbors(Vector2i.ZERO):
        sim.map_data.add_cell(hex)
    for q in range(-5, 6):
        for r in range(-5, 6):
            var hex := Vector2i(q, r)
            if HEX_GRID_SCRIPT.distance(Vector2i.ZERO, hex) <= 5:
                sim.map_data.add_cell(hex)
    sim.register_character(caster)
    return {"sim": sim, "caster": caster}


func _cast(sim: WorldSimulation, caster: CharacterState, target: CharacterState, spell_id: String, modifiers: Dictionary = {}) -> Dictionary:
    var prepared := PREPARED_SPELL_SCRIPT.create(spell_id, modifiers)
    caster.prepared_spells.append(prepared.to_dict())
    var request := ACTION_REQUEST_SCRIPT.cast_spell(caster.id, target.id if target != null else "", prepared)
    return sim.submit_action(request, 42)


func _cast_at(sim: WorldSimulation, caster: CharacterState, hex: Vector2i, spell_id: String, modifiers: Dictionary = {}) -> Dictionary:
    var prepared := PREPARED_SPELL_SCRIPT.create(spell_id, modifiers)
    caster.prepared_spells.append(prepared.to_dict())
    return sim.submit_action(ACTION_REQUEST_SCRIPT.cast_spell_at_hex(caster.id, hex, prepared), 42)


func _test_smite_evil() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var undead := CHARACTER_STATE_SCRIPT.new("undead", "Skeleton", Vector2i(2, 0))
    undead.side = "enemy"
    undead.tags.append("undead")
    undead.health = 30
    caster.to_hit_spell = 100.0
    sim.register_character(undead)
    var result := _cast(sim, caster, undead, "smite_evil")
    _check(bool(result.get("ok", false)), "Smite Evil should cast")
    _check(undead.health == 22, "Smite Evil should deal its base 8 damage to undead")
    sim.free()


func _test_smite_tag_restriction() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var ordinary := CHARACTER_STATE_SCRIPT.new("ordinary", "Bandit", Vector2i(2, 0))
    ordinary.side = "enemy"
    ordinary.health = 30
    sim.register_character(ordinary)
    var result := _cast(sim, caster, ordinary, "smite_evil")
    _check(bool(result.get("ok", false)), "Smite Evil should resolve even when the target is not eligible")
    _check(ordinary.health == 30, "Smite Evil should have no effect on targets without undead/demon tags")
    _check(caster.current_mana == 97, "An in-range Smite Evil with an ineligible target should still pay its source-game cost")
    sim.free()


func _test_burst_heal() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var ally_a := CHARACTER_STATE_SCRIPT.new("healed_a", "Ally A", Vector2i(1, 0))
    var ally_b := CHARACTER_STATE_SCRIPT.new("healed_b", "Ally B", Vector2i(2, 0))
    ally_a.side = "player"
    ally_b.side = "player"
    ally_a.health = 10
    ally_b.health = 10
    sim.register_character(ally_a)
    sim.register_character(ally_b)
    var result := _cast_at(sim, caster, Vector2i(1, 0), "heal", {"burst": true})
    _check(bool(result.get("ok", false)), "Burst Heal should resolve as an area effect")
    _check(ally_a.health == 15 and ally_b.health == 15, "Burst Heal should heal all allies in its radius")
    _check(caster.current_mana == 86, "Burst Heal should pay base mana plus burst surcharge")
    sim.free()


func _test_divine_silence_breaks_on_cast() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var enemy := CHARACTER_STATE_SCRIPT.new("silenced_caster", "Silenced Caster", Vector2i(2, 0))
    enemy.side = "enemy"
    enemy.current_mana = 20
    enemy.max_mana = 20
    enemy.time_points = 100.0
    enemy.unlocked_base_spells = ["firebolt"]
    var firebolt := PREPARED_SPELL_SCRIPT.create("firebolt")
    enemy.prepared_spells.append(firebolt.to_dict())
    sim.register_character(enemy)
    var silence := _cast(sim, caster, enemy, "divine_silence")
    _check(bool(silence.get("ok", false)) and enemy.has_spell_effect("divine_silence"), "Divine Silence should be active before the target casts")
    var counter_cast: Dictionary = sim.submit_action(ACTION_REQUEST_SCRIPT.cast_spell(enemy.id, caster.id, firebolt), 4)
    _check(bool(counter_cast.get("ok", false)), "A silenced character should still be able to cast")
    _check(not enemy.has_spell_effect("divine_silence"), "Casting should break Divine Silence")
    sim.free()


func _test_divine_silence() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var target := CHARACTER_STATE_SCRIPT.new("silenced", "Enemy Mage", Vector2i(2, 0))
    target.side = "enemy"
    sim.register_character(target)
    var result := _cast(sim, caster, target, "divine_silence")
    _check(bool(result.get("ok", false)) and target.has_spell_effect("divine_silence"), "Divine Silence should apply an ongoing target effect")
    var health_before := target.health
    sim._advance_character_spell_effects(target, 20.0)
    _check(target.health < health_before, "Divine Silence should deal damage over elapsed Time Points")
    sim.free()


func _test_sanctuary_and_divine_protection() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var ally := CHARACTER_STATE_SCRIPT.new("ally", "Ally", Vector2i(1, 0))
    ally.side = "player"
    var enemy := CHARACTER_STATE_SCRIPT.new("enemy", "Enemy", Vector2i(2, 0))
    enemy.side = "enemy"
    enemy.time_points = 50.0
    sim.register_character(ally)
    sim.register_character(enemy)
    var sanctuary := _cast(sim, caster, ally, "sanctuary")
    _check(bool(sanctuary.get("ok", false)) and ally.has_spell_effect("sanctuary"), "Sanctuary should protect an ally")
    sim._apply_spell_protection_triggers(enemy, ally)
    _check(is_equal_approx(enemy.time_points, 49.0), "Sanctuary should drain one TP from a hostile attacker")
    var protection := _cast(sim, caster, ally, "divine_protection")
    _check(bool(protection.get("ok", false)) and ally.has_spell_effect("divine_protection"), "Divine Protection should apply to an ally")
    enemy.time_points = 50.0
    sim._apply_spell_protection_triggers(enemy, ally)
    _check(is_equal_approx(enemy.time_points, 48.0), "Both divine protections should apply their TP penalties")
    sim.free()


func _test_summon_animal() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var result := _cast_at(sim, caster, Vector2i(1, 0), "summon_animal", {"summon_id": "wolf"})
    _check(bool(result.get("ok", false)), "Summon Animal should create a summon at a valid empty hex")
    var summon: CharacterState = sim.get_character(String(result.get("summoned_id", "")))
    _check(summon != null and summon.is_summoned and summon.summoned_by_id == caster.id, "Summoned animal should be registered with its summoner")
    _check(summon != null and summon.tags.has("animal"), "Summoned creature should carry the animal tag")
    sim.free()


func _test_permanent_animal_companion() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    caster.skills["animal_companion"] = 1
    caster.skills["learn_unicorn_summon"] = 1
    var result := _cast_at(sim, caster, Vector2i(1, 0), "summon_animal", {"summon_id": "wolf"})
    _check(bool(result.get("ok", false)), "Animal Companion skill should make the first summon permanent")
    var companion: CharacterState = sim.get_character(String(result.get("summoned_id", "")))
    _check(companion != null and companion.is_animal_companion and not companion.is_summoned, "First animal should be stored as a permanent companion")
    var second := _cast_at(sim, caster, Vector2i(2, 0), "summon_animal", {"summon_id": "unicorn"})
    _check(not bool(second.get("ok", true)), "A second permanent unicorn companion should be rejected")
    sim.free()


func _test_counterspell() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var enemy := CHARACTER_STATE_SCRIPT.new("enemy_mage", "Enemy Mage", Vector2i(2, 0))
    enemy.side = "enemy"
    enemy.add_spell_effect({"effect_id": "sanctuary", "source_id": enemy.id, "magnitude": 1})
    sim.register_character(enemy)
    var result := _cast(sim, caster, enemy, "counterspell")
    _check(bool(result.get("ok", false)), "Counterspell should resolve against an opponent with an active spell effect")
    _check(not enemy.has_spell_effect("sanctuary"), "Counterspell should dispel an active target effect")
    sim.free()


func _test_counterspell_reaction() -> void:
    var sim := WORLD_SIMULATION_SCRIPT.new()
    var caster := CHARACTER_STATE_SCRIPT.new("enemy_caster", "Enemy Caster", Vector2i(0, 0))
    var player := CHARACTER_STATE_SCRIPT.new("player_reactor", "Player Reactor", Vector2i(3, 0))
    caster.side = "enemy"
    caster.current_mana = 20
    caster.max_mana = 20
    caster.time_points = 50.0
    caster.unlocked_base_spells = ["firebolt"]
    var firebolt := PREPARED_SPELL_SCRIPT.create("firebolt")
    caster.prepared_spells.append(firebolt.to_dict())
    player.side = "player"
    player.current_mana = 20
    player.max_mana = 20
    player.time_points = 50.0
    player.unlocked_base_spells = ["counterspell"]
    var counterspell := PREPARED_SPELL_SCRIPT.create("counterspell")
    player.prepared_spells.append(counterspell.to_dict())
    sim.register_character(caster)
    sim.register_character(player)
    sim.start_combat()
    sim.turn_scheduler.current_character_id = caster.id
    var result := sim.submit_action(ACTION_REQUEST_SCRIPT.cast_spell(caster.id, player.id, firebolt), 91)
    _check(bool(result.get("pending", false)), "Enemy casting should pause for the player's Counterspell reaction")
    _check(not sim.pending_reaction.is_empty(), "Counterspell should use the shared reaction request system")
    var reaction := sim.resolve_reaction("counterspell_player_reactor")
    _check(bool(reaction.get("ok", false)), "The player should be able to select Counterspell")
    _check(player.current_mana == 10 and is_equal_approx(player.time_points, 45.0), "Counterspell should spend its own mana and five TP")
    _check(caster.current_mana == 15 and is_equal_approx(caster.time_points, 50.0), "A countered spell should cost caster mana but not cast TP")
    _check(player.health == player.max_health, "Counterspell should prevent the incoming spell effect")
    sim.free()


func _test_dragon_breath() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var first := CHARACTER_STATE_SCRIPT.new("first", "First", Vector2i(2, 0))
    var second := CHARACTER_STATE_SCRIPT.new("second", "Second", Vector2i(3, 0))
    first.side = "enemy"
    second.side = "enemy"
    first.health = 40
    second.health = 40
    sim.register_character(first)
    sim.register_character(second)
    var result := _cast_at(sim, caster, Vector2i(2, 0), "dragon_breath")
    _check(bool(result.get("ok", false)), "Dragon Breath should resolve at a selected hex")
    _check(first.health == 25 and second.health == 25, "Dragon Breath should damage every opponent in its radius")
    sim.free()


func _test_entangle() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var target := CHARACTER_STATE_SCRIPT.new("entangled", "Entangled Enemy", Vector2i(2, 0))
    target.side = "enemy"
    sim.register_character(target)
    var result := _cast_at(sim, caster, Vector2i(2, 0), "entangle")
    _check(bool(result.get("ok", false)), "Entangle should resolve at a selected hex")
    _check(target.has_spell_effect("entangled"), "Entangle should apply a timed movement debuff")
    sim.free()


func _test_entangle_persists_until_dispelled() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var target := CHARACTER_STATE_SCRIPT.new("long_entangled", "Long Entangled", Vector2i(2, 0))
    target.side = "enemy"
    sim.register_character(target)
    var result := _cast_at(sim, caster, Vector2i(2, 0), "entangle")
    _check(bool(result.get("ok", false)), "Entangle should cast")
    for tick in range(25):
        sim._advance_character_spell_effects(target, 0.0)
    _check(target.has_spell_effect("entangled"), "Entangle should persist until dispelled rather than expiring on a guessed timer")
    sim.free()


func _test_wild_fury() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var result := _cast(sim, caster, caster, "wild_fury")
    _check(bool(result.get("ok", false)) and caster.has_spell_effect("wild_fury"), "Wild Fury should apply to its caster")
    _check(int(caster.get_spell_effect("wild_fury").get("magnitude", 0)) == 3, "Wild Fury should preserve its unarmed damage bonus")
    sim.free()


func _test_calm_animal() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var animal := CHARACTER_STATE_SCRIPT.new("animal", "Wolf", Vector2i(2, 0))
    animal.side = "enemy"
    animal.tags.append("animal")
    sim.register_character(animal)
    var result := _cast(sim, caster, animal, "calm_animal", {"calm_mode": "stay"})
    _check(bool(result.get("ok", false)) and animal.has_spell_effect("calmed"), "Calm Animal should affect eligible animals")
    var fey := CHARACTER_STATE_SCRIPT.new("fey", "Unicorn", Vector2i(3, 0))
    fey.side = "enemy"
    fey.tags.append("animal")
    fey.tags.append("fey")
    sim.register_character(fey)
    var rejected := _cast(sim, caster, fey, "calm_animal")
    _check(not bool(rejected.get("ok", true)), "Calm Animal must exclude fey creatures")
    sim.free()


func _test_calm_animal_modes_and_break() -> void:
    var come_setup := _new_sim()
    var come_sim = come_setup["sim"]
    var come_caster = come_setup["caster"]
    var coming := CHARACTER_STATE_SCRIPT.new("coming_animal", "Coming Wolf", Vector2i(3, 0))
    coming.side = "enemy"
    coming.tags.append("animal")
    come_sim.register_character(coming)
    var come_result := _cast(come_sim, come_caster, coming, "calm_animal", {"calm_mode": "come"})
    _check(bool(come_result.get("ok", false)), "Calm Animal come mode should cast")
    come_sim.start_combat()
    come_sim.turn_scheduler.current_character_id = coming.id
    var enemy_ids: Array[String] = [coming.id]
    var party_ids: Array[String] = [come_caster.id]
    COMBAT_AI_SCRIPT.take_turn(come_sim, coming, enemy_ids, party_ids)
    _check(coming.axial != Vector2i(3, 0), "Come mode should move the animal towards its caster")
    come_sim.free()

    var chase_setup := _new_sim()
    var chase_sim = chase_setup["sim"]
    var chase_caster = chase_setup["caster"]
    var fleeing := CHARACTER_STATE_SCRIPT.new("chasing_animal", "Chasing Wolf", Vector2i(2, 0))
    fleeing.side = "enemy"
    fleeing.tags.append("animal")
    chase_sim.register_character(fleeing)
    var chase_result := _cast(chase_sim, chase_caster, fleeing, "calm_animal", {"calm_mode": "chase"})
    _check(bool(chase_result.get("ok", false)), "Calm Animal chase mode should cast")
    chase_sim.start_combat()
    chase_sim.turn_scheduler.current_character_id = fleeing.id
    var chase_enemy_ids: Array[String] = [fleeing.id]
    var chase_party_ids: Array[String] = [chase_caster.id]
    COMBAT_AI_SCRIPT.take_turn(chase_sim, fleeing, chase_enemy_ids, chase_party_ids)
    _check(HEX_GRID_SCRIPT.distance(fleeing.axial, chase_caster.axial) > 2, "Chase mode should move the animal away from its caster")
    chase_sim.free()

    var break_setup := _new_sim()
    var break_sim = break_setup["sim"]
    var break_caster = break_setup["caster"]
    var attacked_animal := CHARACTER_STATE_SCRIPT.new("attacked_animal", "Attacked Wolf", Vector2i(1, 0))
    attacked_animal.side = "enemy"
    attacked_animal.tags.append("animal")
    break_sim.register_character(attacked_animal)
    _cast(break_sim, break_caster, attacked_animal, "calm_animal")
    break_sim._resolve_attack_action(break_caster.id, attacked_animal.id, {}, 6)
    _check(not attacked_animal.has_spell_effect("calmed"), "Being attacked should break Calm Animal")
    break_sim.free()


func _test_disguise_self() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var prepared := PREPARED_SPELL_SCRIPT.new("disguise_self", {}, {"profile_id": "merchant"})
    caster.prepared_spells.append(prepared.to_dict())
    var result: Dictionary = sim.submit_action(ACTION_REQUEST_SCRIPT.cast_spell(caster.id, caster.id, prepared))
    _check(bool(result.get("ok", false)), "Disguise Self should cast on the caster")
    _check(caster.has_spell_effect("disguise_self"), "Disguise Self should store its active disguise profile")
    _check(String(caster.get_spell_effect("disguise_self").get("profile_id", "")) == "merchant", "Disguise Self should preserve its selected profile")
    sim.free()


func _test_temporal_rift() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var target := CHARACTER_STATE_SCRIPT.new("rift_target", "Rift Target", Vector2i(3, 0))
    target.side = "enemy"
    target.time_points = 88.0
    sim.register_character(target)
    var result := _cast(sim, caster, target, "temporal_rift")
    _check(bool(result.get("ok", false)), "Temporal Rift should cast on an opponent")
    _check(is_zero_approx(target.time_points), "Temporal Rift should drain the target's Time Points to zero")
    sim.free()


func _test_feather_fall_expiry() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    _cast(sim, caster, caster, "feather_fall")
    for tick in range(30):
        sim._advance_character_spell_effects(caster, 0.0)
    _check(not caster.has_spell_effect("feather_fall"), "Feather Fall should expire after its 30-tick duration")
    sim.free()


func _test_feather_fall() -> void:
    var setup := _new_sim()
    var sim = setup["sim"]
    var caster = setup["caster"]
    var result := _cast(sim, caster, caster, "feather_fall")
    _check(bool(result.get("ok", false)) and caster.has_spell_effect("feather_fall"), "Feather Fall should grant a timed self-protection effect")
    var fall: Dictionary = sim.resolve_fall_damage(caster.id, 12)
    _check(bool(fall.get("prevented", false)) and int(fall.get("damage", -1)) == 0, "Feather Fall should prevent the next fall damage event")
    _check(not caster.has_spell_effect("feather_fall"), "Feather Fall should only prevent one fall")
    sim.free()
