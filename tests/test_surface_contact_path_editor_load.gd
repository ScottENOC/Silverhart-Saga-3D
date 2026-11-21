extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var packed := load("res://tools/surface_contact_path_editor.tscn") as PackedScene
    assert(packed != null, "Native companion surface contact path editor scene did not load")
    var editor := packed.instantiate() as Control
    assert(editor != null, "Native surface contact path editor root is not Control")
    root.add_child(editor)
    await process_frame
    await process_frame
    assert(editor.get("_body_root") != null, "Contact path editor did not load its default Wren native build")
    var descriptors: Array = editor.get("_descriptors")
    assert(not descriptors.is_empty(), "Contact path editor found no skinned surfaces")
    assert(editor.get("_path_id_input") != null, "Contact path editor did not build its path ID control")
    assert(editor.get("_path_preview_mesh") != null, "Contact path editor did not build its preview")
    assert(editor.get("_surface_regions") != null, "Contact editor did not configure the native body surface evaluator")
    assert(editor.get("_preview_contact_path") != null, "Contact editor did not create a reusable surface-route evaluator")
    var first_descriptor: Dictionary = descriptors[0]
    var triangle_ids: PackedInt32Array = first_descriptor["triangle_ids"]
    assert(triangle_ids.size() >= 3, "Native contact surface has no source triangles")
    var triangle := PackedInt32Array([triangle_ids[0], triangle_ids[1], triangle_ids[2]])
    var preview_points: Array[Dictionary] = [
        {"triangle_indices": triangle, "barycentric": PackedFloat32Array([1.0, 0.0, 0.0])},
        {"triangle_indices": triangle, "barycentric": PackedFloat32Array([0.0, 1.0, 0.0])}
    ]
    editor.set("_path_points", preview_points)
    editor.call("_refresh_marker")
    var preview_mesh: ImmediateMesh = editor.get("_path_preview_mesh")
    assert(preview_mesh.get_surface_count() == 1,
        "Two points on one source triangle should produce a rendered surface-constrained route")
    editor.call("_clear_path")
    var body_option: OptionButton = editor.get("_body_option")
    assert(body_option.get_item_count() == 2, "Contact editor should only offer current Wren and Aldric builds")
    assert(body_option.get_item_text(0) == "Wren (current native build)", "Wren must be the default contact-path target")
    body_option.select(1)
    editor.call("_load_body", "Aldric (current native build)")
    await process_frame
    var aldric_save_path: LineEdit = editor.get("_save_path")
    assert(aldric_save_path.text.begins_with("res://data/characters/surface_contact_paths/aldric_"),
        "Changing to Aldric left the contact path save target on the wrong body: " + aldric_save_path.text)
    var path_points: Array = editor.get("_path_points")
    assert(path_points.is_empty(), "Changing body did not clear the previous contact path points")
    body_option.select(0)
    editor.call("_load_body", "Wren (current native build)")
    await process_frame
    var wren_save_path: LineEdit = editor.get("_save_path")
    assert(wren_save_path.text.begins_with("res://data/characters/surface_contact_paths/wren_"),
        "Changing back to Wren left the contact path save target on the wrong body: " + wren_save_path.text)
    print("NATIVE_COMPANION_SURFACE_CONTACT_PATH_EDITOR_LOAD: PASS surfaces=%d body_switch=PASS" % descriptors.size())
    editor.queue_free()
    await process_frame
    quit(0)
