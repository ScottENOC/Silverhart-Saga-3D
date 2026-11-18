extends SceneTree

const SPELL_RULES = preload("res://scripts/simulation/spell_rules.gd")
const PREPARED_SPELL = preload("res://scripts/simulation/prepared_spell.gd")
const CHARACTER_STATE = preload("res://scripts/simulation/character_state.gd")

var _failures := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _test_catalogue_loads()
    _test_default_variant()
    _test_arcane_efficiency_and_modifiers()
    _test_slowed_subtle_heal()
    _test_touch_and_mana_floor()
    _test_invalid_combinations()
    _test_modifier_skills_are_required()
    _test_summon_species_skills_and_costs()
    _test_prepared_spell_round_trip()

    if _failures > 0:
        push_error("%d spell rules test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Spell rules tests passed.")
    quit(0)


func _test_catalogue_loads() -> void:
    var catalogue := SPELL_RULES.base_spells()
    _check(catalogue.size() == 15, "The source-derived base spell catalogue should load all 15 spells")


func _test_default_variant() -> void:
    var result: Dictionary = SPELL_RULES.compute_variant("firebolt")
    _check(bool(result.get("ok", false)), "Default Firebolt should be calculable")
    _check(int(result.get("mana_cost", -1)) == 5, "Default Firebolt should cost 5 mana")
    _check(int(result.get("core_mana_cost", -1)) == 5, "Default Firebolt core cost should be 5")
    _check(int(result.get("time_point_cost", -1)) == 10, "Default spell should cost 10 TP")
    _check(float(result.get("magnitude", 0.0)) == 5.0, "Default Firebolt magnitude should be 5")
    _check(int(result.get("range", -1)) == 8, "Default Firebolt range should be 8")


func _test_arcane_efficiency_and_modifiers() -> void:
    var modifiers := {
        "speed": "quickened",
        "magnitude_bonus": 1,
        "range_bonus": 2,
        "radius_bonus": 1,
        "target_bonus": 1,
        "burst": true
    }
    var skills := {
        "arcane_burst": 1,
        "arcane_expand": 1,
        "arcane_magnitude": 1,
        "arcane_range": 2,
        "arcane_targets": 1,
        "arcane_quickened": 1,
        "arcane_eff_range": 1,
        "arcane_eff_magnitude": 1,
        "arcane_eff_speed": 2
    }
    var result: Dictionary = SPELL_RULES.compute_variant("firebolt", modifiers, skills)
    _check(bool(result.get("ok", false)), "Modified Firebolt should be calculable")
    _check(int(result.get("mana_cost", -1)) == 46, "Arcane efficiencies and modifiers should match the original formula")
    _check(int(result.get("core_mana_cost", -1)) == 43, "Core mana cost should preserve the original distinction")
    _check(int(result.get("time_point_cost", -1)) == 5, "Quickened casting should cost 5 TP")
    _check(float(result.get("magnitude", 0.0)) == 10.0, "One magnitude increment should double base magnitude")
    _check(int(result.get("radius", -1)) == 2, "Burst radius should start at one and accept radius increments")
    _check(String(result.get("type", "")) == "aoe_damage", "Burst Firebolt should resolve as area damage")


func _test_slowed_subtle_heal() -> void:
    var modifiers := {
        "speed": "slowed",
        "magnitude_bonus": 2,
        "radius_bonus": 1,
        "target_bonus": 1,
        "burst": true,
        "subtle": true
    }
    var skills := {
        "divine_slowed": 1,
        "divine_magnitude": 2,
        "divine_expand": 1,
        "divine_targets": 1,
        "subtle_spell": 1
    }
    var result: Dictionary = SPELL_RULES.compute_variant("heal", modifiers, skills)
    _check(bool(result.get("ok", false)), "Subtle burst Heal should be calculable")
    _check(int(result.get("mana_cost", -1)) == 51, "Slowed subtle burst Heal should match the original mana formula")
    _check(int(result.get("core_mana_cost", -1)) == 55, "Core cost should exclude the slowed mana discount")
    _check(int(result.get("time_point_cost", -1)) == 25, "Slowed subtle casting should cost 25 TP")
    _check(String(result.get("type", "")) == "aoe_heal", "Burst Heal should become area healing")


func _test_touch_and_mana_floor() -> void:
    var touch := SPELL_RULES.compute_variant("firebolt", {"touch": true}, {"arcane_touch": 1})
    _check(bool(touch.get("ok", false)), "Touch Firebolt should be calculable")
    _check(int(touch.get("mana_cost", -1)) == 2, "Touch should discount Firebolt by three mana")
    _check(int(touch.get("range", -1)) == 1, "Touch should cap spell range at one")

    var floor_result := SPELL_RULES.compute_variant(
        "firebolt",
        {"speed": "slowed", "touch": true},
        {"arcane_slowed": 1, "arcane_touch": 1}
    )
    _check(int(floor_result.get("mana_cost", -1)) == 1, "Mana cost should never fall below one")


func _test_invalid_combinations() -> void:
    var unknown := SPELL_RULES.compute_variant("not_a_spell")
    _check(not bool(unknown.get("ok", true)), "Unknown base spell should be rejected")
    var invalid_burst := SPELL_RULES.compute_variant("sanctuary", {"burst": true})
    _check(not bool(invalid_burst.get("ok", true)), "Burst should reject unsupported base spell types")
    var invalid_subtle := SPELL_RULES.compute_variant("firebolt", {"subtle": true})
    _check(not bool(invalid_subtle.get("ok", true)), "Subtle direct damage should be rejected")
    var invalid_touch := SPELL_RULES.compute_variant("heal", {"touch": true})
    _check(not bool(invalid_touch.get("ok", true)), "Touch should reject spells without extended base range")


