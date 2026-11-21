extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed := load("res://tools/surface_contact_path_editor.tscn") as PackedScene
    assert(packed != null, "Ara surface contact path editor scene did not load")
    var editor := packed.instantiate() as Control
    assert(editor != null, "Ara surface contact path editor root is not Control")
    root.add_child(editor)
    await process_frame
    await process_frame
    assert(editor.get("_body_root") != null, "Contact path editor did not load its default Ara body")
    var descriptors: Array = editor.get("_descriptors")
    assert(not descriptors.is_empty(), "Contact path editor found no skinned surfaces")
    assert(editor.get("_path_id_input") != null, "Contact path editor did not build its path ID control")
    assert(editor.get("_path_preview_mesh") != null, "Contact path editor did not build its preview")
    print("ARA_SURFACE_CONTACT_PATH_EDITOR_LOAD: PASS surfaces=%d" % descriptors.size())
    editor.queue_free()
    await process_frame
    quit(0)
