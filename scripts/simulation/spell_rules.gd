class_name SpellRules
extends RefCounted

## Authoritative spell variant maths, ported from Hex-crpg's
## spellPlanner.js computeSpellVariant(). UI and AI must use this result.
## This is intentionally separate from casting/effect resolution.

const DATA_PATH := "res://data/magic/base_spells.json"
static var _base_spells: Dictionary = {}
static var _load_error: String = ""


static func base_spells() -> Dictionary:
    if not _base_spells.is_empty():
        return _base_spells
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        _load_error = "missing_spell_catalogue"
        push_error("Spell catalogue missing: %s" % DATA_PATH)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        _load_error = "invalid_spell_catalogue_json"
        return {}
    var rows: Variant = parsed.get("spells", [])
    if not rows is Array:
        _load_error = "invalid_spell_list"
        return {}
    var loaded: Dictionary = {}
    for row in rows:
        if not row is Dictionary:
            _load_error = "invalid_spell_entry"
            return {}
        var spell_id := String(row.get("id", ""))
        if spell_id.is_empty() or loaded.has(spell_id):
            _load_error = "empty_or_duplicate_spell_id"
            return {}
        loaded[spell_id] = row.duplicate(true)
    if int(parsed.get("count", -1)) != loaded.size():
        _load_error = "spell_count_mismatch"
        return {}
    _base_spells = loaded
    _load_error = ""
    return _base_spells


static func get_base_spell(spell_id: String) -> Dictionary:
    var value: Variant = base_spells().get(spell_id, {})
    return value.duplicate(true) if value is Dictionary else {}


static func compute_variant(
    spell_id: String,
    modifiers: Dictionary = {},
    skills: Dictionary = {}
) -> Dictionary:
    var base := get_base_spell(spell_id)
    if base.is_empty():
        return {"ok": false, "reason": "unknown_base_spell"}

    var raw_speed: Variant = modifiers.get("speed", "default")
    if not raw_speed is String or not ["default", "quickened", "slowed"].has(String(raw_speed)):
        return {"ok": false, "reason": "invalid_casting_speed"}
    for modifier_key in ["magnitude_bonus", "range_bonus", "radius_bonus", "target_bonus"]:
        var raw_value: Variant = modifiers.get(modifier_key, 0)
        if not (raw_value is int or raw_value is float):
            return {"ok": false, "reason": "invalid_spell_modifier"}
        if not is_finite(float(raw_value)) or float(raw_value) < 0.0 or float(raw_value) != floorf(float(raw_value)):
            return {"ok": false, "reason": "invalid_spell_modifier"}
    for boolean_key in ["burst", "subtle", "touch"]:
        if not (modifiers.get(boolean_key, false) is bool):
            return {"ok": false, "reason": "invalid_spell_modifier"}

    var summon_id: Variant = modifiers.get("summon_id", "wolf")
    if not summon_id is String or not ["wolf", "boar", "tiger", "eagle", "unicorn"].has(String(summon_id)):
        return {"ok": false, "reason": "invalid_summon_choice"}
    var calm_mode: Variant = modifiers.get("calm_mode", "stay")
    if not calm_mode is String or not ["stay", "come", "chase"].has(String(calm_mode)):
        return {"ok": false, "reason": "invalid_calm_mode"}
    var speed := String(raw_speed)
    var magnitude_bonus := int(modifiers.get("magnitude_bonus", 0))
    var range_bonus := int(modifiers.get("range_bonus", 0))
    var radius_bonus := int(modifiers.get("radius_bonus", 0))
    var target_bonus := int(modifiers.get("target_bonus", 0))
    var burst := bool(modifiers.get("burst", false))
    var subtle := bool(modifiers.get("subtle", false))
    var touch := bool(modifiers.get("touch", false))

    var base_type := String(base.get("type", ""))
    var base_range := int(base.get("base_range", 1)) if base.get("base_range") != null else 1
    if burst and not ["damage", "heal"].has(base_type):
        return {"ok": false, "reason": "burst_not_supported"}
    if subtle and base_type == "damage":
        return {"ok": false, "reason": "subtle_damage_not_supported"}
    if touch and base_range <= 1:
        return {"ok": false, "reason": "touch_not_applicable"}
    if touch and range_bonus > 0:
        return {"ok": false, "reason": "touch_and_range_bonus_are_exclusive"}

    var school := String(base.get("school", ""))
    var efficiency_range := 0
    var efficiency_magnitude := 0
    var efficiency_speed := 0
    if school == "arcane":
        efficiency_range = maxi(0, int(skills.get("arcane_eff_range", 0)))
        efficiency_magnitude = maxi(0, int(skills.get("arcane_eff_magnitude", 0)))
        efficiency_speed = maxi(0, int(skills.get("arcane_eff_speed", 0)))

    var mana_cost := int(base.get("base_mana", 0))
    var time_point_cost := 10
    if speed == "quickened":
        time_point_cost = 5
        mana_cost += maxi(0, 5 - efficiency_speed)
    elif speed == "slowed":
        time_point_cost = 20
        mana_cost -= 4

    var range_cost := -3 if touch else maxi(0, range_bonus - efficiency_range)
    mana_cost += range_cost
    mana_cost += magnitude_bonus * maxi(0, 5 - efficiency_magnitude)
    mana_cost += radius_bonus * 10
    mana_cost += target_bonus * 15
    if burst:
        mana_cost += 8
    if subtle:
        mana_cost += 6
        time_point_cost += 5

    # Keep the source game's core cost separate from the actual cost. The
    # original formula excludes quickened's efficiency-adjusted surcharge
    # from coreManaCost, while including all other modifiers.
    var core_mana_cost := int(base.get("base_mana", 0)) + range_cost
    core_mana_cost += magnitude_bonus * maxi(0, 5 - efficiency_magnitude)
    core_mana_cost += radius_bonus * 10
    core_mana_cost += target_bonus * 15
    if burst:
        core_mana_cost += 8
    if subtle:
        core_mana_cost += 6

    mana_cost = maxi(1, mana_cost)
    var base_magnitude: Variant = base.get("base_magnitude")
    var magnitude: Variant = null
    if base_magnitude != null:
        magnitude = float(base_magnitude) * (1.0 + float(magnitude_bonus))

    var base_radius := 0
    if base.get("base_radius") != null:
        base_radius = int(base.get("base_radius"))
    var radius := (1 if burst else base_radius) + radius_bonus
    var effective_range := 1 if touch else base_range + range_bonus
    var effective_type := base_type
    if burst:
        effective_type = "aoe_heal" if base_type == "heal" else "aoe_damage"

    return {
        "ok": true,
        "base_id": spell_id,
        "name": String(base.get("name", spell_id)),
        "school": school,
        "type": effective_type,
        "mana_cost": mana_cost,
        "core_mana_cost": core_mana_cost,
        "time_point_cost": time_point_cost,
        "magnitude": magnitude,
        "range": effective_range,
        "radius": radius,
        "extra_targets": target_bonus,
        "subtle": subtle,
        "touch": touch,
        "modifiers": PreparedSpell._normalise_modifiers(modifiers)
    }


