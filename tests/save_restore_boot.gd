extends Node

func _ready() -> void:
    var runner := Node.new()
    runner.name = "SaveRestoreIntegrationRunner"
    runner.set_script(load("res://tests/save_restore_runner.gd"))
    # Wait until the boot scene has finished attaching to the SceneTree.
    # The runner must live under the SceneTree root so it survives the
    # change_scene_to_file() call that launches the real campaign scene.
    await get_tree().process_frame
    get_tree().root.add_child(runner)
