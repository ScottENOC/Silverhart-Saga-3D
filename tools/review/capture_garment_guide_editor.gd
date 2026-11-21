extends SceneTree
## Captures the actual Ara garment-guide editor from four useful review angles.
## Run with: godot --path . --script res://tools/review/capture_garment_guide_editor.gd -- <output-dir>

const EDITOR_SCENE := "res://tools/garment_guide_curve_editor.tscn"


func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var arguments := OS.get_cmdline_user_args()
    var output_directory := "build/garment-guide-preview"
    if not arguments.is_empty():
        output_directory = arguments[0]
    var absolute_directory := ProjectSettings.globalize_path(output_directory) if output_directory.begins_with("res://") or output_directory.begins_with("user://") else output_directory
    var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
    if directory_error != OK:
        push_error("Could not create garment preview directory: %s (%d)" % [absolute_directory, directory_error])
        quit(1)
        return

    var packed := load(EDITOR_SCENE) as PackedScene
    if packed == null:
        push_error("Could not load garment guide editor scene")
        quit(1)
        return
    var editor := packed.instantiate() as Control
    if editor == null:
        push_error("Garment guide editor root is not a Control")
        quit(1)
        return
    root.size = Vector2i(1600, 1000)
    root.add_child(editor)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw

    for body_name in ["Female Ara", "Male Ara"]:
        if body_name == "Male Ara":
            editor.call("_load_body", body_name)
            await process_frame
            await process_frame
            await RenderingServer.frame_post_draw
        for view in ["front", "side", "rear"]:
            var yaw := PI
            if view == "side":
                yaw = PI * 0.5
            elif view == "rear":
                yaw = 0.0
            editor.set("_camera_yaw", yaw)
            editor.call("_update_camera")
            await process_frame
            await RenderingServer.frame_post_draw
            var screenshot := root.get_texture().get_image()
            var filename := "%s-%s.png" % [body_name.to_lower().replace(" ", "-"), view]
            var save_error := screenshot.save_png(absolute_directory.path_join(filename))
            if save_error != OK:
                push_error("Could not save %s (%d)" % [filename, save_error])
                quit(1)
                return
            print("GARMENT_PREVIEW_SAVED ", absolute_directory.path_join(filename))

    quit(0)