## The first resolver slice supports only direct Firebolt damage and
## single-target Heal. Do not silently treat unimplemented Burst/AoE or
## extra-target variants as single-target casts.
static func supports_initial_cast(spell_id: String, variant: Dictionary) -> bool:
    if not bool(variant.get("ok", false)):
        return false
    const IMPLEMENTED_IDS := [
        "firebolt", "heal", "smite_evil", "divine_silence", "sanctuary",
        "divine_protection", "summon_animal", "counterspell", "dragon_breath",
        "entangle", "wild_fury", "calm_animal", "disguise_self",
        "temporal_rift", "feather_fall"
    ]
    if not IMPLEMENTED_IDS.has(spell_id):
        return false
    if int(variant.get("extra_targets", 0)) > 0:
        return false
    var modifiers: Dictionary = variant.get("modifiers", {})
    if bool(modifiers.get("burst", false)) and spell_id not in ["heal", "firebolt"]:
        return false
    if int(variant.get("radius", 0)) > 0 and spell_id not in ["dragon_breath", "entangle", "heal", "firebolt"]:
        return false
    if spell_id in ["heal", "firebolt"] and int(variant.get("radius", 0)) > 0 and not bool(modifiers.get("burst", false)):
        return false
    return true


## Port of Hex-crpg's getArmorSpellPenalty(). The armour slot accepts either
## the compact item ID or the richer equipped item dictionary.
static func armour_mana_penalty(caster: CharacterState, school: String) -> int:
    if caster == null:
        return 0
    var armour_value: Variant = caster.equipped_item_data.get("armour", caster.equipment.get("armour", caster.equipment.get("armor", "")))
    var weight_class := ""
    var armour_id := ""
    if armour_value is Dictionary:
        weight_class = String(armour_value.get("weight_class", armour_value.get("weightClass", ""))).to_lower()
        armour_id = String(armour_value.get("id", "")).to_lower()
    else:
        armour_id = String(armour_value).to_lower()
    var penalty := 0
    if weight_class == "heavy" or armour_id == "heavy_armor" or armour_id == "heavy_armour":
        penalty = 3
    elif weight_class == "medium" or armour_id == "medium_armor" or armour_id == "medium_armour":
        penalty = 2
    elif weight_class == "light" or armour_id == "light_armor" or armour_id == "light_armour":
        penalty = 1
    if school == "divine":
        penalty -= maxi(0, int(caster.skills.get("divine_armor_ease", 0)))
    elif school == "nature":
        penalty -= maxi(0, int(caster.skills.get("nature_armor_ease", 0)))
    return maxi(0, penalty)


## Source-compatible mana-first payment with optional Blood Magic conversion:
## each missing mana costs 2 HP, and a caster must remain above 0 HP.
static func cast_affordability(caster: CharacterState, total_cost: int) -> Dictionary:
    if caster == null or total_cost < 0:
        return {"ok": false, "reason": "invalid_mana_cost"}
    var mana_available := maxi(0, caster.current_mana)
    var mana_to_spend := mini(mana_available, total_cost)
    var shortfall := total_cost - mana_to_spend
    var hp_cost := shortfall * 2
    if shortfall > 0:
        if not caster.blood_magic_active or int(caster.skills.get("blood_magic", 0)) <= 0:
            return {"ok": false, "reason": "insufficient_mana"}
        if caster.health - hp_cost < 1:
            return {"ok": false, "reason": "insufficient_blood_magic_health"}
    return {
        "ok": true,
        "mana_to_spend": mana_to_spend,
        "hp_cost": hp_cost
    }


static func load_error() -> String:
    base_spells()
    return _load_error


static func reset_cache_for_tests() -> void:
    _base_spells.clear()
    _load_error = ""
