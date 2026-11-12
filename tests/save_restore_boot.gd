extends Node

func _ready() -> void:
    var runner := Node.new()
    runner.name = "SaveRestoreIntegrationRunner"
    runner.set_script(load("res://tests/save_restore_runner.gd"))
    # The boot scene is still attaching its children during _ready(). Defer
    # insertion into the SceneTree root to avoid Godot's busy-parent error.
    get_tree().root.add_child.call_deferred(runner)
