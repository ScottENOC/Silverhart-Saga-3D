class_name SkillCatalog
extends RefCounted
## Loads the source-derived skill catalogue. This is metadata only; effects are
## deliberately implemented in separate simulation systems.

const DATA_PATH := "res://data/skills/skill_definitions.json"
static var _definitions: Dictionary = {}
static var _load_error: String = ""

static func definitions() -> Dictionary:
    if not _definitions.is_empty():
        return _definitions
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        _load_error = "missing_catalogue"
        push_error("Skill catalogue missing: %s" % DATA_PATH)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        _load_error = "invalid_catalogue_json"
        push_error("Skill catalogue is not a JSON object.")
        return {}
    var rows: Variant = parsed.get("skills", [])
    if not rows is Array:
        _load_error = "invalid_skill_list"
        return {}
    var loaded: Dictionary = {}
    for row in rows:
        if not row is Dictionary:
            _load_error = "invalid_skill_entry"
            return {}
        var skill_id := String(row.get("id", ""))
        var tree := String(row.get("tree", ""))
        if skill_id.is_empty() or tree.is_empty() or loaded.has(skill_id):
            _load_error = "invalid_or_duplicate_skill_id"
            push_error("Skill catalogue contains an empty or duplicate skill ID: %s" % skill_id)
            return {}
        loaded[skill_id] = row.duplicate(true)
    if int(parsed.get("count", -1)) != loaded.size():
        _load_error = "catalogue_count_mismatch"
        push_error("Skill catalogue count does not match its entries.")
        return {}
    _definitions = loaded
    _load_error = ""
    return _definitions

static func get_skill(skill_id: String) -> Dictionary:
    var value: Variant = definitions().get(skill_id, {})
    return value.duplicate(true) if value is Dictionary else {}

static func all_skill_ids() -> Array[String]:
    var result: Array[String] = []
    for skill_id in definitions():
        result.append(String(skill_id))
    result.sort()
    return result

static func load_error() -> String:
    definitions()
    return _load_error

static func reset_cache_for_tests() -> void:
    _definitions.clear()
    _load_error = ""
