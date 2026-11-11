extends Node
## Versioned campaign save storage. Runtime game systems provide plain-data snapshots;
## this service owns slot metadata, validation, safe writes and rotation.
const FORMAT_VERSION := 1
const SAVE_ROOT := "user://saves"
const MANUAL_SLOT_COUNT := 8
const QUICK_SLOT := "quicksave"
const AUTOSAVE_SLOTS := ["autosave_01", "autosave_02", "autosave_03"]
var _autosave_cursor := 0
var pending_load_data: Dictionary = {}

func _slot_path(slot_id: String) -> String:
    return "%s/%s.sav" % [SAVE_ROOT, slot_id]

func _valid_slot_id(slot_id: String) -> bool:
    if slot_id == QUICK_SLOT or AUTOSAVE_SLOTS.has(slot_id):
        return true
    if not slot_id.begins_with("slot_"):
        return false
    var number := slot_id.trim_prefix("slot_").to_int()
    return number >= 1 and number <= MANUAL_SLOT_COUNT and slot_id == "slot_%02d" % number

func save_snapshot(slot_id: String, snapshot: Dictionary, label: String = "Manual Save") -> Dictionary:
    if not _valid_slot_id(slot_id):
        return {"ok": false, "reason": "invalid_slot"}
    if snapshot.is_empty():
        return {"ok": false, "reason": "empty_snapshot"}
    var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))
    if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
        return {"ok": false, "reason": "directory_error", "error": directory_error}
    var metadata := {
        "slot_id": slot_id,
        "label": label,
        "saved_at_unix": int(Time.get_unix_time_from_system()),
        "game_version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
        "format_version": FORMAT_VERSION,
        "location": str(snapshot.get("location", "Unknown location")),
        "character_name": str(snapshot.get("player_profile", {}).get("name", "Adventurer")),
        "playtime_seconds": float(snapshot.get("playtime_seconds", 0.0))
    }
    var envelope := {"metadata": metadata, "snapshot": snapshot}
    var target := _slot_path(slot_id)
    var temporary := target + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "reason": "open_failed", "error": FileAccess.get_open_error()}
    file.store_var(envelope, false)
    file.flush()
    file.close()
    if FileAccess.get_open_error() != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return {"ok": false, "reason": "write_failed"}
    var absolute_target := ProjectSettings.globalize_path(target)
    var absolute_temporary := ProjectSettings.globalize_path(temporary)
    if FileAccess.file_exists(target):
        var backup := absolute_target + ".bak"
        DirAccess.copy_absolute(absolute_target, backup)
        var remove_error := DirAccess.remove_absolute(absolute_target)
        if remove_error != OK:
            return {"ok": false, "reason": "replace_failed", "error": remove_error}
    var rename_error := DirAccess.rename_absolute(absolute_temporary, absolute_target)
    if rename_error != OK:
        if FileAccess.file_exists(absolute_target + ".bak"):
            DirAccess.copy_absolute(absolute_target + ".bak", absolute_target)
        return {"ok": false, "reason": "commit_failed", "error": rename_error}
    return {"ok": true, "metadata": metadata}

func save_quick(snapshot: Dictionary) -> Dictionary:
    return save_snapshot(QUICK_SLOT, snapshot, "Quick Save")

func save_autosave(snapshot: Dictionary) -> Dictionary:
    var slot_id: String = AUTOSAVE_SLOTS[_autosave_cursor]
    _autosave_cursor = (_autosave_cursor + 1) % AUTOSAVE_SLOTS.size()
    return save_snapshot(slot_id, snapshot, "Autosave")

func load_snapshot(slot_id: String) -> Dictionary:
    if not _valid_slot_id(slot_id):
        return {"ok": false, "reason": "invalid_slot"}
    var path := _slot_path(slot_id)
    if not FileAccess.file_exists(path):
        return {"ok": false, "reason": "empty_slot"}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"ok": false, "reason": "open_failed", "error": FileAccess.get_open_error()}
    var envelope: Variant = file.get_var(false)
    file.close()
    if not envelope is Dictionary or not envelope.get("metadata", {}) is Dictionary or not envelope.get("snapshot", {}) is Dictionary:
        return {"ok": false, "reason": "corrupt_save"}
    var metadata: Dictionary = envelope["metadata"]
    var version := int(metadata.get("format_version", 0))
    if version > FORMAT_VERSION or version < 1:
        return {"ok": false, "reason": "unsupported_save_version", "version": version}
    return {"ok": true, "metadata": metadata.duplicate(true), "snapshot": envelope["snapshot"].duplicate(true)}

func get_slot_metadata(slot_id: String) -> Dictionary:
    var result := load_snapshot(slot_id)
    return result.get("metadata", {}) if bool(result.get("ok", false)) else {}

func list_slots() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in range(1, MANUAL_SLOT_COUNT + 1):
        var slot_id := "slot_%02d" % index
        var metadata := get_slot_metadata(slot_id)
        result.append({"slot_id": slot_id, "metadata": metadata, "occupied": not metadata.is_empty()})
    for slot_id in [QUICK_SLOT] + AUTOSAVE_SLOTS:
        var metadata := get_slot_metadata(slot_id)
        result.append({"slot_id": slot_id, "metadata": metadata, "occupied": not metadata.is_empty()})
    return result

func set_pending_load(snapshot: Dictionary) -> void:
    pending_load_data = snapshot.duplicate(true)

func consume_pending_load() -> Dictionary:
    var result := pending_load_data.duplicate(true)
    pending_load_data.clear()
    return result

func has_pending_load() -> bool:
    return not pending_load_data.is_empty()