func _test_modifier_skills_are_required() -> void:
    var quickened_without_skill := SPELL_RULES.compute_variant("firebolt", {"speed": "quickened"})
    _check(not bool(quickened_without_skill.get("ok", false)), "Quickened casting should require the matching school skill")
    _check(String(quickened_without_skill.get("reason", "")) == "quickened_skill_required", "Missing quickened skill should report a clear reason")

    var burst_without_skill := SPELL_RULES.compute_variant("firebolt", {"burst": true})
    _check(String(burst_without_skill.get("reason", "")) == "burst_skill_required", "Burst should require the matching school skill")

    var subtle_without_skill := SPELL_RULES.compute_variant("heal", {"subtle": true})
    _check(String(subtle_without_skill.get("reason", "")) == "subtle_spell_skill_required", "Subtle casting should require Subtle Spell")

    var insufficient_expansion := SPELL_RULES.compute_variant(
        "firebolt", {"radius_bonus": 2}, {"arcane_expand": 1}
    )
    _check(String(insufficient_expansion.get("reason", "")) == "expansion_skill_rank_insufficient", "Expansion rank should cap the radius bonus")

    var wrong_school := SPELL_RULES.compute_variant(
        "heal", {"speed": "quickened"}, {"arcane_quickened": 1}
    )
    _check(String(wrong_school.get("reason", "")) == "quickened_skill_required", "A skill from another school must not unlock this school's casting speed")

    var unlocked := SPELL_RULES.compute_variant(
        "firebolt",
        {"speed": "quickened", "burst": true, "radius_bonus": 1, "magnitude_bonus": 1, "range_bonus": 1, "target_bonus": 1},
        {"arcane_quickened": 1, "arcane_burst": 1, "arcane_expand": 1, "arcane_magnitude": 1, "arcane_range": 1, "arcane_targets": 1}
    )
    _check(bool(unlocked.get("ok", false)), "A legal set of purchased Arcane skills should unlock the corresponding variant")

    
func _test_summon_species_skills_and_costs() -> void:
    var locked_boar := SPELL_RULES.compute_variant("summon_animal", {"summon_id": "boar"})
    _check(String(locked_boar.get("reason", "")) == "boar_summon_skill_required", "Boar summoning should require its dedicated skill")

    var boar := SPELL_RULES.compute_variant("summon_animal", {"summon_id": "boar"}, {"learn_boar_summon": 1})
    _check(bool(boar.get("ok", false)), "Boar summoning should unlock with Boar Summoning")
    _check(int(boar.get("mana_cost", -1)) == 18, "Boar summoning should add its 8 mana surcharge")
    _check(int(boar.get("core_mana_cost", -1)) == 18, "Summon surcharge should be included in core mana cost")

    var tiger := SPELL_RULES.compute_variant("summon_animal", {"summon_id": "tiger"}, {"learn_tiger_summon": 1})
    _check(int(tiger.get("mana_cost", -1)) == 25, "Tiger summoning should add its 15 mana surcharge")

    var eagle := SPELL_RULES.compute_variant("summon_animal", {"summon_id": "eagle"}, {"learn_eagle_summon": 1})
    _check(int(eagle.get("mana_cost", -1)) == 15, "Eagle summoning should add its 5 mana surcharge")

    var unicorn := SPELL_RULES.compute_variant(
        "summon_animal", {"summon_id": "unicorn"},
        {"learn_unicorn_summon": 1, "animal_companion": 1}
    )
    _check(bool(unicorn.get("ok", false)), "Unicorn summoning should require and accept both earned bond skills")

    
func _test_prepared_spell_round_trip() -> void:
    var spell = PREPARED_SPELL.create("firebolt", {
        "speed": "quickened",
        "magnitude_bonus": 2,
        "range_bonus": 1
    })
    spell.presentation = {
        "profile_id": "future-tradition",
        "verbal_component_ids": ["fire-root", "greater"],
        "somatic_component_ids": ["point-and-throw"]
    }
    var restored = PREPARED_SPELL.from_dict(spell.to_dict())
    _check(restored != null, "Prepared spell should survive serialisation round-trip")
    if restored == null:
        return
    _check(restored.base_spell_id == "firebolt", "Prepared spell should retain its base spell identity")
    _check(int(restored.modifiers.get("magnitude_bonus", 0)) == 2, "Prepared spell should retain its modifier choices")
    _check(restored.presentation.get("verbal_component_ids", []).size() == 2, "Prepared spell should retain future verbal component IDs")
    _check(restored.presentation.get("somatic_component_ids", []).size() == 1, "Prepared spell should retain future gesture component IDs")

    var character = CHARACTER_STATE.new("caster", "Caster")
    character.prepared_spells.append(spell.to_dict())
    character.blood_magic_active = true
    character.to_hit_spell = 12.5
    var restored_character = CHARACTER_STATE.from_dict(character.to_dict())
    _check(restored_character.prepared_spells.size() == 1, "Character save data should retain prepared spells")
    var restored_entry: Dictionary = restored_character.prepared_spells[0]
    _check(String(restored_entry.get("base_spell_id", "")) == "firebolt", "Character save data should retain the prepared spell base ID")
    _check(restored_character.blood_magic_active, "Blood Magic stance should survive character save data")
    _check(is_equal_approx(restored_character.to_hit_spell, 12.5), "Spell accuracy should survive character save data")


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error("FAIL: " + message)
