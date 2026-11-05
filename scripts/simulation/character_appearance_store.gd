class_name CharacterAppearanceStore
extends RefCounted

const SAVE_PATH := "user://character_appearances.json"

static func save_appearance(character_id: String, appearance: CharacterAppearance) -> Error:
    if character_id.is_empty() or appearance == null:
        return ERR_INVALID_PARAMETER
    var all_data := _read_all()
    all_data[character_id] = appearance.to_dict()
    var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(all_data, "\t"))
    file.flush()
    file.close()
    var absolute_tmp := ProjectSettings.globalize_path(SAVE_PATH + ".tmp")
    var absolute_final := ProjectSettings.globalize_path(SAVE_PATH)
    var dir := DirAccess.open("user://")
    if dir == null:
        return ERR_CANT_OPEN
    if dir.file_exists("character_appearances.json"):
        dir.remove("character_appearances.json")
    return dir.rename("character_appearances.json.tmp", "character_appearances.json")

static func load_appearance(character_id: String) -> CharacterAppearance:
    var all_data := _read_all()
    var value: Variant = all_data.get(character_id, {})
    return CharacterAppearance.from_dict(value) if value is Dictionary else CharacterAppearance.new()

static func _read_all() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}
