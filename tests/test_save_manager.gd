extends SceneTree

var _failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var sample := {
        "player_profile": {"name": "Save Test", "body_variant": "female"},
        "position": Vector3(12.5, 0.0, -4.25),
        "party_member_ids": ["player", "companion_wren_talbot"],
        "world_seconds": 39600.0
    }
    var saved := SaveManager.save_snapshot("test_slot", sample, "Automated Save Test")
    _check(bool(saved.get("ok", false)), "SaveManager should write a manual slot")
    var loaded := SaveManager.load_snapshot("test_slot")
    _check(bool(loaded.get("ok", false)), "SaveManager should load a valid manual slot")
    if bool(loaded.get("ok", false)):
        var restored: Dictionary = loaded.get("snapshot", {})
        _check(restored.get("player_profile", {}).get("name", "") == "Save Test", "Player profile should round-trip")
        _check(restored.get("position", Vector3.ZERO) == Vector3(12.5, 0.0, -4.25), "Vector3 should round-trip through binary serialization")
        _check(restored.get("party_member_ids", []).size() == 2, "Party roster should round-trip")
    var invalid := SaveManager.save_snapshot("slot_99", sample)
    _check(not bool(invalid.get("ok", false)), "Invalid slot IDs should be rejected")
    var path := ProjectSettings.globalize_path("user://saves/test_slot.sav")
    if FileAccess.file_exists("user://saves/test_slot.sav"):
        DirAccess.remove_absolute(path)
    if FileAccess.file_exists("user://saves/test_slot.sav.bak"):
        DirAccess.remove_absolute(path + ".bak")
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