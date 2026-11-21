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
    var body_option: OptionButton = editor.get("_body_option")
    body_option.select(1)
    editor.call("_load_body", "Male Ara")
    await process_frame
    var male_save_path: LineEdit = editor.get("_save_path")
    assert(male_save_path.text.begins_with("res://data/characters/surface_contact_paths/male_"),
        "Changing to Male Ara left the contact path save target on the wrong body: " + male_save_path.text)
    var path_points: Array = editor.get("_path_points")
    assert(path_points.is_empty(), "Changing body did not clear the previous contact path points")
    body_option.select(0)
    editor.call("_load_body", "Female Ara")
    await process_frame
    var female_save_path: LineEdit = editor.get("_save_path")
    assert(female_save_path.text.begins_with("res://data/characters/surface_contact_paths/female_"),
        "Changing back to Female Ara left the contact path save target on the wrong body: " + female_save_path.text)
    print("ARA_SURFACE_CONTACT_PATH_EDITOR_LOAD: PASS surfaces=%d body_switch=PASS" % descriptors.size())
    editor.queue_free()
    await process_frame
    quit(0)
