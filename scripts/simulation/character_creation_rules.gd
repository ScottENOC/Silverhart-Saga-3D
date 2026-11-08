class_name CharacterCreationRules
extends RefCounted
## Source-backed character creation rules migrated from Hex-crpg.

const DATA_PATH := "res://data/characters/character_creation_rules.json"
const ITEM_CATALOG = preload("res://scripts/simulation/item_catalog.gd")
static var _cache: Dictionary = {}

static func _data() -> Dictionary:
    if not _cache.is_empty():
        return _cache
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Character creation rules missing: %s" % DATA_PATH)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        _cache = parsed
    else:
        push_error("Character creation rules are invalid JSON.")
    return _cache

static func race_ids() -> Array[String]:
    var result: Array[String] = []
    for key in _data().get("races", {}).keys():
        result.append(String(key))
    result.sort()
    return result

static func class_ids() -> Array[String]:
    var result: Array[String] = []
    for key in _data().get("classes", {}).keys():
        result.append(String(key))
    result.sort()
    return result

static func race_definition(id: String) -> Dictionary:
    var value: Variant = _data().get("races", {}).get(id, {})
    return value.duplicate(true) if value is Dictionary else {}

static func class_definition(id: String) -> Dictionary:
    var value: Variant = _data().get("classes", {}).get(id, {})
    return value.duplicate(true) if value is Dictionary else {}

static func create_player_state(profile: Dictionary, character_id: String, start_hex: Vector2i) -> CharacterState:
    var race_id := String(profile.get("race", "human"))
    var class_id := String(profile.get("character_class", "fighter"))
    var race := race_definition(race_id)
    var profession := class_definition(class_id)
    if race.is_empty() or profession.is_empty():
        push_error("Invalid player race/class: %s / %s" % [race_id, class_id])
        race_id = "human"
        class_id = "fighter"
        race = race_definition(race_id)
        profession = class_definition(class_id)
    var state := CharacterState.new(character_id, String(profile.get("name", "Adventurer")), start_hex)
    state.side = "player"
    state.race = race_id
    state.character_class = class_id
    state.level = 1
    state.experience = 0
    state.game_mode = String(profile.get("game_mode", "campaign"))
    state.campaign_id = String(profile.get("campaign_id", "2"))
    state.difficulty_mode = String(profile.get("difficulty_mode", "normal"))
    state.ironman_mode = bool(profile.get("ironman_mode", false))
    state.gender_presentation = String(profile.get("gender_presentation", "Masculine"))
    state.pronouns = String(profile.get("pronouns", "they/them"))
    state.class_levels = {class_id: 1}
    state.gold = int(_data().get("starting_resources", {}).get(state.campaign_id, 0))
    state.tags = ["humanoid", "race_%s" % race_id]
    var attributes: Dictionary = {}
    for key in _data().get("base_attributes", []):
        attributes[String(key)] = 0
    for definition in [race, profession]:
        var bonuses: Dictionary = definition.get("bonus", {})
        for key in bonuses:
            attributes[key] = int(attributes.get(key, 0)) + int(bonuses[key])
    state.attributes = attributes
    if state.difficulty_mode == "easy":
        state.gold = roundi(float(state.gold) * 1.5)
        state.skills["health"] = 1
        state.free_skill_ranks["health"] = 1
        state.max_health += 10
        state.health += 10
    var equipped_ids: Array = profession.get("equipped", [])
    var starting_ids: Array = profession.get("starting_equipment", [])
    for index in range(starting_ids.size()):
        var item_id := String(starting_ids[index])
        var item := ITEM_CATALOG.create_instance(item_id, "start_%s_%s_%02d" % [character_id, item_id, index])
        if item.is_empty():
            push_error("Unknown class starting item: %s" % item_id)
            continue
        if state.add_inventory_item(item) and equipped_ids.has(item_id):
            if not state.equip_inventory_item(String(item.instance_id)):
                push_error("Could not equip starting item: %s" % item_id)
    return state

static func preview_text(race_id: String, class_id: String, difficulty_id: String) -> String:
    var race := race_definition(race_id)
    var profession := class_definition(class_id)
    var totals: Dictionary = {}
    for key in race.get("bonus", {}):
        totals[key] = int(totals.get(key, 0)) + int(race.bonus[key])
    for key in profession.get("bonus", {}):
        totals[key] = int(totals.get(key, 0)) + int(profession.bonus[key])
    var keys: Array = totals.keys()
    keys.sort()
    var bonus_lines: Array[String] = []
    for key in keys:
        if int(totals[key]) != 0:
            bonus_lines.append("%s +%d" % [String(key).capitalize(), int(totals[key])])
    var difficulty: Dictionary = _data().get("difficulties", {}).get(difficulty_id, {})
    return "%s — %s\n%s\nAttribute pools: %s\nStarting gear: %s\n%s" % [
        String(race.get("label", race_id)),
        String(profession.get("label", class_id)),
        String(profession.get("description", "")),
        ", ".join(bonus_lines),
        ", ".join(profession.get("starting_equipment", [])),
        String(difficulty.get("description", ""))
    ]
