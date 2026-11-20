extends SceneTree


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var painter_script := load("res://tools/anatomy_surface_painter.gd") as Script
    assert(painter_script != null, "Anatomy surface painter script failed to load")
    var painter_scene := load("res://tools/anatomy_surface_painter.tscn") as PackedScene
    assert(painter_scene != null, "Anatomy surface painter scene failed to load")
    var input_router := load("res://tools/anatomy_surface_painter_input.gd") as Script
    assert(input_router != null, "Anatomy surface painter input router failed to load")
    print("ARA_ANATOMY_SURFACE_PAINTER_LOAD: PASS")
    quit(0)
