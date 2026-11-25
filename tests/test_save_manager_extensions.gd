extends SceneTree

const SAVE_MANAGER_SCRIPT = preload("res://scripts/save/save_manager.gd")

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_manager = SAVE_MANAGER_SCRIPT.new()
	save_manager.register_snapshot_extension("spell_terrain_effects", Callable(self, "_spell_terrain_snapshot"))
	var sample := {
		"player_profile": {"name": "Extension Test"},
		"location": "Extension Test Location"
	}
	var saved := save_manager.save_snapshot("test_slot", sample, "Snapshot Extension Test")
	_check(bool(saved.get("ok", false)), "SaveManager should write a snapshot with registered extensions")
	var loaded := save_manager.load_snapshot("test_slot")
	_check(bool(loaded.get("ok", false)), "SaveManager should load a snapshot with registered extensions")
	if bool(loaded.get("ok", false)):
		var restored: Dictionary = loaded.get("snapshot", {})
		var effects: Array = restored.get("spell_terrain_effects", [])
		_check(effects.size() == 1, "Registered spell-terrain data should be included in the saved snapshot")
		if not effects.is_empty():
			_check(effects[0].get("effect_id", "") == "entangle", "Snapshot extension should preserve its supplied effect data")
	save_manager.unregister_snapshot_extension("spell_terrain_effects")

	var path := "user://saves/test_slot.sav"
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(absolute_path + ".bak")
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	save_manager.free()
	if _failures > 0:
		push_error("%d snapshot extension test assertion(s) failed." % _failures)
		quit(1)
		return
	print("SaveManager snapshot extension tests passed.")
	quit(0)

func _spell_terrain_snapshot() -> Array[Dictionary]:
	return [{"effect_id": "entangle", "hex": Vector2i(3, -2)}]

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)
