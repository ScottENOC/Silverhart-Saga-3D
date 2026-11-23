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
    _test_prepared_spell_round_trip()

    if _failures > 0:
        push_error("%d spell rules test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Spell rules tests passed.")
    quit(0)


func _test_catalogue_loads() -> void:
    var catalogue := SPELL_RULES.base_spells()
    _check(catalogue.size() == 12, "The official player spell catalogue should load all 12 spells")
    var expected_ids := [
        "firebolt", "counterspell", "feather_fall", "disguise_self",
        "heal", "divine_protection", "divine_strength", "curse",
        "summon_animal", "entangle", "calm_animal", "wild_fury"
    ]
    for spell_id in expected_ids:
        _check(catalogue.has(spell_id), "Official catalogue should include %s" % spell_id)
    for obsolete_id in ["smite_evil", "divine_silence", "sanctuary", "dragon_breath", "temporal_rift"]:
        _check(not catalogue.has(obsolete_id), "Obsolete spell %s must not be learnable" % obsolete_id)
        _check(not SPELL_RULES.compute_variant(obsolete_id).get("ok", false), "Obsolete spell %s must not produce a castable variant" % obsolete_id)


func _test_default_variant() -> void:
    var result: Dictionary = SPELL_RULES.compute_variant("firebolt")
    _check(bool(result.get("ok", false)), "Default Firebolt should be calculable")
    _check(int(result.get("mana_cost", -1)) == 5, "Default Firebolt should cost 5 mana")
    _check(int(result.get("core_mana_cost", -1)) == 5, "Default Firebolt core cost should be 5")
    _check(int(result.get("time_point_cost", -1)) == 10, "Default Firebolt should cost 10 TP")
    var curse: Dictionary = SPELL_RULES.compute_variant("curse")
    var divine_strength: Dictionary = SPELL_RULES.compute_variant("divine_strength")
    _check(int(curse.get("time_point_cost", -1)) == 8, "Curse should retain its source-derived 8 TP cost")
    _check(int(divine_strength.get("time_point_cost", -1)) == 10, "Divine Strength should cost 10 TP")
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
    var result: Dictionary = SPELL_RULES.compute_variant("heal", modifiers)
    _check(bool(result.get("ok", false)), "Subtle burst Heal should be calculable")
    _check(int(result.get("mana_cost", -1)) == 51, "Slowed subtle burst Heal should match the original mana formula")
    _check(int(result.get("core_mana_cost", -1)) == 55, "Core cost should exclude the slowed mana discount")
    _check(int(result.get("time_point_cost", -1)) == 25, "Slowed subtle casting should cost 25 TP")
    _check(String(result.get("type", "")) == "aoe_heal", "Burst Heal should become area healing")


func _test_touch_and_mana_floor() -> void:
    var touch := SPELL_RULES.compute_variant("firebolt", {"touch": true})
    _check(bool(touch.get("ok", false)), "Touch Firebolt should be calculable")
    _check(int(touch.get("mana_cost", -1)) == 2, "Touch should discount Firebolt by three mana")
    _check(int(touch.get("range", -1)) == 1, "Touch should cap spell range at one")

    var floor_result := SPELL_RULES.compute_variant(
        "firebolt",
        {"speed": "slowed", "touch": true}
    )
    _check(int(floor_result.get("mana_cost", -1)) == 1, "Mana cost should never fall below one")


func _test_invalid_combinations() -> void:
    var unknown := SPELL_RULES.compute_variant("not_a_spell")
    _check(not bool(unknown.get("ok", true)), "Unknown base spell should be rejected")
    var invalid_burst := SPELL_RULES.compute_variant("divine_protection", {"burst": true})
    _check(not bool(invalid_burst.get("ok", true)), "Burst should reject unsupported base spell types")
    var invalid_subtle := SPELL_RULES.compute_variant("firebolt", {"subtle": true})
    _check(not bool(invalid_subtle.get("ok", true)), "Subtle direct damage should be rejected")
    var invalid_touch := SPELL_RULES.compute_variant("heal", {"touch": true})
    _check(not bool(invalid_touch.get("ok", true)), "Touch should reject spells without extended base range")


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
