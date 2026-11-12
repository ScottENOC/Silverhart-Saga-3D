extends SceneTree

const SAVE_MANAGER_SCRIPT = preload("res://scripts/save/save_manager.gd")

var _failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var save_manager = SAVE_MANAGER_SCRIPT.new()
    var sample := {
        "player_profile": {"name": "Save Test", "body_variant": "female"},
        "position": Vector3(12.5, 0.0, -4.25),
        "party_member_ids": ["player", "companion_wren_talbot"],
        "world_seconds": 39600.0
    }
    var saved := save_manager.save_snapshot("test_slot", sample, "Automated Save Test")
    _check(bool(saved.get("ok", false)), "SaveManager should write a manual slot")
    var loaded := save_manager.load_snapshot("test_slot")
    _check(bool(loaded.get("ok", false)), "SaveManager should load a valid manual slot")
    if bool(loaded.get("ok", false)):
        var restored: Dictionary = loaded.get("snapshot", {})
        _check(restored.get("player_profile", {}).get("name", "") == "Save Test", "Player profile should round-trip")
        _check(restored.get("position", Vector3.ZERO) == Vector3(12.5, 0.0, -4.25), "Vector3 should round-trip through binary serialization")
        _check(restored.get("party_member_ids", []).size() == 2, "Party roster should round-trip")

    var replacement := sample.duplicate(true)
    replacement["player_profile"]["name"] = "Replacement Save"
    var replaced := save_manager.save_snapshot("test_slot", replacement, "Replacement Test")
    _check(bool(replaced.get("ok", false)), "Replacing a slot should complete successfully")
    var main_path := "user://saves/test_slot.sav"
    var corrupt_file := FileAccess.open(main_path, FileAccess.WRITE)
    _check(corrupt_file != null, "Test should be able to corrupt the primary save")
    if corrupt_file != null:
        corrupt_file.store_string("not a valid save envelope")
        corrupt_file.close()
    var recovered := save_manager.load_snapshot("test_slot")
    _check(bool(recovered.get("ok", false)), "A corrupt primary save should recover from its backup")
    if bool(recovered.get("ok", false)):
        _check(recovered.get("snapshot", {}).get("player_profile", {}).get("name", "") == "Save Test", "Backup recovery should restore the previous complete save")

    var invalid := save_manager.save_snapshot("slot_99", sample)
    _check(not bool(invalid.get("ok", false)), "Invalid slot IDs should be rejected")

    var pending_input := sample.duplicate(true)
    save_manager.set_pending_load(pending_input)
    pending_input["player_profile"]["name"] = "Mutated After Set"
    _check(save_manager.has_pending_load(), "Setting pending load should make it available")
    var pending := save_manager.consume_pending_load()
    _check(pending.get("player_profile", {}).get("name", "") == "Save Test", "Pending load should retain a deep copy of the supplied snapshot")
    _check(not save_manager.has_pending_load(), "Consuming pending load should clear it")

    var absolute_path := ProjectSettings.globalize_path(main_path)
    if FileAccess.file_exists(main_path):
        DirAccess.remove_absolute(absolute_path)
    if FileAccess.file_exists(main_path + ".bak"):
        DirAccess.remove_absolute(absolute_path + ".bak")
    var temporary_path := ProjectSettings.globalize_path(main_path + ".tmp")
    if FileAccess.file_exists(main_path + ".tmp"):
        DirAccess.remove_absolute(temporary_path)

    save_manager.free()
    if _failures > 0:
        push_error("%d save-system test assertion(s) failed." % _failures)
        quit(1)
        return
    print("SaveManager tests passed.")
    quit(0)

func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error("FAIL: " + message)
