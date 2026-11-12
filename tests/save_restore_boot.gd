extends Node

func _ready() -> void:
    var runner := Node.new()
    runner.name = "SaveRestoreIntegrationRunner"
    runner.set_script(load("res://tests/save_restore_runner.gd"))
    get_tree().root.add_child(runner)
