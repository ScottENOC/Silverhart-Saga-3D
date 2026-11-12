extends SceneTree

func _initialize() -> void:
    print("[TavernScriptDiagnostic] Loading HollowTankard directly.")
    var tavern_script = load("res://scripts/world/hollow_tankard.gd")
    if tavern_script == null:
        push_error("[TavernScriptDiagnostic] HollowTankard failed to load.")
        quit(1)
        return
    var reload_error: Error = tavern_script.reload()
    if reload_error != OK:
        push_error("[TavernScriptDiagnostic] HollowTankard reload failed: %s" % error_string(reload_error))
        quit(1)
        return
    print("[TavernScriptDiagnostic] HollowTankard parsed successfully.")
    quit(0)
