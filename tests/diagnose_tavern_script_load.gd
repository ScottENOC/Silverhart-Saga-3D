extends SceneTree

func _initialize() -> void:
    print("[TavernScriptDiagnostic] Loading HollowTankard directly.")
    var tavern_script = load("res://scripts/world/hollow_tankard.gd")
    if tavern_script == null:
        push_error("[TavernScriptDiagnostic] HollowTankard failed to load.")
        quit(1)
        return
    print("[TavernScriptDiagnostic] HollowTankard loaded: ", tavern_script)
    quit(0)
