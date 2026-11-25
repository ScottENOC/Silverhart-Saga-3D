class_name PreparedSpell
extends RefCounted

## A prepared spell stores the choices that created it, not just a cached
## outcome. Derived costs/range/magnitude are recalculated by SpellRules.
## Presentation IDs are reserved for the future incantation/gesture grammar;
## this class deliberately does not invent spoken words or animation names.

const SCHEMA_VERSION: int = 1
const PRESENTATION_SCHEMA_VERSION: int = 1

var base_spell_id: String = ""
var modifiers: Dictionary = {}
var presentation: Dictionary = {}


func _init(
    requested_base_spell_id: String = "",
    requested_modifiers: Dictionary = {},
    requested_presentation: Dictionary = {}
) -> void:
    base_spell_id = requested_base_spell_id.strip_edges()
    modifiers = _normalise_modifiers(requested_modifiers)
    presentation = _normalise_presentation(requested_presentation)


static func create(base_id: String, requested_modifiers: Dictionary = {}) -> PreparedSpell:
    return PreparedSpell.new(base_id, requested_modifiers)


static func from_dict(data: Dictionary) -> PreparedSpell:
    if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
        return null
    var base_id := String(data.get("base_spell_id", "")).strip_edges()
    var saved_modifiers: Variant = data.get("modifiers", {})
    var saved_presentation: Variant = data.get("presentation", {})
    if base_id.is_empty() or not saved_modifiers is Dictionary:
        return null
    if not saved_presentation is Dictionary:
        return null
    var prepared := PreparedSpell.new(base_id, saved_modifiers, saved_presentation)
    return prepared if prepared.is_valid() else null


func is_valid() -> bool:
    if base_spell_id.is_empty():
        return false
    for key in ["magnitude_bonus", "range_bonus", "radius_bonus", "target_bonus"]:
        var value: Variant = modifiers.get(key, 0)
        if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0:
            return false
        if float(value) != floorf(float(value)):
            return false
    var speed: Variant = modifiers.get("speed", "default")
    if not speed is String or not ["default", "quickened", "slowed"].has(String(speed)):
        return false
    var summon_id: Variant = modifiers.get("summon_id", "wolf")
    if not summon_id is String or not ["wolf", "boar", "tiger", "eagle", "unicorn"].has(String(summon_id)):
        return false
    var calm_mode: Variant = modifiers.get("calm_mode", "stay")
    if not calm_mode is String or not ["stay", "come", "chase"].has(String(calm_mode)):
        return false
    for key in ["burst", "subtle", "touch"]:
        if not (modifiers.get(key, false) is bool):
            return false
    for key in ["verbal_component_ids", "somatic_component_ids"]:
        var ids: Variant = presentation.get(key, [])
        if not ids is Array:
            return false
        for component_id in ids:
            if not component_id is String or String(component_id).is_empty():
                return false
    return true


func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "base_spell_id": base_spell_id,
        "modifiers": modifiers.duplicate(true),
        "presentation": presentation.duplicate(true)
    }


static func _normalise_modifiers(source: Dictionary) -> Dictionary:
    return {
        "speed": source.get("speed", "default"),
        "magnitude_bonus": source.get("magnitude_bonus", 0),
        "range_bonus": source.get("range_bonus", 0),
        "radius_bonus": source.get("radius_bonus", 0),
        "target_bonus": source.get("target_bonus", 0),
        "burst": source.get("burst", false),
        "subtle": source.get("subtle", false),
        "touch": source.get("touch", false),
        "summon_id": source.get("summon_id", "wolf"),
        "calm_mode": source.get("calm_mode", "stay")
    }


static func _normalise_presentation(source: Dictionary) -> Dictionary:
    var verbal: Array = source.get("verbal_component_ids", [])
    var somatic: Array = source.get("somatic_component_ids", [])
    return {
        "schema_version": PRESENTATION_SCHEMA_VERSION,
        "profile_id": String(source.get("profile_id", "")),
        "verbal_component_ids": verbal.duplicate(true),
        "somatic_component_ids": somatic.duplicate(true)
    }
