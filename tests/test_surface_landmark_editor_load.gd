extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed := load("res://tools/surface_landmark_editor.tscn") as PackedScene
    assert(packed != null, "Native companion surface landmark editor scene did not load")
    var editor := packed.instantiate() as Control
    assert(editor != null, "Ara surface landmark editor root is not Control")
    root.add_child(editor)
    await process_frame
    await process_frame
    assert(editor.get("_body_root") != null, "Surface landmark editor did not load its default Wren native build")
    var body_option: OptionButton = editor.get("_body_option")
    assert(body_option.get_item_count() == 2, "Landmark editor should only offer Wren and Aldric native builds")
    assert(body_option.get_item_text(0) == "Wren (current native build)", "Wren must be the default landmark target")
    var descriptors: Array = editor.get("_descriptors")
    assert(not descriptors.is_empty(), "Surface landmark editor found no skinned surfaces")
    print("NATIVE_COMPANION_SURFACE_LANDMARK_EDITOR_LOAD: PASS surfaces=%d" % descriptors.size())
    editor.queue_free()
    await process_frame
    quit(0)
